import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';

/// The making page's error variant, in place of the progress: why the movie
/// wasn't made, and "Report error" when something went wrong that the developer
/// should see.
class MakingMovieError extends StatelessWidget {
  const MakingMovieError({super.key});

  static const Key calloutKey = Key('makingMovieError.callout');

  static const Key reportKey = Key('makingMovieError.report');

  @override
  Widget build(BuildContext context) {
    final ({MovieJobFailure? failure, int? shortfall, int skipped}) job =
        context.select<
          MovieJobBloc,
          ({MovieJobFailure? failure, int? shortfall, int skipped})
        >(
          (MovieJobBloc job) => (
            failure: job.state.failure,
            shortfall: job.state.spaceShortfall,
            skipped: job.state.skippedClips,
          ),
        );
    final (String text, OsdCalloutKind kind) = switch (job.failure) {
      MovieJobFailure.notEnoughClips => (
        // Too few are left because some could not be read: say how many.
        job.skipped > 0
            ? '${Strings.movieInsufficientVideos} '
                  '${Strings.movieSkippedClips(job.skipped, format: MovieLabels.numberFormat(context))}'
            : Strings.movieInsufficientVideos,
        OsdCalloutKind.warning,
      ),
      MovieJobFailure.noSpace => (
        switch (job.shortfall) {
          final int bytes => Strings.makingMovieNoSpace(
            size: MovieLabels.size(context, bytes),
          ),
          null => Strings.makingMovieNoSpaceUnknown,
        },
        OsdCalloutKind.error,
      ),
      MovieJobFailure.failed ||
      null => (Strings.makingMovieError, OsdCalloutKind.error),
    };
    final bool reportable =
        job.failure != MovieJobFailure.notEnoughClips &&
        job.failure != MovieJobFailure.noSpace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: OsdCallout.neutral(key: calloutKey, text: text, kind: kind),
        ),
        if (reportable) const _ReportButton(),
      ],
    );
  }
}

/// "Report error": the mail app with the logs; off while it opens.
class _ReportButton extends StatelessWidget {
  const _ReportButton();

  @override
  Widget build(BuildContext context) {
    final bool sending = context.select<ReportErrorCubit, bool>(
      (ReportErrorCubit report) => report.state == ReportErrorStatus.sending,
    );
    return OsdTextButton(
      key: MakingMovieError.reportKey,
      label: Strings.reportError,
      onPressed: sending
          ? null
          : () => unawaited(
              context.read<ReportErrorCubit>().report(
                body: Strings.errorMailBody,
              ),
            ),
    );
  }
}
