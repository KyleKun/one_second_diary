import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

import '../../../shared/fakes/fake_clip_repository.dart';

/// A [ClipStore] whose [delete] takes the clip out of [clips]' index, as
/// the real store does, or refuses while [refuse] is set; [hold] keeps a
/// delete running until [release]. [deleted] and [dismissed] say what it
/// did.
class FakeClipStore extends Fake implements ClipStore {
  FakeClipStore(this.clips);

  final FakeClipRepository clips;

  /// The platform refuses to delete.
  bool refuse = false;

  /// Deletes wait for [release].
  bool hold = false;
  Completer<void> _gate = Completer<void>();

  final List<ClipRef> deleted = <ClipRef>[];
  final List<ClipWrite> dismissed = <ClipWrite>[];

  /// Lets held deletes finish.
  void release() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  Future<ClipWrite> delete(ClipRef clip) async {
    if (hold) await _gate.future;
    if (refuse) {
      throw MediaStoreException('Could not delete the clip ${clip.relPath}');
    }
    deleted.add(clip);
    final ClipIndex? index = clips.snapshotOf(clip.profile);
    if (index != null) clips.publish(index.withoutClip(clip.relPath));
    final ClipWrite write = ClipWrite(
      clip: clip,
      undo: DeletedUndo(relPath: clip.relPath, trashId: 'trash-1'),
    );
    _deletions[clip] = write;
    return write;
  }

  final Map<ClipRef, ClipWrite> _deletions = <ClipRef, ClipWrite>{};

  @override
  ClipWrite? deletionOf(ClipRef clip) => _deletions[clip];

  @override
  Future<void> dismiss(ClipWrite write) async {
    _deletions.remove(write.clip);
    dismissed.add(write);
  }
}
