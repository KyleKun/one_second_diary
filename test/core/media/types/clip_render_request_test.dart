import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

const StampStyle _stamp = StampStyle(
  format: StampFormat.numeric,
  rgb: 0xFFFFFF,
  outline: true,
);

VideoRender _video({required bool fromRecording}) => VideoRender(
  sourcePath: '/tmp/REC1.mp4',
  fromRecording: fromRecording,
  trimStartMs: 0,
  trimEndMs: 2500,
  outputFileName: '2024-01-05.mp4',
  stampText: '05/01/2024',
  stampStyle: _stamp,
  legacyStampFont: false,
  location: const ClipLocation.off(),
  subtitles: '',
  format: const ClipFormat.legacy(VideoOrientation.landscape),
  albumLabel: 'Default',
);

void main() {
  test('a recording is tagged osd_recording, an import gallery, a photo '
      'gallery_photo', () {
    const PhotoRender photo = PhotoRender(
      photoPath: '/tmp/IMG.jpg',
      durationSeconds: 1.5,
      outputFileName: '2024-01-05-2.mp4',
      stampText: 'January 5, 2024',
      stampStyle: _stamp,
      legacyStampFont: false,
      location: ClipLocation(
        enabled: true,
        text: 'Tokyo, Japan',
        latitude: 35.71,
        longitude: 139.79,
      ),
      subtitles: 'hello',
      format: ClipFormat.legacy(VideoOrientation.portrait),
      albumLabel: 'Kids',
    );

    expect(_video(fromRecording: true).origin, ClipOrigin.osdRecording);
    expect(_video(fromRecording: false).origin, ClipOrigin.gallery);
    expect(photo.origin, ClipOrigin.galleryPhoto);
  });
}
