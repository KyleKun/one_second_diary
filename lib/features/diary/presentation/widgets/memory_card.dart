import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/audio/clip_mute_flow.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_hero.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_flow.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/clip_privacy_flow.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_edit_flow.dart';
import 'package:one_second_diary/features/clips/presentation/tags/clip_tags_flow.dart';
import 'package:one_second_diary/features/diary/domain/clip_caption.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/diary_viewer_flow.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_actions_sheet.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/delete_clip_dialog.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip_row.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/progress/page_dots.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A recorded day in Memories: the clip's poster with the play circle once
/// the poster is up, then its label: "Today" or "Sunday 27", what the
/// clip says about itself, its subtitle in quotes, else its place, else
/// nothing, and its tags as small chips (hidden with the caption while the
/// clip is private).
///
/// A day with several clips pages sideways through their posters with
/// dots; the label follows the clip shown.
///
/// A tap on the card, its picture or its label, opens the viewer on the
/// clip shown (no player in the feed), the poster flying there
/// ([ClipHero]); the clip the viewer shows last comes back to [onReturned].
/// A long press offers the clip's actions for the clip shown
/// ([ClipActionsSheet], the viewer's More): Subtitles, Edit tags, Private,
/// Mute, Edit again and Process this import when they apply, Share and
/// Delete; screen readers get them as actions of the card.
class MemoryCard extends StatefulWidget {
  const MemoryCard({
    super.key,
    required this.day,
    this.onReturned,
    this.fitWidth = false,
  });

  static Key keyOf(LocalDay day) =>
      ValueKey<(String, LocalDay)>(('memoryCard', day));

  /// The poster box.
  static const Key mediaKey = Key('memoryCard.media');

  /// The subtitle or the place.
  static const Key secondLineKey = Key('memoryCard.secondLine');

  /// The clip's tags.
  static const Key chipsKey = Key('memoryCard.chips');

  /// The poster box of a landscape profile.
  static const double height = 196;

  /// The poster box of a portrait profile.
  static const double portraitHeight = 320;

  /// The card's width in the design (390 − 2 × 16).
  static const double _designWidth = 358;

  final LocalDay day;

  /// The viewer closed on this clip.
  final ValueChanged<ClipRef>? onReturned;

  /// The poster box takes the card's width at the design's ratio instead
  /// of the phone's fixed height: the cards of a tablet's two columns.
  final bool fitWidth;

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  final PageController _pages = PageController();
  int _page = 0;

  /// How many times the viewer came back to this card: each return gives
  /// the poster a new hero (see [_open]).
  int _returns = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Opens the viewer on [clip]; when it closes, the poster is built anew.
  ///
  /// The flight to the viewer leaves the poster's hero an empty box until
  /// a flight back lands on it. When none does (the viewer closed on
  /// another clip, by a back gesture, or while the Diary's tickers were
  /// still off), Flutter never fills it again and the card stayed blank,
  /// whatever tab showed. A new hero has no such box: it is in place before
  /// the flight back looks for its target, so the video still lands on it.
  Future<void> _open(ClipRef clip) async {
    await DiaryViewerFlow.open(
      context,
      clip: clip,
      onReturned: widget.onReturned,
    );
    if (mounted) setState(() => _returns++);
  }

  /// The long press: the sheet of actions for [clip].
  Future<void> _offerActions(ClipRef clip, {required bool several}) async {
    unawaited(OsdHaptic.medium.play());
    final ClipAction? action = await ClipActionsSheet.show(
      context,
      title: DiaryFormats.of(context).fullDate(widget.day),
      isPrivate: ClipPrivacyFlow.isPrivate(context, clip),
      isMuted: ClipMuteFlow.isMuted(context, clip),
      hasSource: EditAgainFlow.isOffered(context, clip),
      isForeign: ProcessImportFlow.isForeign(context, clip),
    );
    if (action == null || !mounted) return;
    await _act(action, clip, several: several, afterSheet: true);
  }

