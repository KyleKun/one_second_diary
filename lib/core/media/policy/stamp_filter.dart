import 'package:one_second_diary/core/media/policy/canvas_filter.dart';
import 'package:one_second_diary/core/media/policy/ffmpeg_color.dart';
import 'package:one_second_diary/core/media/policy/range_filter.dart';
import 'package:one_second_diary/core/media/types/clip_crop.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';

/// The picture filter of a clip save: a plain chain for `-vf` (the canvas
/// fit, then the stamps), or a graph for `-filter_complex` (a blur-filled
/// frame, then the stamps), whose output is labelled `[v]` and mapped
/// instead of the source's video stream.
typedef VideoFilter = ({bool complex, String value});

/// The picture filter of a clip save: the canvas fit (or the editor's
/// frame), the date stamp and, with geotagging on, the place name.
///
/// The text comes from files (`textfile=`, never `text=`, so it never passes
/// through filtergraph escaping), and both drawtext filters end with
/// `:expansion=none`: drawtext's default expansion would still read `%{…}`
/// and `\` in the FILE, so a typed place such as "100% home" would fail or
/// change.
///
/// Other details:
/// - `fontsize=`, the margins and `borderw=` scale with the canvas
///  : `k = shortSide / 1080`, 40k px of type and margin,
///   1k px of outline, rounded to whole pixels; `fontsize` and `borderw`
///   are printed as Dart doubles (`40.0`, `1.0`/`0.0`), so at 1080p the
///   argv is what earlier versions wrote; 80 px at 4K, 27 px at 720p.
///   The style's [StampSize] changes only the type: 32k or 48k px for a
///   small or a large stamp (both the date and the place); the margin and
///   the outline stay, so the stamp keeps its inset and its 1 px ring;
/// - `fontcolor='0x…'` keeps its single quotes (the filter parser strips
///   them); the outline is the RGB inverse of the date colour;
/// - numeric date top right (`x=w-tw-40:y=40`), written date bottom left
///   (`x=40:y=h-th-40`), place bottom right (`x=w-tw-40:y=h-th-40`);
/// - the date drawtext names `fontfile` first, the place one `textfile`
///   first, and the place joins with `", "` (comma and space).
///
/// Paths (font, text files) are app-controlled and must stay free of
/// `: , ' \ [ ] ;`. Spaces are fine: the value is one argument.
abstract final class StampFilter {
  /// The stamp's type size at the 1080p reference canvas, in px. The
  /// editor's preview scales it by its canvas width over the reference
  /// canvas's (`ClipFormat.width`), which is WYSIWYG at every
  /// tier since the stamp scales the same way ([fontSizeFor]).
  static const double fontSizePx = 40.0;

  /// How far the stamps sit from the canvas edges at the reference canvas,
  /// in px.
  static const int marginPx = 40;

  /// The contrast outline's width at the reference canvas, in px
  /// (`borderw`), in the RGB inverse of the stamp colour.
  static const double outlineWidthPx = 1.0;

  /// The short side of the reference canvas every size above is given at.
  static const int referenceShortSide = 1080;

  /// The stamp's type size on [format]'s canvas, in whole px: [size]'s
  /// base (40 for the medium every clip was burned with) scaled by the
  /// canvas.
  static int fontSizeFor(
    ClipFormat format, [
    StampSize size = StampSize.medium,
  ]) => _scaled(size.basePx, format);

  /// The stamps' distance from the canvas edges on [format]'s canvas.
  static int marginFor(ClipFormat format) => _scaled(marginPx, format);

  /// The outline's width on [format]'s canvas, in whole px.
  static int outlineWidthFor(ClipFormat format) => _scaled(1, format);

  static int _scaled(int px, ClipFormat format) =>
      (px * format.shortSide / referenceShortSide).round();

  /// The whole filter: `[in]<canvas>,<date>[, <place>][out]` for `-vf`,
  /// or, for a blur-filled [frame] with bars, the `-filter_complex` graph
  /// `[1:v]split…overlay,<date>[, <place>][v]`. The place drawtext is
  /// added when [locationTextPath] is given (geotagging on), even for an
  /// empty place. A [crop] or a [frame] cuts and places the source before
  /// the stamps, so the stamps are never cropped; a [frame] takes
  /// precedence over a [crop]. The source is input 1 of the save.
  ///
  /// A source whose range differs from the format's (an HDR import into
  /// an SDR profile, an SDR recording into an HLG one; [sourceColorTransfer]
  /// is what ffprobe said of the source, null for SDR) is converted FIRST
  /// (`RangeFilter`): the chain goes in front of the canvas, or, in the
  /// graph, on `[1:v]` before the split (`[1:v]<chain>[c];[c]split…`), so
  /// the blur, the frame and the stamps all work in the target's range.
  /// SDR into SDR adds nothing.
  ///
  /// A [motion] chain (a photo's zoom, `PhotoZoom.filter`) goes between the
  /// canvas and the stamps, so it moves the picture and never the stamps.
  static VideoFilter videoFilter({
    required ClipFormat format,
    ClipCrop? crop,
    SourceFrame? frame,
    required StampStyle style,
    required String fontPath,
    required String dateTextPath,
    required String? locationTextPath,
    String? sourceColorTransfer,
    String? motion,
  }) {
    final String moved = motion == null ? '' : ',$motion';
    final String? conversion = RangeFilter.conversionFor(
      format,
      sourceColorTransfer,
    );
    final int margin = marginFor(format);
    final String date = _drawtext(
      files: 'fontfile=$fontPath:textfile=$dateTextPath',
      style: style,
      format: format,
      position: switch (style.format) {
        StampFormat.numeric => 'x=w-tw-$margin:y=$margin',
        StampFormat.written => 'x=$margin:y=h-th-$margin',
      },
    );
    final String location = locationTextPath == null
        ? ''
        : ', ${_drawtext(files: 'textfile=$locationTextPath:fontfile=$fontPath', style: style, format: format, position: 'x=w-tw-$margin:y=h-th-$margin')}';
    final String? graph = frame == null
        ? null
        : CanvasFilter.blurGraph(
            format,
            frame,
            input: conversion == null ? '1:v' : 'c',
          );
    if (graph != null) {
      final String converted = conversion == null ? '' : '[1:v]$conversion[c];';
      return (complex: true, value: '$converted$graph$moved,$date$location[v]');
    }
    final String canvas = frame == null
        ? CanvasFilter.scaleFilter(format, crop: crop)
        : CanvasFilter.frameFilter(format, frame);
    final String picture = conversion == null ? canvas : '$conversion,$canvas';
    return (complex: false, value: '[in]$picture$moved,$date$location[out]');
  }

  static String _drawtext({
    required String files,
    required StampStyle style,
    required ClipFormat format,
    required String position,
  }) {
    final String color = FfmpegColor.hex(style.rgb);
    final String outlineColor = FfmpegColor.hex(style.rgb ^ 0xFFFFFF);
    final double fontSize = fontSizeFor(format, style.size).toDouble();
    final double outlineWidth = style.outline
        ? outlineWidthFor(format).toDouble()
        : 0.0;
    return 'drawtext=$files:fontsize=$fontSize:fontcolor=\'$color\':'
        'borderw=$outlineWidth:bordercolor=$outlineColor:$position:'
        'expansion=none';
  }
}
