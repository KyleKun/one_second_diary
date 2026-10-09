import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Every preference the app reads or writes, with the exact name, storage
/// type and reader default existing installs use.
///
/// This is the migration contract with every existing install, pinned by
/// `test/core/storage/pref_keys_golden_test.dart`. Never rename a key, change
/// its type or its default, and never reuse a name in [deadNeverReuse].
/// String keys default to `''`: "absent" and "empty" read the same.
abstract final class PrefKeys {
  /// Tri-state: the user is onboarded if and only if this is `false`. Absent
  /// (`null`) and `true` both mean "show onboarding". Written after the
  /// Default profile exists.
  static const PrefKey<bool?> showIntro = PrefKey<bool?>(
    'showIntro',
    PrefType.boolean,
    null,
  );

  /// Ordered profile labels. Index 0 is the Default profile (folder key
  /// `''`, label conventionally `'Default'`); the others are the exact folder
  /// names under `Profiles/`. Older installs may hold it in the plugin's old
  /// list encoding; only the plugin decodes it, so always read it through
  /// [PrefsStore].
  static const PrefKey<List<String>> profiles = PrefKey<List<String>>(
    'profiles',
    PrefType.stringList,
    <String>['Default'],
  );

  /// Index of the active profile in [profiles]; 0 is Default.
  static const PrefKey<int> selectedProfileIndex = PrefKey<int>(
    'selectedProfileIndex',
    PrefType.integer,
    0,
  );

  /// The canvas of [profile]'s clips: `'landscape'` or `'portrait'`
  /// (`VideoOrientation.name`); absent or unknown means landscape. The Default
  /// profile's key is `orientation_` (empty suffix). Written once, when the
  /// profile is created; removed when it is deleted.
  static PrefKey<String> orientation(ProfileKey profile) =>
      PrefKey<String>('orientation_${profile.value}', PrefType.string, '');

  /// Days recorded in the active profile: its bare-name clips, `-N` clips
  /// not counted. Older builds force-unwrap it (no default), so it is kept
  /// written.
  static const PrefKey<int?> videoCount = PrefKey<int?>(
    'videoCount',
    PrefType.integer,
    null,
  );

  /// The NEXT movie number used in `OSD-Movie-<n>-<date>.mp4` (starts at 1;
  /// not a count). Older builds force-unwrap it (no default). Written as
  /// 1 + the highest `<n>` in `Movies/` after each movie, so a downgraded
  /// build never reuses a number.
  static const PrefKey<int?> movieCount = PrefKey<int?>(
    'movieCount',
    PrefType.integer,
    null,
  );

  /// "Today is recorded" for the active profile.
  static const PrefKey<bool> dailyEntry = PrefKey<bool>(
    'dailyEntry',
    PrefType.boolean,
    false,
  );

  /// `yyyy-MM-dd` of the day [dailyEntry] was last reset.
  static const PrefKey<String> today = PrefKey<String>(
    'today',
    PrefType.string,
    '',
  );

  /// Two-letter language code picked by the user; `''` means follow the
  /// device. May hold an unsupported code; resolve before use.
  static const PrefKey<String> lang = PrefKey<String>(
    'lang',
    PrefType.string,
    '',
  );

  /// Dark theme. Absent means dark for existing installs.
  static const PrefKey<bool> isDarkMode = PrefKey<bool>(
    'isDarkMode',
    PrefType.boolean,
    true,
  );

  static const PrefKey<bool> activatedNotification = PrefKey<bool>(
    'activatedNotification',
    PrefType.boolean,
    false,
  );

  /// Ongoing (non-dismissable) reminder. Android only.
  static const PrefKey<bool> persistentNotification = PrefKey<bool>(
    'persistentNotification',
    PrefType.boolean,
    false,
  );

  static const PrefKey<int> scheduledTimeHour = PrefKey<int>(
    'scheduledTimeHour',
    PrefType.integer,
    20,
  );

  static const PrefKey<int> scheduledTimeMinute = PrefKey<int>(
    'scheduledTimeMinute',
    PrefType.integer,
    0,
  );

  /// 3 s countdown before recording.
  static const PrefKey<bool> timer = PrefKey<bool>(
    'timer',
    PrefType.boolean,
    false,
  );

  /// Clip length in seconds. Readers clamp it to 2..10.
  static const PrefKey<int> recordingSeconds = PrefKey<int>(
    'recordingSeconds',
    PrefType.integer,
    2,
  );

  /// Last lens used.
  static const PrefKey<bool> recordWithFrontCamera = PrefKey<bool>(
    'recordWithFrontCamera',
    PrefType.boolean,
    false,
  );

