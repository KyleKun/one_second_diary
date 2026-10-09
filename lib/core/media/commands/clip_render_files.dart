import 'package:equatable/equatable.dart';

/// Where one clip render reads and writes, all absolute paths. Each job has
/// its own scratch folder, so two jobs never clobber each other's files.
final class ClipRenderFiles extends Equatable {
  const ClipRenderFiles({
    required this.subtitles,
    required this.font,
    required this.dateText,
    required this.locationText,
    required this.output,
  });

  /// The SRT muxed as input 0: the subtitle text, or the placeholder cue.
  final String subtitles;

  /// The stamp font copied out of the assets (`StampFont.pathIn`).
  final String font;

  /// `date.txt` (`StampTextFiles.date`).
  final String dateText;

  /// `location.txt` (`StampTextFiles.location`); only read with geotagging
  /// on.
  final String locationText;

  /// The rendered clip, named like the clip it will be published as.
  final String output;

  @override
  List<Object?> get props => <Object?>[
    subtitles,
    font,
    dateText,
    locationText,
    output,
  ];
}
