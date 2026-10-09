import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Journey's way back to the movie being made, inside the movie card in
/// Start's place while [offers] holds (one movie at a time). A C2 card with
/// its title ("Making your movie…") and percent above its bar, which pulses
/// while the movie is saved; after a failure that page has not shown yet,
/// "Couldn't make your movie" and a chevron.
///
/// A tap opens the making-movie page, which shows the job as it is (and
/// moves on if it finished meanwhile). One button for screen readers: the
/// title, then the percent.
class JourneyMovieJobCard extends StatelessWidget {
  const JourneyMovieJobCard({super.key, required this.onTap});

  static const Key cardKey = Key('journeyMovieJobCard.card');

  static const Key percentKey = Key('journeyMovieJobCard.percent');

  /// Opens the making-movie page.
  final VoidCallback onTap;

  /// Whether the Journey offers [job]: while it is made (not while it
  /// stops), and after a failure until the making-movie page has shown it.
  static bool offers(MovieJobState job) => switch (job.status) {
    MovieJobStatus.preparing ||
    MovieJobStatus.rendering ||
    MovieJobStatus.finishing ||
    MovieJobStatus.failed => true,
    MovieJobStatus.idle ||
    MovieJobStatus.cancelling ||
    MovieJobStatus.cancelled ||
    MovieJobStatus.done => false,
  };

  @override
  Widget build(BuildContext context) {
    final ({MovieJobStatus status, double progress}) job = context
        .select<MovieJobBloc, ({MovieJobStatus status, double progress})>(
          (MovieJobBloc job) =>
              (status: job.state.status, progress: job.state.progress),
        );
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final bool failed = job.status == MovieJobStatus.failed;
    return OsdCard(
      key: cardKey,
      tone: OsdCardTone.c2,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: <Widget>[
          Row(
            spacing: 12,
            children: <Widget>[
              Expanded(
                child: Text(
                  failed ? Strings.movieErrorTitle : Strings.makingMovieTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.rowTitleStrong.copyWith(color: colors.tx),
                ),
              ),
              if (failed)
                OsdIcon(OsdIcons.chevronRight, color: colors.fa)
              else
                Text(
                  MovieLabels.percent(context, job.progress),
                  key: percentKey,
                  style: typography.titleSmall.copyWith(
                    color: colors.coInk,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
            ],
          ),
          if (!failed)
            OsdProgressBar(
              value: job.progress,
              finishing: job.status == MovieJobStatus.finishing,
            ),
        ],
      ),
    );
  }
}
