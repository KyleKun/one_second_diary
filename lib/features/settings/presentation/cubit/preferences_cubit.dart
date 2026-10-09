import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_state.dart';

/// Preferences: eight switches over [SettingsRepository], whose defaults
/// it reads (only the experimental picker is on).
///
/// Every change is stored at once and logged
/// (`[PREFERENCES] - <name> was enabled`), which bug reports rely on. The
/// switch moves before the write completes; a refused write puts it back.
///
/// "Keep original recordings" also shows about how much one recording adds
/// at the active profile's quality ([PreferencesState.perRecordingBytes]).
/// The "Original videos" group shows what the Originals folder holds
/// ([PreferencesState.originals]; one walk per launch, cached by the
/// [OriginalsStore] and walked again after a write there). [deleteOriginals]
/// empties the folder once the page has asked, and the store tells the
/// library, so Edit again is offered nowhere afterwards.
///
/// The consumers read the same settings when they need them (the import
/// flow, the camera, the Diary, the logger), so nothing else is told.
class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit({
    required SettingsRepository settings,
    required this._imports,
    required this._logger,
    OriginalsStore? originals,
    ClipFormat Function()? activeFormat,
  }) : _settings = settings,
       _originals = originals, // ignore: prefer_initializing_formals
       _activeFormat = activeFormat, // ignore: prefer_initializing_formals
       super(PreferencesState(stored: _storedIn(settings)));

  final SettingsRepository _settings;
  final ImportFlow _imports;
  final AppLogger _logger;

  /// The kept originals; null when the app keeps none (the row then shows
  /// no size).
  final OriginalsStore? _originals;

  /// The active profile's format, for "about X per recording"; null shows
  /// no such line.
  final ClipFormat Function()? _activeFormat;

  static const String _tag = 'PREFERENCES';

  /// Reads whether this phone must record with the system camera (Android
  /// below 10), where "Force native camera" shows on and locked, and the
  /// Originals folder's size. The page opens with the stored values
  /// meanwhile.
  Future<void> load() async {
    emit(state.copyWith(perRecordingBytes: _perRecordingBytes()));
    final bool required = await _imports.systemCameraRequired();
    if (!isClosed) emit(state.copyWith(nativeCameraRequired: required));
    final OriginalsStore? originals = _originals;
    if (originals == null) return;
    final OriginalsContents contents = await originals.contentsCached();
    if (!isClosed) emit(state.copyWith(originals: () => contents));
  }

  /// About the bytes one recording adds to the folder: the capture
  /// bitrate of the active profile's format (video and audio,
  /// `CaptureQuality`) over the camera's clip length; null without a
  /// format.
  int? _perRecordingBytes() {
    final ClipFormat? format = _activeFormat?.call();
    if (format == null) return null;
    final CaptureQuality capture = CaptureQuality.of(format);
    final int bitsPerSecond =
        capture.videoBitrate + CaptureQuality.audioBitrate;
    return (bitsPerSecond / 8 * _settings.recordingSeconds.value).ceil();
  }

  /// "Delete originals" (the page asked first): empties the folder through
  /// the store (the media store on Android); the group shows what is
  /// left, 0 videos when every file went. The clips stay as they are. A
  /// refusal is logged by the store and shows in what is left.
  Future<void> deleteOriginals() async {
    final OriginalsStore? originals = _originals;
    if (originals == null || state.deletingOriginals) return;
    emit(state.copyWith(deletingOriginals: true));
    final int deleted = await originals.deleteAll();
    _logger.info(_tag, '- Deleted $deleted original video(s)');
    final OriginalsContents left = await originals.contentsCached();
    if (!isClosed) {
      emit(state.copyWith(deletingOriginals: false, originals: () => left));
    }
  }

  /// Turns [preference] on or off: the switch moves at once, the value is
  /// stored, and the log line is written. A switch that can't change
  /// ([PreferencesState.isEnabled]) is left alone.
  ///
  /// Changing the in-app picker also turns the date filter off, so the
  /// filter never comes back on by itself: it shows off while the picker
  /// is off, and older installs may have left it stored on.
  Future<void> set(AppPreference preference, bool value) async {
    if (!state.isEnabled(preference)) return;
    final bool resetsFilter =
        preference == AppPreference.experimentalPicker &&
        (state.stored[AppPreference.filterByDate] ?? false);
    emit(
      state.copyWith(
        stored: <AppPreference, bool>{
          ...state.stored,
          preference: value,
          if (resetsFilter) AppPreference.filterByDate: false,
        },
        status: PreferencesStatus.saving,
      ),
    );
    try {
      await _store(preference, value);
      if (resetsFilter) await _store(AppPreference.filterByDate, false);
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not store ${preference.logName}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            stored: _storedIn(_settings),
            status: PreferencesStatus.saveFailed,
          ),
        );
      }
      return;
    }
    if (!isClosed) emit(state.copyWith(status: PreferencesStatus.ready));
  }

  Future<void> _store(AppPreference preference, bool value) async {
    await _settingOf(_settings, preference).set(value);
    _logger.info(
      _tag,
      '- ${preference.logName} was ${value ? 'enabled' : 'disabled'}',
    );
  }

  static Map<AppPreference, bool> _storedIn(SettingsRepository settings) =>
      <AppPreference, bool>{
        for (final AppPreference preference in AppPreference.values)
          preference: _settingOf(settings, preference).value,
      };

  static Setting<bool> _settingOf(
    SettingsRepository settings,
    AppPreference preference,
  ) => switch (preference) {
    AppPreference.forceNativeCamera => settings.forceNativeCamera,
    AppPreference.legacyStampFont => settings.legacyStampFont,
    AppPreference.clipDeviceInfo => settings.clipDeviceInfo,
    AppPreference.keepOriginals => settings.keepOriginals,
    AppPreference.experimentalPicker => settings.useExperimentalPicker,
    AppPreference.filterByDate => settings.useFilterInExperimentalPicker,
    AppPreference.alternativeCalendarColors =>
      settings.useAlternativeCalendarColors,
    AppPreference.verboseLogging => settings.verboseLogging,
  };
}
