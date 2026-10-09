import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/clip_editor/domain/quick_cuts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/recording/domain/recording_lock.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/language_catalog.dart';
import 'package:one_second_diary/features/settings/domain/locale_resolver.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';

/// Every setting that is not about profiles.
///
/// Each setting is a [Setting]: its current `value`, `set` to change it and
/// `changes` to follow it. Defaults come from `PrefKeys` only. This is the
/// only writer of these keys, so a cubit can read `value` once and then
/// follow `changes`.
///
/// Reading never writes. In particular `calendarAutoPlay`,
/// `calendarAutoSound` and `lang` are stored only when the user acts.
///
/// A plain class (not final), so cubit tests can fake it.
class SettingsRepository {
  SettingsRepository({required this._prefs});

  final PrefsStore _prefs;

  /// The dark theme (`isDarkMode`). Absent reads as dark.
  late final Setting<bool> darkMode = _stored(PrefKeys.isDarkMode);

  /// Decides the theme at launch and returns whether it is dark. Call it
  /// once per launch, before the first frame, with the platform's current
  /// brightness.
  ///
  /// - A stored `isDarkMode` wins: the Settings switch owns the theme.
  /// - An existing install without the key stays dark, the default, and
  ///   nothing is stored.
  /// - A brand-new install follows the phone once: [platformIsDark] is
  ///   stored, so later changes on the phone don't flip the app.
  Future<bool> settleThemeOnLaunch({required bool platformIsDark}) async {
    if (_prefs.contains(PrefKeys.isDarkMode) || _isExistingInstall) {
      return darkMode.value;
    }
    await darkMode.set(platformIsDark);
    return platformIsDark;
  }

  /// Whether an older install ran here: the user finished onboarding, or a
  /// key is present that the app never writes on its own at launch.
  bool get _isExistingInstall =>
      _prefs.read(PrefKeys.showIntro) == false ||
      PrefKeys.legacyLive
          .where((PrefKey<Object?> key) => !_writtenByV3AtLaunch.contains(key))
          .any(_prefs.contains);

  /// Keys the app may write on a brand-new install before the theme is
  /// settled: the log session, the SDK level and the downgrade counters.
  /// (Keys outside `PrefKeys.legacyLive` need no entry.)
  static const Set<PrefKey<Object?>> _writtenByV3AtLaunch = <PrefKey<Object?>>{
    PrefKeys.currentLogFile,
    PrefKeys.sdkVersion,
    PrefKeys.videoCount,
    PrefKeys.dailyEntry,
    PrefKeys.today,
  };

  /// The language the user picked (`lang`), or null to follow the device.
  ///
  /// A stored code the app has no translation for reads as null: older
  /// installs stored the device language on first launch whatever it was,
  /// so such a value was never the user's choice. Only a pick stores `lang`
  /// (the bare code); setting null removes it.
  late final Setting<AppLanguage?> pickedLanguage = Setting<AppLanguage?>(
    read: () => LanguageCatalog.byCode(_prefs.read(PrefKeys.lang)),
    write: (AppLanguage? language) => language == null
        ? _prefs.remove(PrefKeys.lang)
        : _prefs.write(PrefKeys.lang, language.code),
  );

  /// The language the app runs in on a device whose locale has
  /// [deviceLanguageCode] (without the region): see [LocaleResolver]. Always
  /// a supported language, and never stored, so the app keeps following the
  /// device until the user picks one.
  AppLanguage appLanguage({required String deviceLanguageCode}) =>
      LocaleResolver.resolve(
        storedLang: _prefs.read(PrefKeys.lang),
        deviceLanguageCode: deviceLanguageCode,
      );

  /// The daily reminder (`activatedNotification`).
  late final Setting<bool> remindersEnabled = _stored(
    PrefKeys.activatedNotification,
  );

  /// The reminder stays until the day is recorded (`persistentNotification`,
  /// Android only).
  late final Setting<bool> persistentReminder = _stored(
    PrefKeys.persistentNotification,
  );

  /// When the reminder fires (`scheduledTimeHour` / `scheduledTimeMinute`).
  ///
  /// A stored part outside the clock (only a corrupt store holds one) reads
  /// as its default instead of rolling the reminder into another day;
  /// storing one throws an [ArgumentError].
  late final Setting<ReminderTime> reminderTime = Setting<ReminderTime>(
    read: () => (
      hour: _withinOr(PrefKeys.scheduledTimeHour, max: 23),
      minute: _withinOr(PrefKeys.scheduledTimeMinute, max: 59),
    ),
    write: (ReminderTime time) async {
      RangeError.checkValueInInterval(time.hour, 0, 23, 'hour');
      RangeError.checkValueInInterval(time.minute, 0, 59, 'minute');
      await _prefs.write(PrefKeys.scheduledTimeHour, time.hour);
      await _prefs.write(PrefKeys.scheduledTimeMinute, time.minute);
    },
  );

  /// The value of [key] when it is within 0..[max], else its default.
  int _withinOr(PrefKey<int> key, {required int max}) {
    final int stored = _prefs.read(key);
    return stored >= 0 && stored <= max ? stored : key.defaultValue;
  }

