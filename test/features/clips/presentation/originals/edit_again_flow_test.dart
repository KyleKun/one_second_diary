// "Edit again" opens a clip's kept original under
// the ownership its cached origin says, so a processed import is re-saved
// as an import and a recording as a recording.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/original_render_facts.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_flow.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

void main() {
  final ClipRef clip = ClipRef(
    profile: ProfileKey.defaultProfile,
    relPath: '2024-01-05.mp4',
  );
  const String kept = '/originals/2024-01-05.mp4';

  test('an import-origin clip opens its original as the user\'s own file, '
      'not owned, and is re-saved as an import', () {
    final EditClipArgs args = EditAgainFlow.argsFor(clip, (
      sourcePath: kept,
      recipe: null,
      origin: ClipOrigin.import,
    ));

    expect(
      args.source,
      const VideoSource(
        path: kept,
        ownership: ClipOwnership.userOriginal,
        owned: false,
      ),
    );
    expect(args.imported, isTrue);
    expect(args.mode, ReplaceClip(clip));
    expect(args.day, clip.day);
    expect(args.profile, clip.profile);
  });

  test('a recording opens as a camera temp, not owned, not imported; so '
      'does a clip whose origin is not cached', () {
    for (final ClipOrigin? origin in <ClipOrigin?>[
      ClipOrigin.osdRecording,
      null,
    ]) {
      final EditClipArgs args = EditAgainFlow.argsFor(clip, (
        sourcePath: kept,
        recipe: null,
        origin: origin,
      ));
      expect(
        args.source.ownership,
        ClipOwnership.cameraTemp,
        reason: '$origin',
      );
      expect(args.source.owned, isFalse);
      expect(args.imported, isFalse);
    }
  });

  test('a gallery pick opens as the user\'s own file and renders as a '
      'gallery clip (neither a recording nor an import)', () {
    expect(
      OriginalRenderFacts.ownership(ClipOrigin.gallery),
      ClipOwnership.userOriginal,
    );
    expect(OriginalRenderFacts.fromRecording(ClipOrigin.gallery), isFalse);
    expect(OriginalRenderFacts.imported(ClipOrigin.gallery), isFalse);
    expect(
      OriginalRenderFacts.fromRecording(ClipOrigin.osdRecordingOld),
      isTrue,
    );
  });
}
