// FramingCubit: the framing sheet's state. Every
// change is clamped by the geometry; the default framing reads as none;
// no gesture tests, the sheet passes canvas fractions.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/framing_cubit.dart';

/// A 16:9 recording on a 9:16 (1080p) canvas.
const ClipFrameGeometry _landscapeOnPortrait = ClipFrameGeometry(
  sourceWidth: 1920,
  sourceHeight: 1080,
  canvasWidth: 1080,
  canvasHeight: 1920,
);

/// A 4K recording on a 1080p landscape canvas: lossless up to 2×.
const ClipFrameGeometry _fourKOnLandscape = ClipFrameGeometry(
  sourceWidth: 3840,
  sourceHeight: 2160,
  canvasWidth: 1920,
  canvasHeight: 1080,
);

const double _cover = 1920 / 1080;

void main() {
  FramingCubit open({
    ClipFrameGeometry geometry = _landscapeOnPortrait,
    bool sizeKnown = true,
    ClipFrame? initial,
    FrameFill fill = FrameFill.blur,
  }) {
    final FramingCubit cubit = FramingCubit(
      geometry: geometry,
      sizeKnown: sizeKnown,
      initial: initial,
      defaultFill: fill,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('opens on the default framing with the remembered fill (cover on a '
      'portrait canvas, fit on a landscape one), which counts as default '
      'and as none; an existing frame opens as it is, clamped', () {
    final FramingCubit portrait = open();
    expect(portrait.state.frame.scale, closeTo(_cover, 1e-9));
    expect(portrait.state.frame.fill, FrameFill.blur);
    expect(portrait.state.isDefault, isTrue);
    expect(portrait.state.fills, isTrue);
    expect(portrait.state.atCover, isTrue);

    final FramingCubit landscape = open(
      geometry: _fourKOnLandscape,
      fill: FrameFill.black,
    );
    expect(landscape.state.frame.scale, 1);
    expect(landscape.state.atFit, isTrue);
    expect(landscape.state.isDefault, isTrue);

    final FramingCubit kept = open(
      initial: const ClipFrame(scale: 9, dx: 30, fill: FrameFill.black),
    );
    expect(kept.state.frame.scale, closeTo(_cover * 4, 1e-9));
    expect(kept.state.frame.dx, lessThan(30));
    expect(kept.state.isDefault, isFalse);
  });

  test('a double tap toggles fit and cover, centred; fit on a portrait '
      'canvas leaves bars, so a blur fill is no longer the default', () {
    final FramingCubit cubit = open()..doubleTapped();
    expect(cubit.state.atFit, isTrue);
    expect(cubit.state.fills, isFalse);
    expect(cubit.state.isDefault, isFalse);

    cubit.doubleTapped();
    expect(cubit.state.atCover, isTrue);
    expect(cubit.state.isDefault, isTrue);

    cubit
      ..doubleTapped()
      ..fillChanged(FrameFill.black);
    expect(cubit.state.frame.fill, FrameFill.black);
    expect(cubit.state.isDefault, isFalse);
  });

  test('a drag moves the picture within the clamps; a pinch zooms around '
      'the fingers, within fit and the close crop', () {
    final FramingCubit cubit = open()..zoomTo(_cover * 2);
    expect(cubit.state.frame.scale, closeTo(_cover * 2, 1e-9));

    cubit.dragged(const Offset(0.1, 0.1));
    expect(cubit.state.frame.dx, closeTo(0.1, 1e-9));
    // At 2× cover the picture is two canvases high: half a canvas of room.
    expect(cubit.state.frame.dy, closeTo(0.1, 1e-9));
    cubit.dragged(const Offset(0, 5));
    expect(cubit.state.frame.dy, closeTo(0.5, 1e-9));

    // Pinching in at the centre from a centred frame keeps it centred.
    final FramingCubit pinched = open()..pinched(1.5, const Offset(0.5, 0.5));
    expect(pinched.state.frame.scale, closeTo(_cover * 1.5, 1e-9));
    expect(pinched.state.frame.dx, closeTo(0, 1e-9));
    expect(pinched.state.frame.dy, closeTo(0, 1e-9));

    // Pinching at the top-left corner: the corner stays, so the centre
    // moves away from it.
    final FramingCubit corner = open()..pinched(2, Offset.zero);
    expect(corner.state.frame.dx, greaterThan(0));
    expect(corner.state.frame.dy, greaterThan(0));

    // Past the close crop the scale stops; below fit it stops too.
    corner.pinched(100, const Offset(0.5, 0.5));
    expect(corner.state.frame.scale, closeTo(_cover * 4, 1e-9));
    corner.pinched(0.001, const Offset(0.5, 0.5));
    expect(corner.state.atFit, isTrue);
    corner.pinched(0, const Offset(0.5, 0.5));
    expect(corner.state.atFit, isTrue);
  });

  test('the lossless mark shows only when the size is known and a sharper '
      'source gives room; the buttons go to fit, cover and lossless; Reset '
      'is the default framing with the fill kept', () {
    final FramingCubit fourK = open(
      geometry: _fourKOnLandscape,
      fill: FrameFill.black,
    );
    expect(fourK.state.showsLossless, isTrue);
    expect(fourK.state.lossless, isTrue);

    fourK.losslessZoom();
    expect(fourK.state.frame.scale, 2);
    expect(fourK.state.lossless, isTrue);
    fourK.zoomTo(2.5);
    expect(fourK.state.lossless, isFalse);

    fourK
      ..cover()
      ..fillChanged(FrameFill.blur);
    expect(fourK.state.atCover, isTrue);
    fourK
      ..zoomTo(3)
      ..reset();
    expect(fourK.state.atFit, isTrue);
    expect(fourK.state.frame.fill, FrameFill.blur);
    // The same shape leaves no bar at fit, so the blur changes nothing:
    // still the default.
    expect(fourK.state.isDefault, isTrue);

    // The same shape, 1080p on 1080p: no room, no mark.
    expect(open(geometry: _landscapeOnPortrait).state.showsLossless, isFalse);
    expect(
      open(geometry: _fourKOnLandscape, sizeKnown: false).state.showsLossless,
      isFalse,
    );
  });

  test('the real size arriving keeps the frame on the new geometry, '
      'clamped', () {
    final FramingCubit cubit = open(
      geometry: const ClipFrameGeometry(
        sourceWidth: 1778,
        sourceHeight: 1000,
        canvasWidth: 1000,
        canvasHeight: 1778,
      ),
      sizeKnown: false,
    )..zoomTo(99);
    expect(cubit.state.showsLossless, isFalse);

    cubit.geometryChanged(_fourKOnLandscape, sizeKnown: true);
    expect(cubit.state.geometry, _fourKOnLandscape);
    expect(cubit.state.frame.scale, _fourKOnLandscape.maxZoom);
    expect(cubit.state.showsLossless, isTrue);
  });
}
