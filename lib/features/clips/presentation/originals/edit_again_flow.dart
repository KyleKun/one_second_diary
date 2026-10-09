import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/original_render_facts.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';

/// "Edit again": opens the clip editor on the clip's kept original recording,
/// pre-filled with the recipe its sidecar entry holds, in replace mode, so the
/// save takes the clip's place and leaves the source where it is. Offered only
/// when `ClipIndex.hasSource` (a names scan, no disk access).
abstract final class EditAgainFlow {
  /// Whether [clip] has a kept original, as the library knows it now.
  static bool isOffered(BuildContext context, ClipRef clip) =>
      context
          .read<ClipRepository>()
          .snapshotOf(clip.profile)
          ?.hasSource(clip) ??
      false;

  /// Opens the editor on [clip]'s original (never deleted by the editor), with
  /// the recipe when the sidecar has one. Returns what the editor popped
  /// with; null at once when the clip has no source.
  static Future<SavedClip?> start(
    BuildContext context, {
    required ClipRef clip,
  }) async {
    final EditAgainSource? again = context.read<ClipStore>().editAgainOf(clip);
    if (again == null) return null;
    return argsFor(clip, again).push<SavedClip>(context);
  }

  /// The editor's arguments for [clip] opened on [again]: its original in
  /// replace mode, pre-filled with the recipe, under the ownership its cached
  /// origin says (`OriginalRenderFacts`), so an import keeps its origin tag.
  static EditClipArgs argsFor(ClipRef clip, EditAgainSource again) =>
      EditClipArgs(
        source: VideoSource(
          path: again.sourcePath,
          ownership: OriginalRenderFacts.ownership(again.origin),
          owned: false,
        ),
        day: clip.day,
        profile: clip.profile,
        mode: ReplaceClip(clip),
        prefill: again.recipe,
        imported: OriginalRenderFacts.imported(again.origin),
      );
}
