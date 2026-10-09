import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:one_second_diary/core/media/types/clip_format.dart';

/// Rewrites a photo ffmpeg cannot hold as a still into one it can.
///
/// ffmpeg loops a still only from its plain image formats (JPEG, PNG, …).
/// A HEIC, HEIF or AVIF photo comes through another demuxer, as a grid of
/// tiles, and the save fails ("Option loop not found"). The phone can
/// decode those, so the photo is decoded here and written as a PNG.
abstract interface class StillPhotoConverter {
  /// Whether the photo at [path] has to go through [toPng].
  bool needsConversion(String path);

  /// Decodes the photo at [source] upright and writes it to [target] as a
  /// PNG, scaled down when its longer side is over [maxSide]
  /// ([UiStillPhotoConverter.maxSideFor] of the profile's format; the
  /// 1080p bound unless given). Throws when the photo cannot be decoded or
  /// the file cannot be written.
  Future<void> toPng(
    String source, {
    required String target,
    int maxSide = UiStillPhotoConverter.maxSide,
  });
}

/// [StillPhotoConverter] over Flutter's image codecs, which use the
/// platform's decoders for HEIC, HEIF and AVIF.
final class UiStillPhotoConverter implements StillPhotoConverter {
  const UiStillPhotoConverter();

  /// The longer side of the PNG for a 1080p profile: above the 1920 of its
  /// canvas, so the clip loses nothing, and far below a 12 MP photo's
  /// 4032, which would take seconds to write.
  static const int maxSide = 2560;

  /// The most any canvas asks for.
  static const int largestSide = 4096;

  /// The longer side of the PNG for [format]: its canvas's long side, at
  /// least [maxSide] (so a 1080p profile keeps today's bound and a close
  /// crop its detail) and never over [largestSide]; 3840 for 4K.
  static int maxSideFor(ClipFormat format) =>
      format.longSide.clamp(maxSide, largestSide);

  static const Set<String> _extensions = <String>{'heic', 'heif', 'avif'};

  @override
  bool needsConversion(String path) {
    final int dot = path.lastIndexOf('.');
    return dot >= 0 &&
        _extensions.contains(path.substring(dot + 1).toLowerCase());
  }

  @override
  Future<void> toPng(
    String source, {
    required String target,
    int maxSide = maxSide,
  }) async {
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromFilePath(
      source,
    );
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
      buffer,
    );
    // One side given: the other keeps the photo's shape.
    final bool wide = descriptor.width >= descriptor.height;
    final int longer = wide ? descriptor.width : descriptor.height;
    final int? side = longer > maxSide ? maxSide : null;
    final ui.Codec codec = await descriptor.instantiateCodec(
      targetWidth: wide ? side : null,
      targetHeight: wide ? null : side,
    );
    try {
      final ui.Image image = (await codec.getNextFrame()).image;
      try {
        final ByteData? png = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) {
          throw FileSystemException('Could not encode the photo', source);
        }
        await File(target).writeAsBytes(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          flush: true,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