  /// Stamp colour as `'r,g,b,a'` (0–255 each); `''` or unparsable means
  /// white. See `StampStyle.fromPrefs`.
  static const PrefKey<String> dateColor = PrefKey<String>(
    'dateColor',
    PrefType.string,
    '',
  );

  /// 0 = numeric date (top right), 1 = written date (bottom left).
  static const PrefKey<int> dateFormatId = PrefKey<int>(
    'dateFormatId',
    PrefType.integer,
    0,
  );

  /// Outline the stamp text in the inverted colour.
  static const PrefKey<bool> dateOutline = PrefKey<bool>(
    'dateOutline',
    PrefType.boolean,
    true,
  );

  /// Remembered geotag switch.
  static const PrefKey<bool> enableGeotagging = PrefKey<bool>(
    'enableGeotagging',
    PrefType.boolean,
    false,
  );

  /// Photo clip length in ms; only 1000/1500/2000/3000/5000/10000 are valid,
  /// anything else means 1000.
  static const PrefKey<int> photoDurationMs = PrefKey<int>(
    'photoDurationMs',
    PrefType.integer,
    1000,
  );

  /// Use the system camera app.
  static const PrefKey<bool> forceNativeCamera = PrefKey<bool>(
    'forceNativeCamera',
    PrefType.boolean,
    false,
  );

  /// Don't add the extra half second at the end of a trimmed clip.
  ///
  /// Unread: a clip always ends exactly where the trim ends. Listed for ever
  /// (older builds still read it; never rename or reuse the name).
  static const PrefKey<bool> strictClipLength = PrefKey<bool>(
    'strictClipLength',
    PrefType.boolean,
    false,
  );

  /// Gallery picker instead of the system picker. Also decides ownership of
  /// the picked file on Android: with it, the source is the user's original
  /// and must never be deleted. (On iOS the picker hands over an exported
  /// temp copy, which may be deleted.)
  static const PrefKey<bool> useExperimentalPicker = PrefKey<bool>(
    'useExperimentalPicker',
    PrefType.boolean,
    true,
  );

  /// Filter the gallery picker by the selected date.
  static const PrefKey<bool> useFilterInExperimentalPicker = PrefKey<bool>(
    'useFilterInExperimentalPicker',
    PrefType.boolean,
    false,
  );

  /// Blue/yellow Diary colours.
  static const PrefKey<bool> useAlternativeCalendarColors = PrefKey<bool>(
    'useAlternativeCalendarColors',
    PrefType.boolean,
    false,
  );

  /// Write verbose log lines.
  static const PrefKey<bool> verboseLogging = PrefKey<bool>(
    'verboseLogging',
    PrefType.boolean,
    false,
  );

  static const PrefKey<bool> calendarAutoPlay = PrefKey<bool>(
    'calendarAutoPlay',
    PrefType.boolean,
    true,
  );

  static const PrefKey<bool> calendarAutoSound = PrefKey<bool>(
    'calendarAutoSound',
    PrefType.boolean,
    true,
  );

  /// Android `Build.VERSION.SDK_INT`, written at each start; never written
  /// on iOS. Below 29 forces the native camera.
  static const PrefKey<int?> sdkVersion = PrefKey<int?>(
    'sdkVersion',
    PrefType.integer,
    null,
  );

  /// Current session log file NAME (not a path), `yyyy-MM-dd_HH-mm-ss.txt`;
  /// `''` means logging is not set up.
  static const PrefKey<String> currentLogFile = PrefKey<String>(
    'currentLogFile',
    PrefType.string,
    '',
  );

  /// `AppPaths.internal`, written every launch, never read.
  static const PrefKey<String> internalDirectoryPath = PrefKey<String>(
    'internalDirectoryPath',
    PrefType.string,
    '',
  );

  /// `AppPaths.videos` (with trailing `/`), written every launch, never read.
  static const PrefKey<String> appPath = PrefKey<String>(
    'appPath',
    PrefType.string,
    '',
  );

  /// `AppPaths.movies` (with trailing `/`), written every launch, never read.
  static const PrefKey<String> moviesPath = PrefKey<String>(
    'moviesPath',
    PrefType.string,
    '',
  );

  /// Optional user name for greetings; `''` means no name.
  /// Clearing the name writes `''` (like every other string key).
  static const PrefKey<String> userName = PrefKey<String>(
    'userName',
    PrefType.string,
    '',
  );

  /// JSON object with per-profile metadata (display name, photo), keyed by
  /// profile folder key. Paths inside are relative. Owned by the profiles
  /// repository.
  static const PrefKey<String> profileMeta = PrefKey<String>(
    'profileMeta',
    PrefType.string,
    '{}',
  );