  /// The 3 s countdown before recording (`timer`).
  late final Setting<bool> countdownBeforeRecording = _stored(PrefKeys.timer);

  /// Shortest and longest clip the camera records, in seconds. A stored 60
  /// is harmless to v1.7, which clamps to its own 10.
  static const int minRecordingSeconds = 2;
  static const int maxRecordingSeconds = 60;

  /// How many seconds the camera records, always within
  /// [minRecordingSeconds]..[maxRecordingSeconds]: clamped on read and on
  /// write.
  late final Setting<int> recordingSeconds = Setting<int>(
    read: () => _clampSeconds(_prefs.read(PrefKeys.recordingSeconds)),
    write: (int value) =>
        _prefs.write(PrefKeys.recordingSeconds, _clampSeconds(value)),
  );

  static int _clampSeconds(int seconds) =>
      seconds.clamp(minRecordingSeconds, maxRecordingSeconds);

  /// The last lens used.
  late final Setting<bool> recordWithFrontCamera = _stored(
    PrefKeys.recordWithFrontCamera,
  );

  /// Record with the front and the back camera at once (`dualCamera`); the
  /// camera uses it only on a phone that can.
  late final Setting<bool> dualCamera = _stored(PrefKeys.dualCamera);

  /// How the dual camera lays its two pictures out (`dualCameraSplit`).
  late final Setting<DualCameraLayout> dualCameraLayout =
      Setting<DualCameraLayout>(
        read: () => _prefs.read(PrefKeys.dualCameraSplit)
            ? DualCameraLayout.split
            : DualCameraLayout.inset,
        write: (DualCameraLayout layout) => _prefs.write(
          PrefKeys.dualCameraSplit,
          layout == DualCameraLayout.split,
        ),
      );

  /// Record with the system camera app.
  late final Setting<bool> forceNativeCamera = _stored(
    PrefKeys.forceNativeCamera,
  );

  /// New clips' stamps prefer Yusei Magic, the font older versions burned,
  /// over Rubik (`StampFontPolicy`).
  late final Setting<bool> legacyStampFont = _stored(PrefKeys.legacyStampFont);

  /// Note the phone, the app version and the moment in each new clip
  /// (`ClipNotesTag`).
  late final Setting<bool> clipDeviceInfo = _stored(PrefKeys.clipDeviceInfo);

  /// Keep every in-app recording untouched beside the diary after its
  /// clip is saved, for "Edit again" (`keepOriginals`, off by default).
  late final Setting<bool> keepOriginals = _stored(PrefKeys.keepOriginals);

  /// The date stamp (`dateColor`, `dateFormatId`, `dateOutline` and the
  /// text size `stampSize`), parsed by [StampStyle.fromPrefs].
  ///
  /// Setting a style writes only the parts that changed, so picking another
  /// format leaves an untouched `dateColor` (`''`, white) or `stampSize`
  /// (`''`, medium) as it was.
  late final Setting<StampStyle> stampStyle = Setting<StampStyle>(
    read: () => StampStyle.fromPrefs(
      dateColor: _prefs.read(PrefKeys.dateColor),
      dateFormatId: _prefs.read(PrefKeys.dateFormatId),
      dateOutline: _prefs.read(PrefKeys.dateOutline),
      stampSize: _prefs.read(PrefKeys.stampSize),
    ),
    write: (StampStyle style) async {
      final StampStyle current = stampStyle.value;
      final (
        :String dateColor,
        :int dateFormatId,
        :bool dateOutline,
        :String stampSize,
      ) = style
          .toPrefs();
      if (style.rgb != current.rgb) {
        await _prefs.write(PrefKeys.dateColor, dateColor);
      }
      if (style.format != current.format) {
        await _prefs.write(PrefKeys.dateFormatId, dateFormatId);
      }
      if (style.outline != current.outline) {
        await _prefs.write(PrefKeys.dateOutline, dateOutline);
      }
      if (style.size != current.size) {
        await _prefs.write(PrefKeys.stampSize, stampSize);
      }
    },
  );

  /// The remembered geotag switch.
  late final Setting<bool> enableGeotagging = _stored(
    PrefKeys.enableGeotagging,
  );

  /// The lengths a photo clip can have, in ms (the editor's chips, in
  /// order).
  static const List<int> photoDurationsMs = <int>[
    1000,
    1500,
    2000,
    3000,
    5000,
    10000,
  ];

  /// How long a photo clip lasts, always one of [photoDurationsMs]. Anything
  /// else stored reads as the default (1 s); storing anything else throws
  /// an [ArgumentError].
  late final Setting<int> photoDurationMs = Setting<int>(
    read: () {
      final int stored = _prefs.read(PrefKeys.photoDurationMs);
      return photoDurationsMs.contains(stored)
          ? stored
          : PrefKeys.photoDurationMs.defaultValue;
    },
    write: (int value) async {
      if (!photoDurationsMs.contains(value)) {
        throw ArgumentError.value(value, 'photoDurationMs', 'is not a chip');
      }
      await _prefs.write(PrefKeys.photoDurationMs, value);
    },
  );

