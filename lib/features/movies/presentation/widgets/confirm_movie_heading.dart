import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/presentation/confirm_movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/flow_profile.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The confirmation's title and summary: the range ("September 2026"), "25
/// clips · Default · Landscape" and, under a tag filter, "Tagged trip · Without
/// work".
class ConfirmMovieHeading extends StatelessWidget {
  const ConfirmMovieHeading({super.key});

  static const Key titleKey = Key('confirmMovieHeading.title');

  static const Key summaryKey = Key('confirmMovieHeading.summary');

  /// The tag filter line; absent without a filter.
  static const Key tagsKey = Key('confirmMovieHeading.tags');

  @override
  Widget build(BuildContext context) {
    final (MovieDraft? draft, int? durationMs) = context
        .select<CreateMovieCubit, (MovieDraft?, int?)>(
          (CreateMovieCubit flow) =>
              (flow.state.draft, flow.state.draftDurationMs),
        );
    final Profile? profile = FlowProfile.watch(context);
    final OsdColors colors = context.colors;
    final String title = draft == null
        ? ''
        : ConfirmMovieLabels.title(context, draft);
    final String summary = draft == null || profile == null
        ? ''
        : Strings.movieSummary(
            clips: _clipsAndLength(context, draft, durationMs),
            profile: profile.displayName,
            orientation: ProfileLabels.orientation(profile.orientation),
          );
    final String tags = draft == null
        ? ''
        : ConfirmMovieLabels.tagFilter(context, draft) ?? '';
    return Column(
      spacing: 6,
      children: <Widget>[
        _Crossfade(
          text: title,
          child: Semantics(
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
              style: context.typography.title30Wrap.copyWith(color: colors.tx),
            ),
          ),
        ),
        _Crossfade(
          text: summary,
          child: Text(
            summary,
            key: summaryKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.typography.body15.copyWith(color: colors.mu),
          ),
        ),
        _Crossfade(
          text: tags,
          child: tags.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  tags,
                  key: tagsKey,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.typography.body15.copyWith(color: colors.mu),
                ),
        ),
      ],
    );
  }
}

/// "25 clips", or "12 min · 25 clips" once the clips' length is known.
String _clipsAndLength(BuildContext context, MovieDraft draft, int? ms) {
  final String clips = Strings.clipCount(
    draft.clips.length,
    format: MovieLabels.numberFormat(context),
  );
  if (ms == null) return clips;
  return Strings.movieLengthAndClips(
    length: MovieLabels.roughDuration(Duration(milliseconds: ms)),
    clips: clips,
  );
}

/// [child] crossfading in when [text] changes.
class _Crossfade extends StatelessWidget {
  const _Crossfade({required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: OsdMotion.d(context, OsdMotion.fast),
    switchInCurve: OsdMotion.fastCurve,
    switchOutCurve: OsdMotion.fastCurve,
    child: KeyedSubtree(key: ValueKey<String>(text), child: child),
  );
}
