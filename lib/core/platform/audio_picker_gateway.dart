import 'package:equatable/equatable.dart';

/// An audio file the user picked for a movie's music: where the app can
/// read it for the rest of the session, and the name to show.
final class PickedAudio extends Equatable {
  const PickedAudio({required this.path, required this.name});

  /// Absolute path of the app's own copy (the system hands out files it
  /// may clean up).
  final String path;

  /// The file's name as the user knows it (`song.mp3`).
  final String name;

  @override
  List<Object?> get props => <Object?>[path, name];
}

/// The system's file picker, for audio files (a movie's music).
///
/// The real implementation (`PluginAudioPickerGateway`, over `file_picker`)
/// is the only file that imports the plugin; everything above it is tested
/// with a fake.
abstract interface class AudioPickerGateway {
  /// Opens the picker for one or more audio files and returns the app's
  /// copies, in the order picked; empty when the user cancelled. Throws
  /// nothing: a file that cannot be read is left out and logged.
  Future<List<PickedAudio>> pickAudio();
}
