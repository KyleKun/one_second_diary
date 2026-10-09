import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';

void main() {
  test('a source is owned by the editor unless said otherwise (a kept '
      'original opened with Edit again is not), and the flag is part of '
      'its identity', () {
    const VideoSource temp = VideoSource(
      path: '/tmp/REC_1.mp4',
      ownership: ClipOwnership.cameraTemp,
    );
    const VideoSource original = VideoSource(
      path: '/originals/2024-01-05.mp4',
      ownership: ClipOwnership.cameraTemp,
      owned: false,
    );
    const PhotoSource photo = PhotoSource(
      path: '/tmp/IMG.jpg',
      ownership: ClipOwnership.pickerCopy,
    );

    expect(temp.owned, isTrue);
    expect(original.owned, isFalse);
    expect(photo.owned, isTrue);
    expect(temp.fromRecording, isTrue);
    expect(
      temp,
      isNot(
        const VideoSource(
          path: '/tmp/REC_1.mp4',
          ownership: ClipOwnership.cameraTemp,
          owned: false,
        ),
      ),
    );
  });
}
