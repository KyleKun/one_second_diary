import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';

void main() {
  test('tags are the exact values v1.x wrote into the comment metadata', () {
    expect(
      <String>[for (final ClipOrigin origin in ClipOrigin.values) origin.tag],
      <String>[
        'osd_recording',
        'gallery',
        'gallery_photo',
        'osd_recording_old',
        'import',
      ],
    );
    expect(ClipOrigin.galleryPhoto.comment, 'origin=gallery_photo');
    // A processed foreign video.
    expect(ClipOrigin.import.comment, 'origin=import');
    expect(ClipOrigin.fromComment('origin=import'), ClipOrigin.import);
  });

  test('fromComment reads it back; anything else is unknown', () {
    for (final ClipOrigin origin in ClipOrigin.values) {
      expect(ClipOrigin.fromComment(origin.comment), origin);
    }
    for (final String? comment in <String?>[
      null,
      '',
      'gallery',
      'origin=',
      'origin=camera',
      'Origin=gallery',
    ]) {
      expect(ClipOrigin.fromComment(comment), isNull, reason: '$comment');
    }
  });
}
