import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/count_tick_text.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Create movie's live count: the clips found, none, or the minimum needed
/// when there are too few. Empty while loading; a diary that could not be read
/// says so, with Try again.
class ClipsFoundCount extends StatelessWidget {
  const ClipsFoundCount({super.key});

  /// The count shown now.
  static const Key textKey = Key('clipsFoundCount.text');

  @override
  Widget build(BuildContext context) {
    final ({CreateMovieStatus status, int clips}) count = context
        .select<CreateMovieCubit, ({CreateMovieStatus status, int clips})>(
          (CreateMovieCubit flow) =>
              (status: flow.state.status, clips: flow.state.presetClips),
        );
    final OsdColors colors = context.colors;
    if (count.status == CreateMovieStatus.failed) return const _Unreadable();
    final int clips = count.clips;
    final String text = switch (count.status) {
      CreateMovieStatus.loading => '',
      _ when clips == 0 => Strings.movieNoClipsFound,
      _ when clips < MovieRules.minClips => Strings.movieNeedMoreClips(
        MovieRules.minClips,
        format: MovieLabels.numberFormat(context),
      ),
      _ => Strings.movieClipsFound(
        clips,
        format: MovieLabels.numberFormat(context),
      ),
    };
    final bool enough = clips >= MovieRules.minClips;
    return CountTickText(
      text: text,
      textKey: textKey,
      textAlign: TextAlign.center,
      style: context.typography.titleSmall.copyWith(
        color: enough ? colors.tx : colors.mu,
      ),
    );
  }
}

/// The diary could not be read: why, and Try again.
class _Unreadable extends StatelessWidget {
  const _Unreadable();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 4,
      children: <Widget>[
        Flexible(
          child: Text(
            Strings.storageUnavailableTitle,
            key: ClipsFoundCount.textKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.typography.titleSmall.copyWith(
              color: context.colors.mu,
            ),
          ),
        ),
        OsdTextButton(
          label: Strings.commonTryAgain,
          hug: true,
          onPressed: () =>
              unawaited(context.read<CreateMovieCubit>().readAgain()),
        ),
      ],
    ),
  );
}
