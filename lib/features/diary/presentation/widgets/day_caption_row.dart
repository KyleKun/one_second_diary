import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/domain/clip_caption.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/rise_switcher.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip_row.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_text_swap.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The row under the calendar's player: the day ("Wednesday 16") over what
/// the [clip] shown says about itself (its subtitle in quotes, else its
/// place, else nothing, the title then centred), one line each, and its
/// tags as small chips under that; then the Edit button, which opens the
/// clip's actions.
///
/// The caption comes from the metadata cache in memory, and follows the
/// clip's version: after a subtitle edit the edited text shows. The tags
/// follow the library, so an edit shows at once. A private clip still
/// covered in the player keeps its caption and its chips with its picture.
/// Another day changes its name letter by letter (`OsdTextSwap`), and a new
/// second line takes the old one's place rising; the button stays still.
class DayCaptionRow extends StatelessWidget {
  const DayCaptionRow({super.key, required this.clip, required this.onMore});

  /// The subtitle or the place.
  static const Key secondLineKey = Key('dayCaptionRow.secondLine');

  /// The clip's tags under the caption.
  static const Key chipsKey = Key('dayCaptionRow.chips');

  static const Key moreKey = Key('dayCaptionRow.more');

  static const double _rise = 4;

  /// The clip the player shows.
  final ClipRef clip;

  /// Called with where the Edit button is on screen (the iPad share
  /// popover's anchor).
  final ValueChanged<Rect?> onMore;

  @override
  Widget build(BuildContext context) {
    final ClipCaption caption = context.select(
      (DiaryCubit cubit) => cubit.captionOf(clip),
    );
    final bool covered = context.select(
      (DiaryCubit cubit) => cubit.state.isCovered(clip),
    );
    // The index shares a clip's list across snapshots that leave its tags
    // alone, so this rebuilds the row only when they change.
    final List<String> tags = context.select(
      (DiaryCubit cubit) => cubit.state.index?.tagsOf(clip) ?? const <String>[],
    );
    final TagColors tagColors = context.read<TagColors>();
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final DiaryFormats formats = DiaryFormats.of(context);
    final String? secondLine = switch (caption) {
      _ when covered => null,
      ClipCaption(subtitle: final String subtitle) => Strings.quotedText(
        text: subtitle,
      ),
      ClipCaption(location: final String location) => location,
      _ => null,
    };
    return Row(
      spacing: 10,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OsdTextSwap(
                Strings.diaryDayCaption(
                  weekday: formats.weekday(clip.day),
                  day: formats.dayOfMonth(clip.day),
                ),
                overflow: TextOverflow.ellipsis,
                style: typography.button.copyWith(color: colors.tx),
              ),
              AnimatedSize(
                duration: OsdMotion.d(context, OsdMotion.standard),
                curve: OsdMotion.curve(context, OsdMotion.standardCurve),
                alignment: AlignmentDirectional.topStart,
                child: RiseSwitcher(
                  rise: _rise,
                  child: secondLine == null
                      ? const SizedBox(
                          key: ValueKey<String>('none'),
                          width: double.infinity,
                        )
                      : SizedBox(
                          key: ValueKey<(ClipRef, String)>((clip, secondLine)),
                          width: double.infinity,
                          child: Text(
                            secondLine,
                            key: secondLineKey,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.caption13.copyWith(
                              color: colors.mu,
                            ),
                          ),
                        ),
                ),
              ),
              AnimatedSize(
                duration: OsdMotion.d(context, OsdMotion.standard),
                curve: OsdMotion.curve(context, OsdMotion.standardCurve),
                alignment: AlignmentDirectional.topStart,
                child: tags.isEmpty || covered
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        key: chipsKey,
                        padding: const EdgeInsets.only(top: 4),
                        child: TagChipRow(
                          tags: tags,
                          colorOf: tagColors.colorOf,
                          maxLines: 1,
                        ),
                      ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (BuildContext button) => NeutralButton(
            key: moreKey,
            icon: OsdIcons.edit,
            label: Strings.edit,
            size: OsdButtonSize.compact,
            hug: true,
            onPressed: () => onMore(_rectOf(button)),
          ),
        ),
      ],
    );
  }

  static Rect? _rectOf(BuildContext context) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
