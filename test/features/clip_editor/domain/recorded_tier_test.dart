// RecordedTier: what the camera achieved against the profile's tier, for
// the editor's "Recorded at 1080p" note.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/features/clip_editor/domain/recorded_tier.dart';

void main() {
  test('a recording\'s tier is the largest its short side reaches, either '
      'way round; under 720p it is still 720p', () {
    expect(RecordedTier.of((width: 1920, height: 1080)), ResolutionTier.p1080);
    expect(RecordedTier.of((width: 1080, height: 1920)), ResolutionTier.p1080);
    expect(RecordedTier.of((width: 3840, height: 2160)), ResolutionTier.p2160);
    expect(RecordedTier.of((width: 2560, height: 1440)), ResolutionTier.p1440);
    expect(RecordedTier.of((width: 1280, height: 720)), ResolutionTier.p720);
    expect(RecordedTier.of((width: 1920, height: 1088)), ResolutionTier.p1080);
    expect(RecordedTier.of((width: 640, height: 480)), ResolutionTier.p720);
  });

  test('the note shows only when the recording is below the profile\'s '
      'tier', () {
    final ClipFormat ultra = ClipFormatPreset.ultra.format(
      VideoOrientation.portrait,
    );
    const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);

    expect(RecordedTier.isBelow((width: 1920, height: 1080), ultra), isTrue);
    expect(RecordedTier.isBelow((width: 3840, height: 2160), ultra), isFalse);
    expect(RecordedTier.isBelow((width: 1920, height: 1080), legacy), isFalse);
    // The dual camera's composite on a 1080p profile.
    expect(RecordedTier.isBelow((width: 1280, height: 720), legacy), isTrue);
  });

  test('the note is read off the probed file of a recording: nothing for '
      'an import, nothing until the size is probed, nothing for a take '
      'that reaches the tier', () {
    final ClipFormat ultra = ClipFormatPreset.ultra.format(
      VideoOrientation.landscape,
    );
    const AchievedSize fullHd = (width: 1920, height: 1080);

    expect(
      RecordedTier.noted(recording: true, source: fullHd, format: ultra),
      ResolutionTier.p1080,
    );
    expect(
      RecordedTier.noted(recording: false, source: fullHd, format: ultra),
      isNull,
    );
    expect(
      RecordedTier.noted(recording: true, source: null, format: ultra),
      isNull,
    );
    expect(
      RecordedTier.noted(
        recording: true,
        source: (width: 3840, height: 2160),
        format: ultra,
      ),
      isNull,
    );
  });
}
