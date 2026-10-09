import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/shared/widgets/buttons/tinted_pill_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// "Make movie" for [month] (the calendar's month header, each Memories
/// header): starts a movie of that month with the active profile
/// (`CreateMovieArgs(source: MovieSource.month(…))`), with the Diary's tag
/// filter when one is on (its text search is not a movie filter and stays
/// behind). With fewer than two clips in the month (that the tags keep) it
/// is dimmed, and a tap says why (two clips of one day are enough).
///
/// [iconOnly] shows only the glyph (the label becomes its tooltip), where
/// the label would cut the month title (`MonthTitleRoom`).
class MakeMovieChip extends StatelessWidget {
  const MakeMovieChip({super.key, required this.month, this.iconOnly = false});

  static String get label => Strings.createMovie;

  final DiaryMonth month;

  /// The glyph alone, the label kept as tooltip and semantics (the month
  /// title needs the room).
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final (bool canMake, TagFilter tags) = context.select(
      (DiaryCubit cubit) =>
          (cubit.state.canMakeFilteredMovieOf(month), cubit.state.filter.tags),
    );
    return TintedPillButton(
      label: label,
      iconOnly: iconOnly,
      onPressed: canMake
          ? () => unawaited(
              CreateMovieArgs(
                source: MovieSource.month(
                  year: month.year,
                  month: month.month,
                  tags: tags,
                ),
              ).push<void>(context),
            )
          : null,
      onDisabledTap: () => OsdSnackbar.show(
        context,
        kind: OsdSnackKind.info,
        title: Strings.movieInsufficientVideos,
      ),
    );
  }
}
