import 'package:equatable/equatable.dart';

/// The part of a source the clip keeps, in fractions (0 to 1) of the source
/// as it is shown: upright, after the phone's rotation.
///
/// The editor makes it in the shape of the profile's canvas, so the part
/// fills the canvas without bars.
final class ClipCrop extends Equatable {
  const ClipCrop({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// Whether nothing is cut: the part is the whole source.
  bool get isWhole => width >= _whole && height >= _whole;

  static const double _whole = .9995;

  @override
  List<Object?> get props => <Object?>[left, top, width, height];
}
