import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/platform/still_photo_converter.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The text of the in-app picker's first grid cell: the latest [media], or
/// [media] from the day [from] on.
typedef PickerFirstCellLabel =
    String Function({required PickerMedia media, required LocalDay? from});

/// Turns a pick into the source of a new clip (Add video, Add photo, the
/// system camera), deciding which picker opens and who owns the file.
///
/// - **Which picker**: the in-app gallery picker unless "Use experimental
///   file picker" is off (then the system picker); its "Use date filter"
///   starts the in-app picker at a past day (never for today).
/// - **Who owns the file**: an Android in-app pick is the user's own gallery
///   file and is never deleted; an iOS in-app pick is a temp export; a
///   system-picker file is a cache copy; a system-camera recording is a
///   camera temp. The save deletes all but the first (`ClipStore`).
/// - **Photos ffmpeg cannot hold** (HEIC, HEIF, AVIF): rewritten as a PNG
///   in the app's temp folder (`StillPhotoConverter`), which the app then
///   owns; the pick it came from is deleted when it was the app's to
///   delete.
/// - **Self-import**: a pick that is the very clip a replace would overwrite
///   is refused. A clip picked again for its own day in add mode simply
///   becomes another clip.
/// - **The system camera**: below Android 10, and with "Force native
///   camera".
/// - **Lost picks**: what Android kept after killing the app while its
///   picker or camera was open; ask once at launch.
class ImportFlow {
  ImportFlow({
    required this._picker,
    required this._settings,
    required this._deviceInfo,
    required this._paths,
    required this._clock,
    required this._logger,
    required this._isAndroid,
    required this._isIOS,
    required this._firstCellLabel,
    this._stillPhotos,
  });

  final PickerGateway _picker;
  final SettingsRepository _settings;
  final DeviceInfoGateway _deviceInfo;
  final AppPaths _paths;
  final Clock _clock;
  final AppLogger _logger;
  final bool _isAndroid;
  final bool _isIOS;
  final PickerFirstCellLabel _firstCellLabel;

  /// Rewrites the photos ffmpeg cannot hold; null leaves every photo as
  /// picked.
  final StillPhotoConverter? _stillPhotos;

  static const String _tag = 'IMPORT';

  /// The Android SDK level below which the system camera is required.
  static const int systemCameraBelowSdk = 29;

  /// Add video for [day]; [mode] is what the save will do with it.
  Future<ImportResult> pickVideo(
    BuildContext context, {
    required LocalDay day,
    ClipSaveMode mode = const AddClip(),
  }) => _pick(context, media: PickerMedia.video, day: day, mode: mode);

  /// Add photo for [day] (the photo becomes a still clip in a profile of
  /// [format]: a photo ffmpeg cannot hold is rewritten as a PNG bounded by
  /// `UiStillPhotoConverter.maxSideFor` that format).
  Future<ImportResult> pickPhoto(
    BuildContext context, {
    required LocalDay day,
    required ClipFormat format,
    ClipSaveMode mode = const AddClip(),
  }) => _pick(
    context,
    media: PickerMedia.photo,
    day: day,
    mode: mode,
    format: format,
  );

  /// Whether Record opens the system camera app instead of the in-app
  /// camera: below Android 10 (always), or with "Force native camera".
  Future<bool> usesSystemCamera() async =>
      _settings.forceNativeCamera.value || await systemCameraRequired();

  /// Whether this phone must use the system camera: Android below 10, where
  /// the settings show "Force native camera" on and locked.
  Future<bool> systemCameraRequired() async {
    final int? sdk = await _deviceInfo.androidSdkInt();
    return sdk != null && sdk < systemCameraBelowSdk;
  }

  /// The day it is now: a clip the system camera app brings back belongs
  /// to the day it came back on, as a take of the in-app camera belongs to
  /// the day it stopped.
  LocalDay today() => LocalDay.fromDateTime(_clock.now());

  /// Records with the system camera app; the file is a camera temp.
  Future<ImportResult> recordWithSystemCamera() async => _resultOf(
    await _picker.recordWithSystemCamera(),
    (String path) =>
        VideoSource(path: path, ownership: ClipOwnership.cameraTemp),
  );

  /// A pick Android kept after it killed the app, or null. A video is taken
  /// for a system-camera recording (the path API 26–28 phones always take),
  /// a photo for a system-picker copy; both are app temps. It belongs to the
  /// day its file was written, or today when the file says nothing.
  Future<RecoveredClip?> recoverLostPick() async {
    final LostPick? lost = await _picker.retrieveLostPick();
    if (lost == null) return null;
    _logger.info(_tag, 'Recovered a ${lost.media.name} lost while away');
    final ClipSource source = switch (lost.media) {
      PickerMedia.video => VideoSource(
        path: lost.path,
        ownership: ClipOwnership.cameraTemp,
      ),
      PickerMedia.photo => PhotoSource(
        path: lost.path,
        ownership: ClipOwnership.pickerCopy,
      ),
    };
    // The day the lost file was written, read before a rewrite replaces it.
    final LocalDay day = await _writtenOn(lost.path);
    // A lost photo's profile is not known here: the converter's default
    // bound, which every format keeps at least.
    final ClipSource? usable = await _usable(source, null);
    return usable == null ? null : RecoveredClip(source: usable, day: day);
  }

