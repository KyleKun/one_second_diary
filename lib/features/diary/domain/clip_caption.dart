import 'package:equatable/equatable.dart';

/// What a clip says about itself: its soft [subtitle] and the [location]
/// of its geotag, each null when it has none. The caption row and the
/// Memories cards show the subtitle, else the place; the viewer shows both.
final class ClipCaption extends Equatable {
  const ClipCaption({this.subtitle, this.location});

  /// Nothing known.
  static const ClipCaption none = ClipCaption();

  final String? subtitle;
  final String? location;

  @override
  List<Object?> get props => <Object?>[subtitle, location];
}
