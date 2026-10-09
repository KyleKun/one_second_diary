import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_flow.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/clips/presentation/audio/clip_mute_flow.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_flow.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/clip_privacy_flow.dart';
import 'package:one_second_diary/features/clips/presentation/saved/saved_clip_snackbar.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_edit_flow.dart';
import 'package:one_second_diary/features/clips/presentation/tags/clip_tags_flow.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_actions_sheet.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/day_caption_row.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/delete_clip_dialog.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/rise_switcher.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// What sits under the selected day's block:
/// - a recorded day: its [DayCaptionRow], whose Edit button opens the
///   clip's actions ([ClipActionsSheet], as a Memories card's long press):
///   Subtitles, Edit tags, Private, Mute, Edit again and Process this import
///   when they apply, Share and Delete (asked with [DeleteClipDialog]);
/// - a missed day, or one before the profile's first clip: Add video and
///   Add photo, which add a clip to that day through the shared
///   `AddClipFlow` (the picker, then the clip editor) and say "Video saved"
///   after;
/// - anything else (today not recorded, a month without clips, a diary
///   still being read): nothing.
///
/// The row crossfades rising, its height following. It stays in the page
/// while the day changes, so the flows it starts can show their snackbars
/// when the day they changed turns into another row.
class DiaryDayActions extends StatelessWidget {
  const DiaryDayActions({super.key});

  static const Key addVideoKey = Key('diaryDayActions.addVideo');

  static const Key addPhotoKey = Key('diaryDayActions.addPhoto');

  static const double _gap = 12;
  static const double _rise = 8;

  Future<void> _add(
    BuildContext context,
    LocalDay day,
    AddClipSource source,
  ) async {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    if (cubit.state.adding) return;
    cubit.addStarted();
    SavedClip? saved;
    try {
      saved = await AddClipFlow.start(
        context,
        source: source,
        day: day,
        profile: cubit.state.profile.key,
      );
    } finally {
      cubit.addFinished(saved: saved?.ref);
    }
    if (saved != null && context.mounted) {
      SavedClipSnackbar.show(context, saved: saved, today: cubit.state.today);
    }
  }

  /// The sheet, then the action it closed with on [clip], once the sheet
  /// has gone (sheets and dialogs don't stack). [origin] anchors Share.
  Future<void> _more(BuildContext context, ClipRef clip, Rect? origin) async {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final ClipAction? action = await ClipActionsSheet.show(
      context,
      title: DiaryFormats.of(context).fullDate(clip.day),
      isPrivate: ClipPrivacyFlow.isPrivate(context, clip),
      isMuted: ClipMuteFlow.isMuted(context, clip),
      hasSource: EditAgainFlow.isOffered(context, clip),
      isForeign: ProcessImportFlow.isForeign(context, clip),
    );
    if (action == null || !context.mounted) return;
    if (action == ClipAction.share) {
      return cubit.shareClip(clip, origin: origin);
    }
    await Future<void>.delayed(OsdMotion.afterSheetClose);
    if (!context.mounted) return;
    switch (action) {
      case ClipAction.subtitles:
        await SubtitleEditFlow.edit(context, clip: clip);
      case ClipAction.tags:
        await ClipTagsFlow.edit(context, clip: clip);
      case ClipAction.privacy:
        await ClipPrivacyFlow.toggle(context, clip: clip);
      case ClipAction.mute:
        await ClipMuteFlow.mute(context, clip: clip);
      case ClipAction.editAgain:
        await _editAgain(context, clip);
      case ClipAction.processImport:
        await _process(context, clip);
      case ClipAction.delete:
        await _delete(context, clip);
      case ClipAction.share:
        return;
    }
  }

  /// Processes [clip] by hand in the editor; "Video saved" after.
  Future<void> _process(BuildContext context, ClipRef clip) async {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final SavedClip? saved = await ProcessImportFlow.editOne(context, clip);
    if (saved != null && context.mounted) {
      SavedClipSnackbar.show(context, saved: saved, today: cubit.state.today);
    }
  }

  /// Opens the editor on [clip]'s kept original; "Video saved" after.
  Future<void> _editAgain(BuildContext context, ClipRef clip) async {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final SavedClip? saved = await EditAgainFlow.start(context, clip: clip);
    if (saved != null && context.mounted) {
      SavedClipSnackbar.show(context, saved: saved, today: cubit.state.today);
    }
  }

  Future<void> _delete(BuildContext context, ClipRef clip) {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    return DeleteClipDialog.show(
      context,
      clip: clip,
      profile: cubit.state.profile,
      several: cubit.state.clipsOf(clip.day).length > 1,
      onDelete: () => cubit.deleteClip(clip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (DiaryDay? day, ClipRef? shown, bool adding) = context.select(
      (DiaryCubit cubit) => (
        switch (cubit.state.selected) {
          final LocalDay selected => cubit.state.dayOf(selected),
          null => null,
        },
        cubit.state.shownClip,
        cubit.state.adding,
      ),
    );
    final Widget row = switch ((day, shown)) {
      (DiaryDay(kind: DiaryDayKind.recorded), final ClipRef clip) => Padding(
        // The same row for every recorded day: its text changes in place.
        key: const ValueKey<String>('caption'),
        padding: const EdgeInsets.only(top: _gap),
        child: DayCaptionRow(
          clip: clip,
          onMore: (Rect? origin) => unawaited(_more(context, clip, origin)),
        ),
      ),
      (
        DiaryDay(
          kind: DiaryDayKind.missed || DiaryDayKind.beforeFirstClip,
          isToday: false,
          :final LocalDay day,
        ),
        _,
      ) =>
        Padding(
          key: ValueKey<(String, LocalDay)>(('add', day)),
          padding: const EdgeInsets.only(top: _gap),
          child: _AddButtons(
            adding: adding,
            onAdd: (AddClipSource source) =>
                unawaited(_add(context, day, source)),
          ),
        ),
      _ => const SizedBox(key: ValueKey<String>('none'), width: .infinity),
    };
    return AnimatedSize(
      duration: OsdMotion.d(context, OsdMotion.standard),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      alignment: AlignmentDirectional.topStart,
      child: RiseSwitcher(rise: _rise, child: row),
    );
  }
}

/// Add video (primary) and Add photo (neutral). While a clip is being
/// added both wait, and Add video spins.
class _AddButtons extends StatelessWidget {
  const _AddButtons({required this.adding, required this.onAdd});

  final bool adding;
  final ValueChanged<AddClipSource> onAdd;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: KeyedSubtree(
          key: DiaryDayActions.addVideoKey,
          child: PrimaryButton(
            label: Strings.addVideo,
            icon: OsdIcons.videoLibrary,
            size: OsdButtonSize.compact,
            loading: adding,
            haptic: OsdHaptic.light,
            onPressed: adding ? null : () => onAdd(AddClipSource.video),
          ),
        ),
      ),
      Expanded(
        child: KeyedSubtree(
          key: DiaryDayActions.addPhotoKey,
          child: NeutralButton(
            label: Strings.addPhotoAsVideo,
            icon: OsdIcons.image,
            size: OsdButtonSize.compact,
            onPressed: adding ? null : () => onAdd(AddClipSource.photo),
          ),
        ),
      ),
    ],
  );
}
