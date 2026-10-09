import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// How a clip was made from its source: the trim
/// window, the framing, the stamp style, whether it was muted, and the
/// format it was rendered in. Stored in the metadata sidecar beside a clip
/// that keeps its original recording, so "Edit again" opens the editor
/// pre-filled; applied clamped field by field, a part that no longer fits
/// the source is dropped.
///
/// The JSON form, under the sidecar's `recipe` key:
///
/// ```json
/// {"trimStartMs": 0, "trimEndMs": 1500,
///  "frame": {"scale": 1.0, "dx": 0.0, "dy": 0.0, "fill": "black"},
///  "source": {"width": 1920, "height": 1080},
///  "stamp": {"format": "numeric", "rgb": 16777215, "outline": true,
///            "size": "medium"},
///  "mute": false, "format": "1080p30-h264-mono-sdr",
///  "orientation": "landscape", "sourceColorTransfer": "arib-std-b67"}
/// ```
///
/// `frame` is absent for a clip framed by default; `source` (the source's
/// upright size the frame was made on, as the engine's `SourceFrame`
/// carries it) goes with it, so a render from the source needs no probe.
/// `sourceColorTransfer` (the source's probed transfer, present only for
/// an HDR source) lets the converter render from the source with the
/// right range conversion (`RangeFilter`) without a probe either; absent
/// reads as SDR.
/// The stamp's `size` (a `StampSize` token) reads as medium when missing or
/// unknown. `orientation` carries the canvas the format string leaves out.
/// Pure: nothing here touches files or Flutter. The clip store writes it
/// when a save keeps its source; the editor prefills from it and the
/// profile converter renders from the source with it.
final class ClipRecipe extends Equatable {
  const ClipRecipe({
    required this.trimStartMs,
    required this.trimEndMs,
    required this.frame,
    required this.stampStyle,
    required this.mute,
    required this.format,
    this.sourceWidth,
    this.sourceHeight,
    this.sourceColorTransfer,
  });

  /// The window kept, in ms of the source; the end is exactly where the
  /// clip ends.
  final int trimStartMs;
  final int trimEndMs;

  /// The framing on the format's canvas; null for the default framing.
  final ClipFrame? frame;

  /// The source's upright size [frame] was made on, in pixels; null
  /// without a frame, or when the editor could not read it.
  final int? sourceWidth;
  final int? sourceHeight;

  /// [frame] with its source size, as the engine renders it; null without
  /// a frame or without the size.
  SourceFrame? get sourceFrame {
    final ClipFrame? framed = frame;
    final int? width = sourceWidth;
    final int? height = sourceHeight;
    if (framed == null || width == null || height == null) return null;
    return SourceFrame(frame: framed, sourceWidth: width, sourceHeight: height);
  }

  final StampStyle stampStyle;

  /// Whether the clip was saved without its sound.
  final bool mute;

  /// The format the clip was rendered in, with its canvas.
  final ClipFormat format;

  /// The source's `color_transfer` as the save's request carried it
  /// (`ClipRenderRequest.sourceColorTransfer`); null for SDR.
  final String? sourceColorTransfer;

  /// How [request] makes its clip: the window, the framing (without the
  /// source size, which the editor reads again), the stamp style, the
  /// mute and the format. Null for a photo: a still is never kept as a
  /// source.
  static ClipRecipe? of(ClipRenderRequest request) => switch (request) {
    VideoRender(:final int trimStartMs, :final int trimEndMs) => ClipRecipe(
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      frame: request.frame?.frame,
      sourceWidth: request.frame?.sourceWidth,
      sourceHeight: request.frame?.sourceHeight,
      stampStyle: request.stampStyle,
      mute: request.mute,
      format: request.format,
      sourceColorTransfer: request.sourceColorTransfer,
    ),
    PhotoRender() => null,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'trimStartMs': trimStartMs,
    'trimEndMs': trimEndMs,
    'frame': ?_frameToJson(frame),
    'source': ?_sourceToJson(),
    'stamp': <String, Object?>{
      'format': stampStyle.format.name,
      'rgb': stampStyle.rgb,
      'outline': stampStyle.outline,
      'size': stampStyle.size.token,
    },
    'mute': mute,
    'format': format.toString(),
    'orientation': format.orientation.name,
    'sourceColorTransfer': ?sourceColorTransfer,
  };

