import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/imports/imported_badge.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_badge.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_flow.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/rise_switcher.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip_row.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// The caption of the viewer's bottom row, beside Share and More: the
/// clip's subtitle in quotes, from the start, four lines at most (two on a
/// short screen: a phone turned sideways); nothing without one (the
/// Subtitles row of More adds it). It is shadowed, so it reads over the
/// video of a phone turned sideways too. Under it, the clip's tags as
/// compact chips on one line, and the "Imported" and "Edit again" badges
/// (buttons, as the sheet's rows are). A step to another clip crossfades
/// them rising. A covered private clip (stepped to, not tapped yet) keeps
/// its subtitle and its tags with its picture.
class ViewerCaption extends StatelessWidget {
  const ViewerCaption({super.key, this.compact = false});

  /// Whether it is the caption of a phone turned sideways: smaller, two
  /// lines, with little room around it, beside the compact buttons.
  final bool compact;

  static const Key textKey = Key('viewerCaption.text');

  static const Key chipsKey = Key('viewerCaption.chips');

  /// The "Imported" badge of a clip the app did not make.
  static const Key importedKey = Key('viewerCaption.imported');

  /// The "Edit again" badge of a clip whose original recording is kept.
  static const Key editAgainKey = Key('viewerCaption.editAgain');

  static const double _rise = 6;

  /// Keeps the text readable where it lies over the video.
  static const List<Shadow> _shadow = <Shadow>[
    Shadow(color: Color(0xCC000000), blurRadius: 6),
  ];

  /// Below this height the caption keeps to two lines.
  static const double _shortScreen = 500;

  @override
  Widget build(BuildContext context) {
    final (
      ClipRef clip,
      String? subtitle,
      List<String> tags,
      bool imported,
      bool hasSource,
    ) = context.select((ViewerCubit cubit) {
      final bool covered = cubit.state.isCovered(cubit.state.clip);
      return (
        cubit.state.clip,
        covered ? null : cubit.state.caption.subtitle,
        covered
            ? const <String>[]
            : cubit.state.index?.tagsOf(cubit.state.clip) ?? const <String>[],
        cubit.state.index?.isForeign(cubit.state.clip) ?? false,
        cubit.state.index?.hasSource(cubit.state.clip) ?? false,
      );
    });
    final TagColors colors = context.read<TagColors>();
    final bool empty =
        subtitle == null && tags.isEmpty && !imported && !hasSource;
    return RiseSwitcher(
      rise: _rise,
      child: empty
          ? SizedBox(key: ValueKey<ClipRef>(clip), width: double.infinity)
          : Padding(
              // Tags by value: a rescan hands out new lists.
              key: ValueKey<(ClipRef, String?, String, bool, bool)>((
                clip,
                subtitle,
                tags.join(','),
                imported,
                hasSource,
              )),
              // The row pads the sides.
              padding: compact
                  ? const EdgeInsets.symmetric(vertical: 4)
                  : EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: compact ? OsdSpace.s4 : OsdSpace.s8,
                children: <Widget>[
                  if (subtitle != null)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        Strings.quotedText(text: subtitle),
                        key: textKey,
                        textAlign: TextAlign.start,
                        maxLines:
                            compact ||
                                MediaQuery.sizeOf(context).height < _shortScreen
                            ? 2
                            : 4,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (compact
                                    ? context.typography.body14
                                    : context.typography.body17Loose)
                                .copyWith(
                                  color: OsdViewer.caption,
                                  shadows: _shadow,
                                ),
                      ),
                    ),
                  if (tags.isNotEmpty)
                    TagChipRow(
                      key: chipsKey,
                      tags: tags,
                      colorOf: colors.colorOf,
                      maxLines: 1,
                    ),
                  // The badges say what the clip is, and are a way to process
                  // it by hand or edit it again from its kept original, as
                  // More's rows are.
                  if (imported || hasSource)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: OsdSpace.s8,
                      children: <Widget>[
                        if (imported)
                          ImportedBadge(
                            key: importedKey,
                            onTap: () => unawaited(
                              ProcessImportFlow.editOne(context, clip),
                            ),
                          ),
                        if (hasSource)
                          EditAgainBadge(
                            key: editAgainKey,
                            onTap: () => unawaited(
                              EditAgainFlow.start(context, clip: clip),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
