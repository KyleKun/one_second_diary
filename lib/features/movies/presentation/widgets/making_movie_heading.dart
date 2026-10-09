import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The making page's title and subtitle: "Making your movie…", or "Couldn't
/// make your movie" once it failed (crossfading), over the movie's range
/// ("September 2026").
class MakingMovieHeading extends StatelessWidget {
  const MakingMovieHeading({super.key});

  static const Key titleKey = Key('makingMovieHeading.title');

  static const Key subtitleKey = Key('makingMovieHeading.subtitle');

  @override
  Widget build(BuildContext context) {
    final ({bool failed, String range}) job = context
        .select<MovieJobBloc, ({bool failed, String range})>(
          (MovieJobBloc job) => (
            failed: job.state.status == MovieJobStatus.failed,
            range: job.state.request?.title ?? '',
          ),
        );
    final OsdColors colors = context.colors;
    final String title = job.failed
        ? Strings.movieErrorTitle
        : Strings.makingMovieTitle;
    return Column(
      spacing: 6,
      children: <Widget>[
        AnimatedSwitcher(
          duration: OsdMotion.d(context, OsdMotion.fast),
          switchInCurve: OsdMotion.fastCurve,
          switchOutCurve: OsdMotion.fastCurve,
          child: Semantics(
            key: ValueKey<bool>(job.failed),
            header: true,
            child: Text(
              title,
              key: titleKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.display,
              ),
              style: context.typography.displayHeadline.copyWith(
                color: colors.tx,
              ),
            ),
          ),
        ),
        Text(
          job.range,
          key: subtitleKey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.typography.body15.copyWith(color: colors.mu),
        ),
      ],
    );
  }
}