  /// The last quick cut tapped in the clip editor (`lastQuickCutMs`): the
  /// window an imported video opens on, 1.5 s by default. Only a
  /// `QuickCuts.lengthsMs` value counts on read, anything else reads as
  /// the default; storing anything else throws an [ArgumentError]. Written
  /// by quick-cut taps only, never by a dragged handle, and never by the
  /// camera's length setting.
  late final Setting<int> lastQuickCut = Setting<int>(
    read: () => QuickCuts.accepted(_prefs.read(PrefKeys.lastQuickCutMs)),
    write: (int value) async {
      if (!QuickCuts.lengthsMs.contains(value)) {
        throw ArgumentError.value(value, 'lastQuickCut', 'is not a quick cut');
      }
      await _prefs.write(PrefKeys.lastQuickCutMs, value);
    },
  );

  /// How the camera starts for [profile] (`recordingLock_<profile>`): null
  /// until the lock was toggled once, which means locked to the profile's
  /// own shape.
  Setting<RecordingLock?> recordingLock(ProfileKey profile) {
    final PrefKey<String> key = PrefKeys.recordingLock(profile);
    return Setting<RecordingLock?>(
      read: () => RecordingLock.parse(_prefs.read(key)),
      write: (RecordingLock? lock) => _prefs.write(key, lock?.name ?? ''),
    );
  }

  /// The framing sheet's fill behind a zoomed-out source, per canvas
  /// (`framingBlurPortrait`, `framingBlurLandscape`): blur by default on a
  /// portrait canvas, black on a landscape one.
  Setting<FrameFill> framingFill(VideoOrientation canvas) {
    final PrefKey<bool> key = switch (canvas) {
      VideoOrientation.portrait => PrefKeys.framingBlurPortrait,
      VideoOrientation.landscape => PrefKeys.framingBlurLandscape,
    };
    return Setting<FrameFill>(
      read: () => _prefs.read(key) ? FrameFill.blur : FrameFill.black,
      write: (FrameFill fill) => _prefs.write(key, fill == FrameFill.blur),
    );
  }

  /// Import through the gallery picker. Also decides that the picked file is
  /// the user's original on Android and must never be deleted.
  late final Setting<bool> useExperimentalPicker = _stored(
    PrefKeys.useExperimentalPicker,
  );

  /// Filter the gallery picker by the selected day.
  late final Setting<bool> useFilterInExperimentalPicker = _stored(
    PrefKeys.useFilterInExperimentalPicker,
  );

  /// Blue/yellow Diary colours.
  late final Setting<bool> useAlternativeCalendarColors = _stored(
    PrefKeys.useAlternativeCalendarColors,
  );

  /// Write verbose log lines.
  late final Setting<bool> verboseLogging = _stored(PrefKeys.verboseLogging);

  /// The Diary plays the selected clip on its own: the user's last play or
  /// pause. Set it only when the user taps play or pause, never for a pause
  /// the app makes itself (before a dialog).
  late final Setting<bool> calendarAutoPlay = _stored(
    PrefKeys.calendarAutoPlay,
  );

  /// The Diary plays the selected clip with sound: the user's last mute
  /// choice. Set it only when the user mutes or unmutes.
  late final Setting<bool> calendarAutoSound = _stored(
    PrefKeys.calendarAutoSound,
  );

  /// The Diary tab shows Memories instead of the calendar
  /// (`diaryMemoriesView`): the view the user picked last, which the Diary
  /// opens in.
  late final Setting<bool> diaryMemoriesView = _stored(
    PrefKeys.diaryMemoriesView,
  );

  /// My movies shows one large movie a row instead of the grid
  /// (`moviesLargeView`): the view picked last.
  late final Setting<bool> moviesLargeView = _stored(PrefKeys.moviesLargeView);

  /// The optional name used in greetings; `''` means none, and every
  /// greeting then uses its variant without a name. Stored trimmed, so a
  /// blank entry clears it.
  late final Setting<String> userName = Setting<String>(
    read: () => _prefs.read(PrefKeys.userName),
    write: (String name) => _prefs.write(PrefKeys.userName, name.trim()),
  );

  /// The character's look, as Today draws it; absent reads as the default
  /// look.
  late final Setting<CharacterLook> characterLook = Setting<CharacterLook>(
    read: () => CharacterLook.decode(_prefs.read(PrefKeys.characterLook)),
    write: (CharacterLook look) =>
        _prefs.write(PrefKeys.characterLook, look.encode()),
  );

  /// The epoch day of the last visit to Today; null before the first.
  late final Setting<int?> todayLastVisit = _stored(PrefKeys.todayLastVisit);

  /// A setting stored as is under [key].
  Setting<T> _stored<T>(PrefKey<T> key) => Setting<T>(
    read: () => _prefs.read(key),
    write: (T value) => _prefs.write(key, value),
  );
}
