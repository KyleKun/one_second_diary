import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_radio_row.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The confirmation's "Transition" row: the choice for this movie (None by
/// default), which opens a sheet of the styles, and, with a style and older
/// clips in the movie, the "Also apply to older clips" switch.
class TransitionRow extends StatelessWidget {
  const TransitionRow({super.key});

  /// The choice row.
  static const Key rowKey = Key('transitionRow.row');

  /// The older-clips switch row.
  static const Key upgradeKey = Key('transitionRow.upgrade');

  /// The sheet's row of [transition] (null: None).
  static Key choiceKey(MovieTransition? transition) =>
      ValueKey<String>('transitionRow.choice.${transition?.name ?? 'none'}');

  /// The label of [transition] (null: None).
  static String labelOf(MovieTransition? transition) => switch (transition) {
    null => Strings.movieTransitionNone,
    MovieTransition.crossfade => Strings.movieTransitionCrossfade,
    MovieTransition.fadeBlack => Strings.movieTransitionFadeBlack,
    MovieTransition.fadeWhite => Strings.movieTransitionFadeWhite,
  };

  Future<void> _choose(BuildContext context) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final _Choice? choice = await showOsdSheet<_Choice>(
      context,
      title: Strings.movieTransitionSheetTitle,
      child: _TransitionSheet(current: flow.state.transition),
    );
    // A dismissed sheet leaves the choice.
    if (choice == null || flow.isClosed) return;
    flow.setTransition(choice.transition);
  }

  @override
  Widget build(BuildContext context) {
    final ({MovieTransition? transition, bool upgrade, int older}) flow =
        context.select<
          CreateMovieCubit,
          ({MovieTransition? transition, bool upgrade, int older})
        >(
          (CreateMovieCubit flow) => (
            transition: flow.state.transition,
            upgrade: flow.state.upgradeOlderClips,
            older: flow.state.olderClips,
          ),
        );
    final bool showUpgrade = flow.transition != null && flow.older > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: OsdCard(
        child: Column(
          children: <Widget>[
            OsdListRow(
              key: rowKey,
              icon: OsdIcons.tune,
              title: Strings.movieTransition,
              subtitle: labelOf(flow.transition),
              trailing: const OsdRowTrailing.chevron(),
              haptic: OsdHaptic.selection,
              onTap: () => _choose(context),
            ),
            AnimatedSize(
              duration: OsdMotion.d(context, OsdMotion.standard),
              curve: OsdMotion.curve(context, OsdMotion.standardCurve),
              alignment: Alignment.topCenter,
              child: showUpgrade
                  ? Column(
                      children: <Widget>[
                        const OsdDivider(),
                        OsdListRow(
                          key: upgradeKey,
                          title: Strings.movieTransitionUpgradeOlder,
                          subtitle: flow.upgrade
                              ? Strings.movieTransitionOlderClipsOn(
                                  flow.older,
                                  format: MovieLabels.numberFormat(context),
                                )
                              : Strings.movieTransitionOlderClipsOff(
                                  flow.older,
                                  format: MovieLabels.numberFormat(context),
                                ),
                          trailing: OsdRowTrailing.custom(
                            OsdSwitch(value: flow.upgrade, interactive: false),
                          ),
                          toggled: flow.upgrade,
                          haptic: OsdHaptic.selection,
                          onTap: () => context
                              .read<CreateMovieCubit>()
                              .setUpgradeOlderClips(upgrade: !flow.upgrade),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet's answer: a choice made (None included), as opposed to a
/// dismissal (null).
final class _Choice {
  const _Choice(this.transition);

  final MovieTransition? transition;
}

/// The styles, None first; the current one selected. Tapping one pops the
/// sheet with it.
class _TransitionSheet extends StatelessWidget {
  const _TransitionSheet({required this.current});

  final MovieTransition? current;

  @override
  Widget build(BuildContext context) {
    final List<MovieTransition?> choices = <MovieTransition?>[
      null,
      ...MovieTransition.values,
    ];
    return OsdCard(
      child: Column(
        children: <Widget>[
          for (final (int index, MovieTransition? choice)
              in choices.indexed) ...<Widget>[
            if (index > 0) const OsdDivider(),
            OsdRadioRow(
              key: TransitionRow.choiceKey(choice),
              label: TransitionRow.labelOf(choice),
              selected: choice == current,
              onSelected: () =>
                  Navigator.of(context).pop<_Choice>(_Choice(choice)),
            ),
          ],
        ],
      ),
    );
  }
}
