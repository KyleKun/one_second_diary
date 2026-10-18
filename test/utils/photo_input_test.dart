import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/utils/photo_input.dart';

void main() {
  group('isLoopable', () {
    test('accepts formats the image2 demuxer reads', () {
      expect(PhotoInput.isLoopable('/DCIM/Camera/IMG_1.jpg'), isTrue);
      expect(PhotoInput.isLoopable('/DCIM/Camera/IMG_1.JPEG'), isTrue);
      expect(PhotoInput.isLoopable('/Pictures/Screenshot.png'), isTrue);
      expect(PhotoInput.isLoopable('/Pictures/sticker.webp'), isTrue);
    });

    test('rejects HEIC and other containers ffmpeg cannot loop', () {
      expect(
        PhotoInput.isLoopable('/Pictures/Messages/IMG_20261010_071816.heic'),
        isFalse,
      );
      expect(PhotoInput.isLoopable('/DCIM/Camera/IMG_1.HEIF'), isFalse);
      expect(PhotoInput.isLoopable('/DCIM/Camera/IMG_1.avif'), isFalse);
      expect(PhotoInput.isLoopable('/Download/funny.gif'), isFalse);
    });

    test('rejects a name without an extension', () {
      expect(PhotoInput.isLoopable('/cache/image_picker123'), isFalse);
      expect(PhotoInput.isLoopable('/cache.dir/image'), isFalse);
    });
  });

  group('targetSize', () {
    test('keeps photos that are already small enough', () {
      expect(PhotoInput.targetSize(1920, 1080), (null, null));
      expect(PhotoInput.targetSize(1920, 1920), (null, null));
    });

    test('caps the shorter side of a large photo', () {
      expect(PhotoInput.targetSize(4032, 3024), (null, 1920));
      expect(PhotoInput.targetSize(3024, 4032), (1920, null));
      expect(PhotoInput.targetSize(4000, 4000), (1920, null));
    });
  });
}
