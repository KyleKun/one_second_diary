import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';

/// The framing sheet's state: the frame under the fingers, on its
/// geometry.
final class FramingState extends Equatable {
  const FramingState({
    required this.frame,
    required this.geometry,
    required this.sizeKnown,
  });

  final ClipFrame frame;

  /// The source on the canvas; with the source's real pixels when
  /// [sizeKnown], else its shape at the canvas's size (the lossless mark is
  /// then not shown: it would be a guess).
  final ClipFrameGeometry geometry;

  final bool sizeKnown;

  /// Whether [frame] is today's default framing, stored as none.
  bool get isDefault => geometry.isDefault(frame);

  /// Whether the picture covers the canvas (no bars).
  bool get fills => geometry.fills(frame);

  /// Whether the frame shows the whole source, at fit.
  bool get atFit =>
      (frame.scale - geometry.fitScale).abs() <= FramingCubit.sameScale;

  /// Whether the frame is exactly at cover.
  bool get atCover =>
      (frame.scale - geometry.coverScale).abs() <= FramingCubit.sameScale;

  /// Whether the lossless mark is on the slider: the size is known and the
  /// lossless scale lies within the slider's range (a source sharper than
  /// fit, not sharper than the close crop).
  bool get showsLossless =>
      sizeKnown &&
      geometry.losslessScale > geometry.fitScale + FramingCubit.sameScale &&
      geometry.losslessScale < geometry.maxZoom - FramingCubit.sameScale;

  /// Whether the frame enlarges no pixel.
  bool get lossless => sizeKnown && geometry.isLossless(frame.scale);

  FramingState copyWith({
    ClipFrame? frame,
    ClipFrameGeometry? geometry,
    bool? sizeKnown,
  }) => FramingState(
    frame: frame ?? this.frame,
    geometry: geometry ?? this.geometry,
    sizeKnown: sizeKnown ?? this.sizeKnown,
  );

  @override
  List<Object?> get props => <Object?>[frame, geometry, sizeKnown];
}

/// The framing sheet's frame, moved by its gestures and controls: pinch around the pinch centre, drag, double-tap fit ↔ cover,
/// the zoom slider, the fill switch, Reset. Every change is clamped by the geometry; the sheet commits the frame to the editor.
/// Pure: the sheet passes canvas fractions, no pixel arithmetic here.
class FramingCubit extends Cubit<FramingState> {
  FramingCubit({
    required ClipFrameGeometry geometry,
    required bool sizeKnown,
    required ClipFrame? initial,
    required FrameFill defaultFill,
  }) : super(
         FramingState(
           frame: geometry.clamp(
             initial ?? geometry.defaultFrame.copyWith(fill: defaultFill),
           ),
           geometry: geometry,
           sizeKnown: sizeKnown,
         ),
       );

  /// How close two scales must be to count as the same.
  static const double sameScale = 1e-6;

  /// The fingers' middle moved by [by] (fractions of the canvas): the
  /// picture follows the finger.
  void dragged(Offset by) => _set(
    state.frame.copyWith(
      dx: state.frame.dx + by.dx,
      dy: state.frame.dy + by.dy,
    ),
  );

  /// The fingers spread (above 1) or closed (below 1) by [ratio] around
  /// [focal] (fractions of the canvas): the point of the picture under the
  /// fingers stays where it is, as far as the clamps allow.
  void pinched(double ratio, Offset focal) {
    if (ratio <= 0 || !ratio.isFinite) return;
    final ClipFrame frame = state.frame;
    final double scale = state.geometry.clampScale(frame.scale * ratio);
    final double applied = scale / frame.scale;
    // The source's centre, in canvas fractions, keeps its distance to the
    // focal point scaled by what was applied.
    final double centreX = .5 + frame.dx;
    final double centreY = .5 + frame.dy;
    _set(
      frame.copyWith(
        scale: scale,
        dx: focal.dx - (focal.dx - centreX) * applied - .5,
        dy: focal.dy - (focal.dy - centreY) * applied - .5,
      ),
    );
  }

  /// A double-tap: cover when the picture leaves a bar, else fit; centred.
  void doubleTapped() => zoomTo(
    state.fills ? state.geometry.fitScale : state.geometry.coverScale,
    centred: true,
  );

  /// The zoom slider at [scale]: the picture keeps its position, clamped
  /// to the new scale ([centred] puts it back in the middle).
  void zoomTo(double scale, {bool centred = false}) => _set(
    state.frame.copyWith(
      scale: scale,
      dx: centred ? 0 : null,
      dy: centred ? 0 : null,
    ),
  );

  /// The fit, cover and lossless buttons (what the slider's marks do).
  void fit() => zoomTo(state.geometry.fitScale, centred: true);
  void cover() => zoomTo(state.geometry.coverScale, centred: true);
  void losslessZoom() => zoomTo(state.geometry.losslessScale);

  /// "Fill: black / blur".
  void fillChanged(FrameFill fill) => _set(state.frame.copyWith(fill: fill));

  /// Reset: today's default framing, with the fill kept (it is remembered
  /// apart).
  void reset() =>
      _set(state.geometry.defaultFrame.copyWith(fill: state.frame.fill));

  /// The source's real size came in (probed after the sheet opened): the
  /// same frame on the real geometry.
  void geometryChanged(ClipFrameGeometry geometry, {required bool sizeKnown}) {
    emit(
      state.copyWith(
        geometry: geometry,
        sizeKnown: sizeKnown,
        frame: geometry.clamp(state.frame),
      ),
    );
  }

  void _set(ClipFrame frame) =>
      emit(state.copyWith(frame: state.geometry.clamp(frame)));
}