  /// Burn new clips' stamps in Yusei Magic, the font of older versions,
  /// instead of Rubik.
  static const PrefKey<bool> legacyStampFont = PrefKey<bool>(
    'legacyStampFont',
    PrefType.boolean,
    false,
  );

  /// Note the phone, the app version and the moment in each new clip's
  /// `synopsis` tag (`ClipNotesTag`). On by default.
  static const PrefKey<bool> clipDeviceInfo = PrefKey<bool>(
    'clipDeviceInfo',
    PrefType.boolean,
    true,
  );

  /// The colours chosen for tags in Settings: a JSON object of
  /// `TagName.fold` key to a swatch index of `OsdMedia.stampSwatches`
  /// (`{"trip": 9}`). A tag without an entry takes a colour from its name.
  static const PrefKey<String> tagColors = PrefKey<String>(
    'tagColors',
    PrefType.string,
    '{}',
  );

  /// The places the user saved (Settings › Places, "Save this place" in the
  /// clip editor): a JSON list of `{"name": "Home", "lat": 48.85,
  /// "lon": 2.35, "uses": 3}`, the coordinates optional. Owned by
  /// `SavedPlaces`.
  static const PrefKey<String> savedPlaces = PrefKey<String>(
    'savedPlaces',
    PrefType.string,
    '[]',
  );

  /// Record with the front and the back camera at once, on a phone that
  /// can.
  static const PrefKey<bool> dualCamera = PrefKey<bool>(
    'dualCamera',
    PrefType.boolean,
    false,
  );

  /// The dual camera's layout: one camera over the other instead of a
  /// small picture in a corner.
  static const PrefKey<bool> dualCameraSplit = PrefKey<bool>(
    'dualCameraSplit',
    PrefType.boolean,
    false,
  );

  /// The Diary tab shows Memories instead of the calendar: the view the
  /// user picked last.
  static const PrefKey<bool> diaryMemoriesView = PrefKey<bool>(
    'diaryMemoriesView',
    PrefType.boolean,
    false,
  );

  /// My movies shows one large movie a row instead of the grid.
  static const PrefKey<bool> moviesLargeView = PrefKey<bool>(
    'moviesLargeView',
    PrefType.boolean,
    false,
  );

  /// Version of the data migrations applied; 0 = none.
  static const PrefKey<int> osdSchemaVersion = PrefKey<int>(
    'osdSchemaVersion',
    PrefType.integer,
    0,
  );

  /// The write-once format of [profile]'s clips, as `ClipFormat.toString`
  /// (`1080p30-h264-mono-sdr`); absent or unknown means
  /// `ClipFormat.legacy` on the profile's [orientation]. The Default
  /// profile's key is `clipFormat_` (empty suffix). Written once, when the
  /// profile is created; removed when it is deleted. [orientation] is still
  /// written beside it: older builds read that one.
  static PrefKey<String> clipFormat(ProfileKey profile) =>
      PrefKey<String>('clipFormat_${profile.value}', PrefType.string, '');

  /// How the camera starts for [profile] (`RecordingLock.name`: `auto`,
  /// `landscape` or `portrait`); absent means locked to the profile's own
  /// [orientation]. Written when the lock is toggled; removed with the
  /// profile.
  static PrefKey<String> recordingLock(ProfileKey profile) =>
      PrefKey<String>('recordingLock_${profile.value}', PrefType.string, '');

  /// The last quick cut tapped in the clip editor, in ms; the window an
  /// imported video opens on. Only a `QuickCuts.lengthsMs` value counts on
  /// read, anything else means 1500. Written by quick-cut taps only, never
  /// by a dragged handle.
  static const PrefKey<int> lastQuickCutMs = PrefKey<int>(
    'lastQuickCutMs',
    PrefType.integer,
    1500,
  );

  /// The framing sheet's fill behind a zoomed-out source, remembered per
  /// canvas: a blurred copy of the picture (true) or black bars. Blur by
  /// default on a portrait canvas, black on a landscape one.
  static const PrefKey<bool> framingBlurPortrait = PrefKey<bool>(
    'framingBlurPortrait',
    PrefType.boolean,
    true,
  );
  static const PrefKey<bool> framingBlurLandscape = PrefKey<bool>(
    'framingBlurLandscape',
    PrefType.boolean,
    false,
  );

  /// The phone check's result (`DeviceMediaProfile`) as a JSON object;
  /// `''` means the check never ran. Stale when the app version or the
  /// device model inside differs from this phone's.
  static const PrefKey<String> deviceMediaProfile = PrefKey<String>(
    'deviceMediaProfile',
    PrefType.string,
    '',
  );

  /// Keep every in-app recording untouched beside the diary
  /// (`AppPaths.originals`) after its clip is saved, for "Edit again".
  static const PrefKey<bool> keepOriginals = PrefKey<bool>(
    'keepOriginals',
    PrefType.boolean,
    false,
  );

