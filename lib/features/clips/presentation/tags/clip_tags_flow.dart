import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';

/// Edits the tags of a saved clip: opens the [TagsSheet] on them and, on Save,
/// writes them with `ClipTags.setTags`. The result is reported in the page's
/// `OsdSnackbarHost`, with Try again on failure.
abstract final class ClipTagsFlow {
  /// The tags of [clip] now, as the library knows them.
  static List<String> tagsOf(BuildContext context, ClipRef clip) =>
      context.read<ClipTags>().tagsOf(clip);

  /// Runs the flow for [clip]; true when its tags were rewritten.
  static Future<bool> edit(
    BuildContext context, {
    required ClipRef clip,
  }) async {
    final ClipTags tags = context.read<ClipTags>();
    final OsdSnackbarHostState host = OsdSnackbarHost.of(context);
    try {
      final List<String>? saved = await TagsSheet.show(
        context,
        tags: tags.tagsOf(clip),
        suggestions: <String>[
          for (final TagCount tag in tags.vocabulary(profile: clip.profile))
            tag.name,
        ],
        onSave: (List<String> next) => tags.setTags(clip, next),
      );
      if (saved == null) return false;
      _saved(host);
      return true;
    } on TagsSaveFailed catch (failure) {
      // Logged by ClipTags.
      _failed(
        host,
        retry: () async {
          await tags.setTags(clip, failure.tags);
          _saved(host);
        },
      );
      return false;
    }
  }

  static void _saved(OsdSnackbarHostState host) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(kind: OsdSnackKind.info, title: Strings.tagsSaved),
    );
  }

  static void _failed(
    OsdSnackbarHostState host, {
    required Future<void> Function() retry,
  }) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.error,
        title: Strings.tagsSaveError,
        actionLabel: Strings.commonTryAgain,
        onAction: retry,
        actionErrorTitle: Strings.tagsSaveError,
      ),
    );
  }
}
