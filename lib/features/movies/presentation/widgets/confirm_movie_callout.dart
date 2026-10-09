import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/confirm_movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The confirmation's callout below the summary: not enough space, too few
/// clips, a note about hand-picked clips, or the skipped days; none when
/// nothing applies. Announced to screen readers.
class ConfirmMovieCallout extends StatelessWidget {
  const ConfirmMovieCallout({super.key});

  /// The callout shown now.
  static const Key calloutKey = Key('confirmMovieCallout.callout');

  @override
  Widget build(BuildContext context) {
    final ({MovieDraft? draft, MovieLaunch launch, int? shortfall}) flow =
        context.select<
          CreateMovieCubit,
          ({MovieDraft? draft, MovieLaunch launch, int? shortfall})
        >(
          (CreateMovieCubit flow) => (
            draft: flow.state.draft,
            launch: flow.state.launch,
            shortfall: flow.state.spaceShortfall,
          ),
        );
    final (String, OsdCalloutKind)? callout = _calloutOf(
      context,
      flow.draft,
      noSpace: flow.launch == MovieLaunch.noSpace ? flow.shortfall : null,
    );
    return AnimatedSize(
      duration: OsdMotion.d(context, OsdMotion.standard),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: OsdMotion.d(context, OsdMotion.fast),
        switchInCurve: OsdMotion.fastCurve,
        switchOutCurve: OsdMotion.fastCurve,
        child: switch (callout) {
          null => const SizedBox(width: double.infinity),
          (final String text, final OsdCalloutKind kind) => KeyedSubtree(
            key: ValueKey<String>(text),
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Semantics(
                liveRegion: true,
                child: OsdCallout.neutral(
                  key: calloutKey,
                  text: text,
                  kind: kind,
                ),
              ),
            ),
          ),
        },
      ),
    );
  }

  static (String, OsdCalloutKind)? _calloutOf(
    BuildContext context,
    MovieDraft? draft, {
    required int? noSpace,
  }) {
    if (draft == null) return null;
    if (noSpace != null) {
      return (
        Strings.makingMovieNoSpace(size: MovieLabels.size(context, noSpace)),
        OsdCalloutKind.error,
      );
    }
    if (!draft.canMake) {
      return (Strings.movieInsufficientVideos, OsdCalloutKind.warning);
    }
    if (draft.source is CustomMovieSource) {
      return draft.privateIncluded > 0
          ? (
              Strings.moviePrivateIncluded(
                draft.privateIncluded,
                format: MovieLabels.numberFormat(context),
              ),
              OsdCalloutKind.warning,
            )
          : (Strings.movieHandPickedNote, OsdCalloutKind.info);
    }
    final int skipped = draft.skippedDays.length;
    if (skipped == 0) return null;
    return (
      skipped > ConfirmMovieLabels.listedSkippedDays
          ? Strings.movieSkippedDaysCount(
              skipped,
              format: MovieLabels.numberFormat(context),
            )
          : Strings.movieSkippedDays(
              skipped,
              days: ConfirmMovieLabels.skippedDays(context, draft),
              format: MovieLabels.numberFormat(context),
            ),
      OsdCalloutKind.info,
    );
  }
}
