import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// A [ClipAudio] that keeps the muted clips in memory: [isMuted] reads
/// [muted], [mute] records the clip in [mutes] and adds it to [muted], or
/// throws [failure] when the test scripted one, leaving the clip as it was.
class FakeClipAudio extends Fake implements ClipAudio {
  /// The relPaths of the clips muted.
  final Set<String> muted = <String>{};

  /// What [mute] was asked, in order.
  final List<ClipRef> mutes = <ClipRef>[];

  /// When set, the next [mute] throws it instead of muting.
  Object? failure;

  @override
  bool isMuted(ClipRef clip) => muted.contains(clip.relPath);

  @override
  Future<void> mute(ClipRef clip) async {
    mutes.add(clip);
    final Object? error = failure;
    if (error != null) {
      failure = null;
      throw error;
    }
    muted.add(clip.relPath);
  }
}
