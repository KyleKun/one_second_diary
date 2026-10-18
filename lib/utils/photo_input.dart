import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import 'utils.dart';

/// Gets a picked photo into a form ffmpeg can turn into a clip.
///
/// The photo-as-video command repeats the photo with `-loop 1`, an option
/// only ffmpeg's image2 demuxer has. HEIC/HEIF and AVIF photos are ISOBMFF
/// containers that ffmpeg opens with the mov demuxer instead, which rejects
/// it with "Option loop not found" (GIFs have their own demuxer too). Those
/// photos are decoded by Flutter, which already shows them in the preview,
/// and handed to ffmpeg as a PNG.
class PhotoInput {
  PhotoInput._();

  static const String _logTag = '[PhotoInput] - ';

  /// Extensions ffmpeg's image2 demuxer reads, which `-loop 1` works on.
  static const Set<String> _loopableExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'tif',
    'tiff',
  };

  /// The converted photo's shorter side is capped at this. It still covers
  /// a 1080x1920 canvas after a portrait profile crops a landscape photo,
  /// and keeps a 12+ MP photo quick to encode.
  static const int maxShortSide = 1920;

  /// Whether ffmpeg can loop the photo at [path] as is.
  static bool isLoopable(String path) {
    final String name = path.split('/').last;
    final int dot = name.lastIndexOf('.');
    if (dot == -1) return false;
    return _loopableExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  /// The width and height to decode a [width]x[height] photo at, capping
  /// its shorter side at [maxShortSide]. A null side is left for the decoder
  /// to work out from the aspect ratio; both null keeps the original size.
  static (int?, int?) targetSize(int width, int height) {
    if (math.min(width, height) <= maxShortSide) return (null, null);
    return width <= height ? (maxShortSide, null) : (null, maxShortSide);
  }

  /// The path to give ffmpeg for the photo at [path]: the photo itself when
  /// ffmpeg can loop it, otherwise a PNG copy in the cache. Falls back to
  /// [path] if the photo can't be converted.
  static Future<String> prepare(String path) async {
    if (isLoopable(path)) return path;
    try {
      final String converted = await _convertToPng(path);
      Utils.logInfo('${_logTag}Converted $path to $converted');
      return converted;
    } catch (e) {
      Utils.logError('${_logTag}Could not convert $path, using it as is: $e');
      return path;
    }
  }

  static Future<String> _convertToPng(String path) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromFilePath(
      path,
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final (int? targetWidth, int? targetHeight) = targetSize(
        descriptor.width,
        descriptor.height,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('PNG encoding returned no data');

      final Directory cache = await getTemporaryDirectory();
      final File output = File('${cache.path}/photo_input.png');
      await output.writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        flush: true,
      );
      return output.path;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