  /// The actions [clip] can take now, in the sheet's order: Edit again and
  /// Process this import only when they apply.
  List<ClipAction> _actionsOf(ClipRef clip) => <ClipAction>[
    for (final ClipAction action in ClipAction.values)
      if (switch (action) {
        ClipAction.editAgain => EditAgainFlow.isOffered(context, clip),
        ClipAction.processImport => ProcessImportFlow.isForeign(context, clip),
        _ => true,
      })
        action,
  ];

  /// Runs [action] on [clip], from the sheet ([afterSheet]) or a screen
  /// reader's action.
  Future<void> _act(
    ClipAction action,
    ClipRef clip, {
    required bool several,
    bool afterSheet = false,
  }) async {
    final DiaryCubit cubit = context.read<DiaryCubit>();
    if (action == ClipAction.share) {
      return cubit.shareClip(clip, origin: _cardRect());
    }
    // Sheets and dialogs don't stack: the next waits for the sheet to go.
    if (afterSheet) await Future<void>.delayed(OsdMotion.afterSheetClose);
    if (!mounted) return;
    switch (action) {
      case ClipAction.subtitles:
        await SubtitleEditFlow.edit(context, clip: clip);
      case ClipAction.privacy:
        await ClipPrivacyFlow.toggle(context, clip: clip);
      case ClipAction.mute:
        await ClipMuteFlow.mute(context, clip: clip);
      case ClipAction.tags:
        await ClipTagsFlow.edit(context, clip: clip);
      case ClipAction.editAgain:
        await EditAgainFlow.start(context, clip: clip);
      case ClipAction.processImport:
        await ProcessImportFlow.editOne(context, clip);
      case ClipAction.delete:
        await DeleteClipDialog.show(
          context,
          clip: clip,
          profile: cubit.state.profile,
          several: several,
          onDelete: () => cubit.deleteClip(clip),
        );
      case ClipAction.share:
        return;
    }
  }

