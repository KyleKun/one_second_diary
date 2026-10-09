import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/audio_picker_gateway.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// [AudioPickerGateway] over `file_picker` (the system document picker:
/// Android's file chooser, iOS's Files app). The only file that imports it.
///
/// The picker hands out a temporary copy the system may clean up, so each
/// file is copied under `AppPaths.scratchDir` (swept at the next launch)
/// and that copy's path is what the app keeps.
final class PluginAudioPickerGateway implements AudioPickerGateway {
  PluginAudioPickerGateway({
    required AppPaths paths,
    required Clock clock,
    required AppLogger logger,
  }) : this._(paths, clock, logger);

  PluginAudioPickerGateway._(this._paths, this._clock, this._logger);

  final AppPaths _paths;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'PICKER';

  @override
  Future<List<PickedAudio>> pickAudio() async {
    final List<PlatformFile> files;
    try {
      // Empty when the user cancels.
      files = await FilePicker.pickFiles(type: FileType.audio);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'The audio picker failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const <PickedAudio>[];
    }
    if (files.isEmpty) return const <PickedAudio>[];
    final Directory folder = Directory(
      '${_paths.scratchDir}/music-${_clock.now().microsecondsSinceEpoch}',
    );
    try {
      await folder.create(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not make a folder for the picked audio',
        error: error,
        stackTrace: stackTrace,
      );
      return const <PickedAudio>[];
    }
    final List<PickedAudio> picked = <PickedAudio>[];
    for (final (int index, PlatformFile file) in files.indexed) {
      final String? source = file.path;
      if (source == null) continue;
      try {
        final File copy = await File(
          source,
        ).copy('${folder.path}/$index-${file.name}');
        picked.add(PickedAudio(path: copy.path, name: file.name));
      } on FileSystemException catch (error, stackTrace) {
        _logger.warning(
          _tag,
          'Could not copy the picked audio ${file.name}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return picked;
  }
}