  /// The processing sheet's remembered length choice: false keeps the
  /// first quick cut ([lastQuickCutMs]), true keeps the whole video up to
  /// 60 s.
  static const PrefKey<bool> importKeepWhole = PrefKey<bool>(
    'importKeepWhole',
    PrefType.boolean,
    false,
  );

  /// The processing sheet's remembered date-stamp choice: on by default.
  static const PrefKey<bool> importDateStamp = PrefKey<bool>(
    'importDateStamp',
    PrefType.boolean,
    true,
  );

  /// The one-time "What's new: quality" sheet is due on Today: set by the
  /// schema step that brought the formats to an install that already had
  /// profiles, cleared by the sheet whatever button closed it.
  static const PrefKey<bool> whatsNewQuality = PrefKey<bool>(
    'whatsNewQuality',
    PrefType.boolean,
    false,
  );

  /// How big the date and place stamps are burned into new clips, as a
  /// `StampSize` token (`'small'`, `'medium'`, `'large'`); `''` or an
  /// unknown token means medium, the 40 px at 1080p every clip was burned
  /// with. Chosen in the editor's date stamp sheet, beside [dateColor],
  /// [dateFormatId] and [dateOutline]. See `StampStyle.fromPrefs`.
  static const PrefKey<String> stampSize = PrefKey<String>(
    'stampSize',
    PrefType.string,
    '',
  );

  /// The character's look (shape, eyes, mouth, colour, hidden), as
  /// `CharacterLook.encode` writes it; `''` means the default look.
  static const PrefKey<String> characterLook = PrefKey<String>(
    'characterLook',
    PrefType.string,
    '',
  );

  /// The epoch day of the last visit to Today, for the character's
  /// "Welcome back"; absent before the first visit.
  static const PrefKey<int?> todayLastVisit = PrefKey<int?>(
    'todayLastVisit',
    PrefType.integer,
    null,
  );

  /// The coordinates looked up for typed place names ("Place them on the
  /// map"): a JSON object of `TagName.fold` key to
  /// `{"lat": 38.72, "lon": -9.14}`. Owned by `PlaceCoordinates`.
  static const PrefKey<String> placeCoordinates = PrefKey<String>(
    'placeCoordinates',
    PrefType.string,
    '{}',
  );

  /// The 31 fixed keys shared with older installs. The 32nd, [orientation],
  /// is one key per profile ([clipFormat] is another family, unknown to
  /// older installs).
  static const List<PrefKey<Object?>> legacyLive = <PrefKey<Object?>>[
    showIntro,
    profiles,
    selectedProfileIndex,
    videoCount,
    movieCount,
    dailyEntry,
    today,
    lang,
    isDarkMode,
    activatedNotification,
    persistentNotification,
    scheduledTimeHour,
    scheduledTimeMinute,
    timer,
    recordingSeconds,
    recordWithFrontCamera,
    dateColor,
    dateFormatId,
    dateOutline,
    enableGeotagging,
    photoDurationMs,
    forceNativeCamera,
    strictClipLength,
    useExperimentalPicker,
    useFilterInExperimentalPicker,
    useAlternativeCalendarColors,
    verboseLogging,
    calendarAutoPlay,
    calendarAutoSound,
    sdkVersion,
    currentLogFile,
  ];

  static const List<PrefKey<Object?>> legacyWriteOnlyPaths = <PrefKey<Object?>>[
    internalDirectoryPath,
    appPath,
    moviesPath,
  ];

  static const List<PrefKey<Object?>> v3 = <PrefKey<Object?>>[
    userName,
    profileMeta,
    legacyStampFont,
    clipDeviceInfo,
    tagColors,
    savedPlaces,
    dualCamera,
    dualCameraSplit,
    moviesLargeView,
    diaryMemoriesView,
    osdSchemaVersion,
    lastQuickCutMs,
    deviceMediaProfile,
    keepOriginals,
    framingBlurPortrait,
    framingBlurLandscape,
    importKeepWhole,
    importDateStamp,
    whatsNewQuality,
    stampSize,
    characterLook,
    todayLastVisit,
    placeCoordinates,
  ];

  /// Every fixed key ([orientation] and [clipFormat] excluded).
  static const List<PrefKey<Object?>> all = <PrefKey<Object?>>[
    ...legacyLive,
    ...legacyWriteOnlyPaths,
    ...v3,
  ];

  /// Names used by past versions and still present on some devices. Ignore
  /// them and never reuse them.
  static const List<String> deadNeverReuse = <String>[
    'showChangelogV15',
    'showChangelogV152',
    'isGeotaggingEnabled',
    'dateFormat',
  ];
}
