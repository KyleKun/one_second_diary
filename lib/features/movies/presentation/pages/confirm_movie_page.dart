import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/confirm_movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/flow_profile.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/clip_mosaic.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/confirm_movie_callout.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/confirm_movie_heading.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/imported_convert_row.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/include_private_row.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_profile_chip.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/music_row.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/scroll_under_footer.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/still_reading_callout.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/transition_row.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Confirm the movie ("New movie"): the mosaic of its clips, the range title,
/// the clip count, profile and orientation, the days without a video, a note
/// while clips are still being read under a tag filter, "Include private clips"
/// when the range holds any, the "Transition" row (and its older-clips switch),
/// and "Create movie".
class ConfirmMoviePage extends StatelessWidget {
  const ConfirmMoviePage({super.key});

  static const Key createKey = Key('confirmMoviePage.create');

  static const double _maxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final double bottom = math.max(
      28,
      MediaQuery.viewPaddingOf(context).bottom + 8,
    );
    return MultiBlocListener(
      listeners: <BlocListener<CreateMovieCubit, CreateMovieState>>[
        BlocListener<CreateMovieCubit, CreateMovieState>(
          listenWhen: (CreateMovieState previous, CreateMovieState current) =>
              previous.launch != current.launch &&
              current.launch == MovieLaunch.ready,
          listener: _start,
        ),
        BlocListener<CreateMovieCubit, CreateMovieState>(
          listenWhen: (CreateMovieState previous, CreateMovieState current) =>
              previous.source is CustomMovieSource && current.source == null,
          listener: (BuildContext context, CreateMovieState state) =>
              unawaited(Navigator.maybePop(context)),
        ),
      ],
      child: Scaffold(
        backgroundColor: context.colors.bg,
        appBar: OsdAppBar(
          title: Strings.newMovieTitle,
          trailing: const MovieProfileChip(),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ScrollUnderFooter(
              content: const SingleChildScrollView(
                padding: EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _FlowMosaic(),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(4, 26, 4, 0),
                      child: ConfirmMovieHeading(),
                    ),
                    ConfirmMovieCallout(),
                    StillReadingCallout(),
                    ImportedConvertRow(),
                    IncludePrivateRow(),
                    TransitionRow(),
                    MusicRow(),
                  ],
                ),
              ),
              footer: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, bottom),
                child: const _CreateMovieButton(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The movie may start: the app's job makes it, the making page shows it.
  static void _start(BuildContext context, CreateMovieState state) {
    context.read<MovieJobBloc>().add(MovieJobStarted(state.request!));
    unawaited(AppRoute.makingMovie.push<void>(context));
  }
}

/// The mosaic of the flow's draft, in the profile's orientation.
class _FlowMosaic extends StatelessWidget {
  const _FlowMosaic();

  @override
  Widget build(BuildContext context) {
    final List<ClipRef> clips = context.select<CreateMovieCubit, List<ClipRef>>(
      (CreateMovieCubit flow) => flow.state.draft?.mosaic ?? const <ClipRef>[],
    );
    return ClipMosaic(
      clips: clips,
      orientation:
          FlowProfile.watch(context)?.orientation ?? VideoOrientation.landscape,
    );
  }
}

/// "Create movie": off with too few clips; a spinner while the free space
/// is checked.
class _CreateMovieButton extends StatelessWidget {
  const _CreateMovieButton();

  @override
  Widget build(BuildContext context) {
    final ({MovieDraft? draft, bool checking}) flow = context
        .select<CreateMovieCubit, ({MovieDraft? draft, bool checking})>(
          (CreateMovieCubit flow) => (
            draft: flow.state.draft,
            checking: flow.state.launch == MovieLaunch.checking,
          ),
        );
    final MovieDraft? draft = flow.draft;
    return PrimaryButton(
      key: ConfirmMoviePage.createKey,
      label: Strings.createMovie,
      icon: OsdIcons.movie,
      size: OsdButtonSize.hero,
      emphasis: true,
      haptic: OsdHaptic.light,
      loading: flow.checking,
      onPressed: draft == null || !draft.canMake
          ? null
          : () => unawaited(
              context.read<CreateMovieCubit>().startMovie(
                title: ConfirmMovieLabels.title(context, draft),
              ),
            ),
    );
  }
}