  Future<LocalDay> _writtenOn(String path) async {
    try {
      return LocalDay.fromDateTime(await File(path).lastModified());
    } on FileSystemException {
      return LocalDay.fromDateTime(_clock.now());
    }
  }

  Future<ImportResult> _pick(
    BuildContext context, {
    required PickerMedia media,
    required LocalDay day,
    required ClipSaveMode mode,
    ClipFormat? format,
  }) async {
    final bool inApp = _settings.useExperimentalPicker.value;
    final PickerOutcome outcome;
    final ClipOwnership ownership;
    if (inApp) {
      final LocalDay? from = _filterFrom(day);
      outcome = await _picker.pickFromGallery(
        context,
        media: media,
        from: from?.toLocalDateTime(),
        firstCellLabel: _firstCellLabel(media: media, from: from),
      );
      ownership = _isIOS && !_isAndroid
          ? ClipOwnership.platformExport
          : ClipOwnership.userOriginal;
    } else {
      outcome = await _picker.pickWithSystemPicker(media: media);
      ownership = ClipOwnership.pickerCopy;
    }
    if (outcome case Picked(
      :final String path,
    ) when await _isReplaceTarget(path, mode)) {
      _logger.warning(
        _tag,
        'Refused to import the clip being replaced as its own source',
      );
      return const ImportRejected();
    }
    final ImportResult result = _resultOf(
      outcome,
      (String path) => switch (media) {
        PickerMedia.video => VideoSource(path: path, ownership: ownership),
        PickerMedia.photo => PhotoSource(path: path, ownership: ownership),
      },
    );
    if (result is! ImportPicked) return result;
    final ClipSource? usable = await _usable(result.source, format);
    return usable == null ? const ImportUnavailable() : ImportPicked(usable);
  }

  /// [source], or its PNG copy when it is a photo ffmpeg cannot hold
  /// (bounded for the profile's [format], or the converter's default
  /// without one); null when that photo could not be rewritten.
  Future<ClipSource?> _usable(ClipSource source, ClipFormat? format) async {
    final StillPhotoConverter? converter = _stillPhotos;
    if (source is! PhotoSource ||
        converter == null ||
        !converter.needsConversion(source.path)) {
      return source;
    }
    final String target =
        '${_paths.temporaryDir}/photo-'
        '${_clock.now().microsecondsSinceEpoch}.png';
    try {
      await converter.toPng(
        source.path,
        target: target,
        maxSide: format == null
            ? UiStillPhotoConverter.maxSide
            : UiStillPhotoConverter.maxSideFor(format),
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not rewrite the picked photo as a PNG',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
    _logger.info(_tag, 'Rewrote the picked photo as a PNG for ffmpeg');
    if (source.ownership.deletableAfterSave) {
      try {
        await File(source.path).delete();
      } on FileSystemException {
        // A temp the system clears anyway.
      }
    }
    return PhotoSource(path: target, ownership: ClipOwnership.pickerCopy);
  }

  /// The day the in-app picker starts at: [day] when "Use date filter" is
  /// on and [day] is not today, else null (the latest items).
  LocalDay? _filterFrom(LocalDay day) {
    if (!_settings.useFilterInExperimentalPicker.value) return null;
    return day == LocalDay.fromDateTime(_clock.now()) ? null : day;
  }

  Future<bool> _isReplaceTarget(String path, ClipSaveMode mode) async {
    if (mode is! ReplaceClip) return false;
    final String target = _paths.absoluteFromVideos(mode.clip.relPath);
    return await _resolved(path) == await _resolved(target);
  }

  /// [path] with its links resolved, as the picker may hand out another
  /// spelling of the same file.
  static Future<String> _resolved(String path) async {
    try {
      return await File(path).resolveSymbolicLinks();
    } on FileSystemException {
      return File(path).absolute.path;
    }
  }

  static ImportResult _resultOf(
    PickerOutcome outcome,
    ClipSource Function(String path) source,
  ) => switch (outcome) {
    Picked(:final String path) => ImportPicked(source(path)),
    PickCancelled() => const ImportCancelled(),
    PickDenied() => const ImportDenied(),
    PickUnavailable() => const ImportUnavailable(),
  };
}
