import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/privacy_commands.dart';
import 'package:one_second_diary/core/media/types/clip_privacy_tag.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';

void main() {
  test('marking a clip private or public is a stream copy of its video, '
      'audio and subtitles with the description tag set or deleted, the '
      'other tags copied by default, the path its own element', () {
    const String clip = '/Application Support/OneSecondDiary/2024-01-05.mp4';
    const String output = '/scratch/out 1/2024-01-05.mp4';
    const List<String> common = <String>[
      '-i',
      clip,
      '-c',
      'copy',
      '-map',
      '0:v',
      '-map',
      '0:a?',
      '-map',
      '0:s?',
      '-metadata',
    ];

    expect(PrivacyCommands.tag(clip: clip, output: output, private: true), [
      ...common,
      'description=private=1',
      output,
      '-y',
    ]);
    expect(PrivacyCommands.tag(clip: clip, output: output, private: false), [
      ...common,
      'description=',
      output,
      '-y',
    ]);
  });

  test('the tag is one part of the description; a clip without it, or with '
      'another description, is public', () {
    expect(ClipPrivacyTag.isPrivate('private=1'), isTrue);
    expect(ClipPrivacyTag.isPrivate('origin=x;private=1'), isTrue);
    for (final String? description in <String?>[
      null,
      '',
      'private=0',
      'private',
      'Shot on my phone',
      'clips=4;from=2026-09-01;to=2026-09-05',
    ]) {
      expect(
        ClipPrivacyTag.isPrivate(description),
        isFalse,
        reason: '$description',
      );
    }

    const ClipProbe probe = ClipProbe(
      durationMs: 1000,
      hasAudio: true,
      hasSubtitleStream: false,
      artist: 'One Second Diary (v1.5)',
      album: 'Default',
      comment: 'origin=osd_recording',
      locationTag: null,
      title: null,
      description: 'private=1',
      width: 1920,
      height: 1080,
      codec: 'h264',
      fps: 30,
    );
    expect(probe.isPrivate, isTrue);
  });
}
