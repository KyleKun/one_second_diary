import 'package:equatable/equatable.dart';

/// Music for a movie (`MovieRenderRequest.music`): audio files the user
/// picked, played in order and repeated until the movie ends, mixed at
/// [volume] over the videos' own sound ([keepClipSound]) or in its place.
///
/// The movie then carries TWO audio tracks: the mix first, as the default,
/// and the videos' own sound second, so "music off" later is a stream-copy
/// swap of the two (`MovieAudioCommands.swap`), never a new render.
final class MovieMusic extends Equatable {
  const MovieMusic({
    required this.tracks,
    this.volume = defaultVolume,
    this.keepClipSound = true,
  });

  /// The music volume the sheet opens with: under the videos' sound.
  static const double defaultVolume = 0.5;

  /// How long the music fades out at the movie's end, so a loop never ends
  /// mid-bar.
  static const int fadeOutMs = 2000;

  /// Absolute paths of the audio files, in play order; at least one.
  final List<String> tracks;

  /// 0 (silent) to 1 (as the file is).
  final double volume;

  /// Whether the videos' own sound plays under the music; false makes the
  /// mix the music alone (the videos' sound is still the second track).
  final bool keepClipSound;

  MovieMusic copyWith({
    List<String>? tracks,
    double? volume,
    bool? keepClipSound,
  }) => MovieMusic(
    tracks: tracks ?? this.tracks,
    volume: volume ?? this.volume,
    keepClipSound: keepClipSound ?? this.keepClipSound,
  );

  @override
  List<Object?> get props => <Object?>[tracks, volume, keepClipSound];
}
