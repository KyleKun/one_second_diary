import 'dart:math' as math;

import 'package:one_second_diary/core/media/types/clip_format.dart';

/// The slow zoom-in of a photo clip: from the whole canvas to its centre,
/// [endScale] closer at the end, by the same ratio every frame.
abstract final class PhotoZoom {
  static const double _perSecond = .05;
  static const double _least = .05;
  static const double _most = .15;

  /// How much closer the last frame is than the first for a clip
  /// [durationMs] long: 5% a second, between 5% and 15%.
  static double endScale(int durationMs) =>
      1 + (_perSecond * durationMs / 1000).clamp(_least, _most);

  /// The zoom [progress] (0 to 1) through a clip [durationMs] long.
  static double scaleAt(double progress, {required int durationMs}) =>
      math.pow(endScale(durationMs), progress).toDouble();

  /// The `zoompan` chain for [format]'s canvas, [durationMs] long, placed
  /// after the canvas and before the stamps (which stay still).
  ///
  /// `zoompan` moves in whole input pixels (even ones in 4:2:0), which
  /// shakes a slow zoom: the canvas goes to 4:4:4 and, up to 1080p, is
  /// doubled first. `exp` keeps commas out of the expressions.
  static String filter(ClipFormat format, {required int durationMs}) {
    final int frames = math.max(
      2,
      (durationMs * format.fpsValue / 1000).round(),
    );
    final double rate = math.log(endScale(durationMs)) / (frames - 1);
    final String pixels = switch (format.range) {
      DynamicRange.sdr => 'yuv444p',
      DynamicRange.hlg => 'yuv444p10le',
    };
    final String upscale = format.shortSide <= 1080
        ? 'scale=iw*2:ih*2:flags=bicubic,'
        : '';
    return '${upscale}format=$pixels,'
        'zoompan=z=exp($rate*on):x=iw/2-iw/zoom/2:y=ih/2-ih/zoom/2:'
        'd=1:s=${format.width}x${format.height}:fps=${format.fpsValue}';
  }
}
