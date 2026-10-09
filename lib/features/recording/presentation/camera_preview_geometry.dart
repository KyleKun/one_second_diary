import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where a tap on the cropped preview falls on the camera's picture (the
/// preview covers its box, centred).
abstract final class CameraPreviewGeometry {
  /// The point of the picture under [tap], in 0..1 each way, for a box of
  /// [box] showing a portrait picture whose width over height is
  /// 1 / [aspectRatio] (the sensor's width over height, [aspectRatio], is
  /// shown upright).
  static Offset pointAt(
    Offset tap, {
    required Size box,
    required double aspectRatio,
  }) {
    // The picture is 1 wide and aspectRatio tall, scaled to cover the box.
    final double scale = math.max(box.width, box.height / aspectRatio);
    final Size shown = Size(scale, scale * aspectRatio);
    final Offset origin = Offset(
      (box.width - shown.width) / 2,
      (box.height - shown.height) / 2,
    );
    final Offset point = tap - origin;
    return Offset(
      (point.dx / shown.width).clamp(0, 1),
      (point.dy / shown.height).clamp(0, 1),
    );
  }
}