  /// The recipe in [json], or null for anything malformed (a missing or
  /// mistyped key, an unknown format): never a guess, the editor then
  /// opens with its defaults.
  static ClipRecipe? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final Object? start = json['trimStartMs'];
    final Object? end = json['trimEndMs'];
    final Object? stamp = json['stamp'];
    final Object? mute = json['mute'];
    final Object? format = json['format'];
    final Object? orientation = json['orientation'];
    if (start is! int ||
        end is! int ||
        start < 0 ||
        end <= start ||
        stamp is! Map<String, Object?> ||
        mute is! bool ||
        format is! String ||
        orientation is! String) {
      return null;
    }
    final VideoOrientation? canvas = VideoOrientation.values
        .where((VideoOrientation value) => value.name == orientation)
        .firstOrNull;
    if (canvas == null) return null;
    final ClipFormat? parsed = ClipFormat.parse(format, canvas);
    final StampStyle? style = _stampFromJson(stamp);
    if (parsed == null || style == null) return null;
    final Object? frameJson = json['frame'];
    final ClipFrame? frame = frameJson == null
        ? null
        : _frameFromJson(frameJson);
    if (frameJson != null && frame == null) return null;
    final ({int width, int height})? source = _sourceFromJson(json['source']);
    final Object? transfer = json['sourceColorTransfer'];
    return ClipRecipe(
      trimStartMs: start,
      trimEndMs: end,
      frame: frame,
      sourceWidth: frame == null ? null : source?.width,
      sourceHeight: frame == null ? null : source?.height,
      stampStyle: style,
      mute: mute,
      format: parsed,
      // A value of another type is not a transfer: read as SDR, never as
      // a reason to drop the recipe.
      sourceColorTransfer: transfer is String && transfer.isNotEmpty
          ? transfer
          : null,
    );
  }

  Map<String, Object?>? _sourceToJson() {
    final int? width = sourceWidth;
    final int? height = sourceHeight;
    if (frame == null || width == null || height == null) return null;
    return <String, Object?>{'width': width, 'height': height};
  }

  /// The source size in [json]; null when absent or malformed (the frame
  /// is then applied without it: the editor reads the size again, the
  /// converter renders without the frame).
  static ({int width, int height})? _sourceFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final Object? width = json['width'];
    final Object? height = json['height'];
    if (width is! int || height is! int || width <= 0 || height <= 0) {
      return null;
    }
    return (width: width, height: height);
  }

  static Map<String, Object?>? _frameToJson(ClipFrame? frame) => frame == null
      ? null
      : <String, Object?>{
          'scale': frame.scale,
          'dx': frame.dx,
          'dy': frame.dy,
          'fill': frame.fill.name,
        };

  static ClipFrame? _frameFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final Object? scale = json['scale'];
    final Object? dx = json['dx'];
    final Object? dy = json['dy'];
    final Object? fill = json['fill'];
    if (scale is! num || dx is! num || dy is! num || fill is! String) {
      return null;
    }
    final FrameFill? parsedFill = FrameFill.values
        .where((FrameFill value) => value.name == fill)
        .firstOrNull;
    if (parsedFill == null || scale <= 0) return null;
    return ClipFrame(
      scale: scale.toDouble(),
      dx: dx.toDouble(),
      dy: dy.toDouble(),
      fill: parsedFill,
    );
  }

  static StampStyle? _stampFromJson(Map<String, Object?> json) {
    final Object? format = json['format'];
    final Object? rgb = json['rgb'];
    final Object? outline = json['outline'];
    if (format is! String || rgb is! int || outline is! bool) return null;
    final StampFormat? parsed = StampFormat.values
        .where((StampFormat value) => value.name == format)
        .firstOrNull;
    if (parsed == null) return null;
    final Object? size = json['size'];
    return StampStyle(
      format: parsed,
      rgb: rgb & 0xFFFFFF,
      outline: outline,
      size: StampSize.fromToken(size is String ? size : ''),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    trimStartMs,
    trimEndMs,
    frame,
    sourceWidth,
    sourceHeight,
    stampStyle,
    mute,
    format,
    sourceColorTransfer,
  ];
}