  /// Where the card is on screen (the iPad share popover's anchor).
  Rect? _cardRect() {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final (
      List<ClipRef> clips,
      VideoOrientation orientation,
      bool today,
    ) = context.select(
      (DiaryCubit cubit) => (
        cubit.state.clipsOf(widget.day),
        cubit.state.profile.orientation,
        cubit.state.today == widget.day,
      ),
    );
    if (clips.isEmpty) return const SizedBox.shrink();
    final ClipRef clip = clips[_page.clamp(0, clips.length - 1)];
    final ClipCaption caption = context.select(
      (DiaryCubit cubit) => cubit.captionOf(clip),
    );
    final bool isPrivate = context.select(
      (DiaryCubit cubit) => cubit.state.index?.isPrivate(clip) ?? false,
    );
    final List<String> tags = context.select(
      (DiaryCubit cubit) => cubit.state.index?.tagsOf(clip) ?? const <String>[],
    );
    final TagColors tagColors = context.read<TagColors>();
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final DiaryFormats formats = DiaryFormats.of(context);
    final String title = today
        ? CommonLabels.of(context).today
        : Strings.diaryDayCaption(
            weekday: formats.weekday(widget.day),
            day: formats.dayOfMonth(widget.day),
          );
    // A private clip's picture is blurred here: its caption stays with it.
    final String? secondLine = switch (caption) {
      _ when isPrivate => null,
      ClipCaption(subtitle: final String subtitle) => Strings.quotedText(
        text: subtitle,
      ),
      ClipCaption(location: final String location) => location,
      _ => null,
    };
    // The whole card opens the viewer, its label as well as its picture;
    // the PageView keeps its sideways drags.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () => unawaited(_open(clip)),
      onLongPress: () =>
          unawaited(_offerActions(clip, several: clips.length > 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          _MediaBox(
            height: orientation == VideoOrientation.portrait
                ? MemoryCard.portraitHeight
                : MemoryCard.height,
            fitWidth: widget.fitWidth,
            // Its own node: the caption under it is not part of the button.
            child: Semantics(
              container: true,
              button: true,
              label: formats.fullDate(widget.day),
              onTapHint: Strings.playerOpenFullScreen,
              excludeSemantics: true,
              onTap: () => unawaited(_open(clip)),
              customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                for (final ClipAction action in _actionsOf(clip))
                  CustomSemanticsAction(
                    label: switch (action) {
                      ClipAction.subtitles => Strings.subtitles,
                      ClipAction.tags => Strings.editTags,
                      ClipAction.privacy =>
                        isPrivate ? Strings.makePublic : Strings.makePrivate,
                      ClipAction.mute =>
                        ClipMuteFlow.isMuted(context, clip)
                            ? Strings.clipMuted
                            : Strings.clipMute,
                      ClipAction.editAgain => Strings.editAgain,
                      ClipAction.processImport => Strings.clipProcessImport,
                      ClipAction.share => Strings.share,
                      ClipAction.delete => CommonLabels.of(context).delete,
                    },
                  ): () =>
                      unawaited(_act(action, clip, several: clips.length > 1)),
              },
              child: ClipRRect(
                key: MemoryCard.mediaKey,
                borderRadius: BorderRadius.circular(OsdRadius.r20),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (clips.length == 1)
                      _Poster(
                        key: ValueKey<int>(_returns),
                        clip: clip,
                        orientation: orientation,
                      )
                    else
                      PageView.builder(
                        controller: _pages,
                        itemCount: clips.length,
                        onPageChanged: (int page) =>
                            setState(() => _page = page),
                        itemBuilder: (BuildContext context, int page) =>
                            page == _page
                            ? _Poster(
                                key: ValueKey<int>(_returns),
                                clip: clips[page],
                                orientation: orientation,
                              )
                            : ClipThumbnailView(
                                clip: clips[page],
                                slot: ClipThumbnailSlot.player,
                                orientation: orientation,
                                overlay: _Poster.playCircle,
                              ),
                      ),
                    if (clips.length > 1)
                      PositionedDirectional(
                        end: 12,
                        bottom: 14,
                        child: IgnorePointer(
                          child: ListenableBuilder(
                            listenable: _pages,
                            builder: (BuildContext context, _) => PageDots(
                              count: clips.length,
                              position: _pages.hasClients
                                  ? _pages.page ?? _page.toDouble()
                                  : _page.toDouble(),
                              style: PageDotsStyle.onMedia,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: <Widget>[
                // The poster says the full date already.
                ExcludeSemantics(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleSmall.copyWith(color: colors.tx),
                  ),
                ),
                if (secondLine != null)
                  Text(
                    secondLine,
                    key: MemoryCard.secondLineKey,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body14.copyWith(color: colors.d2),
                  ),
                if (tags.isNotEmpty && !isPrivate)
                  Padding(
                    key: MemoryCard.chipsKey,
                    padding: const EdgeInsets.only(top: 4),
                    child: TagChipRow(
                      tags: tags,
                      colorOf: tagColors.colorOf,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The poster's box: [height] tall, or the card's width at the design's
/// ratio when [fitWidth].
class _MediaBox extends StatelessWidget {
  const _MediaBox({
    required this.height,
    required this.fitWidth,
    required this.child,
  });

  final double height;
  final bool fitWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => fitWidth
      ? AspectRatio(aspectRatio: MemoryCard._designWidth / height, child: child)
      : SizedBox(height: height, child: child);
}

/// The clip shown: its poster, which flies to the viewer.
class _Poster extends StatelessWidget {
  const _Poster({super.key, required this.clip, required this.orientation});

  /// Over a poster once it is up: never while it loads, nor over one that
  /// can't be made.
  static const Widget playCircle = Center(
    child: PlayOverlayButton(size: PlayOverlaySize.medium),
  );

  final ClipRef clip;
  final VideoOrientation orientation;

  @override
  Widget build(BuildContext context) => ClipHero(
    clip: clip,
    radius: OsdRadius.r20,
    slot: ClipThumbnailSlot.player,
    orientation: orientation,
    child: ClipThumbnailView(
      clip: clip,
      slot: ClipThumbnailSlot.player,
      orientation: orientation,
      overlay: playCircle,
    ),
  );
}
