import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/count_tick_text.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The picker's bottom bar: the count ticking as clips are picked, and
/// Continue, off below a movie's minimum.
class PickClipsBar extends StatelessWidget {
  const PickClipsBar({super.key});

  /// The count shown now.
  static const Key countKey = Key('pickClipsBar.count');

  static const Key continueKey = Key('pickClipsBar.continue');

  @override
  Widget build(BuildContext context) {
    final int count = context.select<CreateMovieCubit, int>(
      (CreateMovieCubit flow) => flow.state.picks.count,
    );
    final OsdColors colors = context.colors;
    final double bottom = math.max(
      24,
      MediaQuery.viewPaddingOf(context).bottom + 8,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.ln)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, bottom),
        child: Row(
          spacing: 12,
          children: <Widget>[
            Expanded(
              child: CountTickText(
                textKey: countKey,
                text: count == 0
                    ? Strings.noneSelected
                    : Strings.selectedCount(
                        count,
                        format: MovieLabels.numberFormat(context),
                      ),
                style: context.typography.rowTitleStrong.copyWith(
                  color: count == 0 ? colors.mu : colors.tx,
                ),
              ),
            ),
            PrimaryButton(
              key: continueKey,
              label: CommonLabels.of(context).continueAction,
              size: OsdButtonSize.dense,
              hug: true,
              haptic: OsdHaptic.light,
              onPressed: count >= MovieRules.minClips
                  ? () => _continue(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _continue(BuildContext context) {
    context.read<CreateMovieCubit>().confirmPicks();
    unawaited(AppRoute.confirmMovie.push<void>(context));
  }
}
