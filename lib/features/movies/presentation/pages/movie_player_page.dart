import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/movie_playback.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/movie_chapters_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_player_screen.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_seek_bar.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/viewer_top_bar.dart';
import 'package:one_second_diary/shared/widgets/foundation/sideways_chrome.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// The movie player (`/movies/play?file=`; always dark: its route wraps it in
/// `OsdForcedDark`).
class MoviePlayerPage extends StatefulWidget {
  const MoviePlayerPage({super.key});

  /// The movie on screen (one button).
  static const Key screenKey = MoviePlayerScreen.buttonKey;

  /// The Chapters button in the bar (only for a movie with chapters).
  static const Key chaptersKey = Key('moviePlayerPage.chapters');

  /// The chapter playing, under the title (only for a movie with chapters).
  static const Key chapterKey = Key('moviePlayerPage.chapter');

  /// The widest the movie is shown (a tablet).
  static const double _maxWidth = 900;

  @override
  State<MoviePlayerPage> createState() => _MoviePlayerPageState();
}

class _MoviePlayerPageState extends State<MoviePlayerPage>
    with SingleTickerProviderStateMixin {
  /// Where the movie lives, kept as the phone turns.
  final GlobalKey _screenKey = GlobalKey();

  late final MoviePlayerCubit _cubit = context.read<MoviePlayerCubit>();
  late final MoviePlayback _playback = MoviePlayback(
    pool: context.read<PlayerPool>(),
    path: '${context.read<AppPaths>().movies}${_cubit.state.file}',
    vsync: this,
    onPlayingChanged: (bool playing) => _cubit.playingChanged(playing: playing),
  );

  @override
  void initState() {
    super.initState();
    _cubit.attachPlayback(seekTo: _playback.seekToPosition);
    _playback.progress.addListener(_onProgress);
    _playback.start();
  }

  @override
  void dispose() {
    _playback.progress.removeListener(_onProgress);
    _playback.dispose();
    super.dispose();
  }

  /// The chapter follows the playback (cheap: the cubit emits only when it
  /// crosses into another chapter).
  void _onProgress() => _cubit.positionChanged(_playback.position);

  @override
  Widget build(BuildContext context) {
    final ({MoviePlayerStatus status, VideoOrientation? orientation}) movie =
        context.select<
          MoviePlayerCubit,
          ({MoviePlayerStatus status, VideoOrientation? orientation})
        >(
          (MoviePlayerCubit cubit) => (
            status: cubit.state.status,
            orientation: cubit.state.movie?.orientation,
          ),
        );
    final bool missing = movie.status == MoviePlayerStatus.missing;
    return MultiBlocListener(
      listeners: <BlocListener<MoviePlayerCubit, MoviePlayerState>>[
        BlocListener<MoviePlayerCubit, MoviePlayerState>(
          listenWhen: (MoviePlayerState previous, MoviePlayerState current) =>
              previous.muted != current.muted,
          listener: (BuildContext context, MoviePlayerState state) =>
              unawaited(_playback.setMuted(state.muted)),
        ),
        // A missing movie is not played on in the dark.
        BlocListener<MoviePlayerCubit, MoviePlayerState>(
          listenWhen: (MoviePlayerState previous, MoviePlayerState current) =>
              current.status == MoviePlayerStatus.missing &&
              previous.status != MoviePlayerStatus.missing,
          listener: (BuildContext context, MoviePlayerState state) =>
              _playback.pause(),
        ),
      ],
      child: Scaffold(
        backgroundColor: OsdViewer.background,
        body: SidewaysChrome(
          builder: (BuildContext context, SidewaysChromeState chrome) {
            final Widget screen = KeyedSubtree(
              key: _screenKey,
              child: AspectRatio(
                aspectRatio: movie.orientation == VideoOrientation.portrait
                    ? 9 / 16
                    : 16 / 9,
                child: MoviePlayerScreen(
                  playback: _playback,
                  posters: context.read<MoviePosters>(),
                  file: _cubit.state.file,
                  orientation: movie.orientation,
                  missing: missing,
                ),
              ),
            );
            final Widget seek = Visibility(
              visible: !missing,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _MovieSeek(playback: _playback),
              ),
            );
            return chrome.sideways
                ? _Sideways(
                    screen: screen,
                    seek: seek,
                    shown: chrome.shown,
                    onRevealTap: chrome.reveal,
                    onHideTap: chrome.hide,
                  )
                : _Upright(screen: screen, seek: seek);
          },
        ),
      ),
    );
  }
}

/// Upright (and on tablets): the bar, the movie full width with the seek
/// bar under it.
class _Upright extends StatelessWidget {
  const _Upright({required this.screen, required this.seek});

  final Widget screen;
  final Widget seek;

  @override
  Widget build(BuildContext context) {
    final double bottom = math.max(
      28,
      MediaQuery.viewPaddingOf(context).bottom + 12,
    );
    return Column(
      children: <Widget>[
        const _MoviePlayerBar(),
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MoviePlayerPage._maxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: screen),
                    seek,
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: bottom),
      ],
    );
  }
}

/// A phone turned sideways: the movie fills the screen, the bar and the seek
/// bar lie over it as much as [shown] says; a tap beside the movie and the
/// controls hides them, and while they are hidden a tap anywhere brings
/// them back.
class _Sideways extends StatelessWidget {
  const _Sideways({
    required this.screen,
    required this.seek,
    required this.shown,
    required this.onRevealTap,
    required this.onHideTap,
  });

  final Widget screen;
  final Widget seek;
  final Animation<double> shown;

  /// Brings the chrome back; null while it shows.
  final VoidCallback? onRevealTap;

  /// Hides the chrome; null while it is hidden.
  final VoidCallback? onHideTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRevealTap = this.onRevealTap;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onHideTap,
        ),
        Center(child: screen),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          // The scrims take hits of their own.
          child: GestureDetector(
            onTap: onHideTap,
            child: FadeTransition(
              opacity: shown,
              child: DecoratedBox(
                decoration: SidewaysChrome.scrim(top: true),
                child: const _MoviePlayerBar(),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: onHideTap,
            child: FadeTransition(
              opacity: shown,
              child: DecoratedBox(
                decoration: SidewaysChrome.scrim(top: false),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: seek,
                ),
              ),
            ),
          ),
        ),
        if (onRevealTap != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRevealTap,
            ),
          ),
      ],
    );
  }
}

/// Close, the movie's title over its clips and length ("25 clips · 1:23 ·
/// Tagged trip" for a movie made with a tag filter) or, for a movie with
/// chapters, over the chapter playing, the Chapters button, and the sound
/// toggle.
class _MoviePlayerBar extends StatelessWidget {
  const _MoviePlayerBar();

  @override
  Widget build(BuildContext context) {
    final (
      MovieEntry? movie,
      bool muted,
      bool missing,
      MovieChapter? chapter,
    ) = context
        .select<MoviePlayerCubit, (MovieEntry?, bool, bool, MovieChapter?)>(
          (MoviePlayerCubit cubit) => (
            cubit.state.movie,
            cubit.state.muted,
            cubit.state.status == MoviePlayerStatus.missing,
            cubit.state.currentChapter,
          ),
        );
    final List<String> clipsLine = <String>[
      if (movie != null) ...<String>[
        ?MovieLabels.clipsLine(context, movie),
        ?MovieLabels.tagFilter(
          context,
          tags: movie.tags,
          without: movie.without,
        ),
      ],
    ];
    final String? clipsText = clipsLine.isEmpty ? null : clipsLine.join(' · ');
    final List<MovieChapter> chapters =
        movie?.chapters ?? const <MovieChapter>[];
    final bool chaptered = chapters.isNotEmpty && !missing;
    return ViewerTopBar(
      onClose: () => context.pop(),
      closeTooltip: Strings.viewerExitFullScreen,
      title: movie == null ? null : MovieLabels.movieTitle(context, movie),
      subtitle: chaptered ? null : clipsText,
      subtitleChild: chaptered && chapter != null
          ? _ChapterLine(
              title: chapter.title,
              number: chapters.indexOf(chapter) + 1,
              total: chapters.length,
            )
          : null,
      actions: <Widget>[
        if (chaptered)
          OsdIconButton(
            key: MoviePlayerPage.chaptersKey,
            icon: OsdIcons.viewAgenda,
            tooltip: Strings.movieChapters,
            onPressed: () => unawaited(
              MovieChaptersSheet.show(context, subtitle: clipsText),
            ),
          ),
      ],
      muted: muted,
      onToggleMute: missing
          ? null
          : () => context.read<MoviePlayerCubit>().toggleSound(),
      muteTooltip: Strings.playerMute,
      unmuteTooltip: Strings.playerUnmute,
    );
  }
}

/// The chapter playing, in the bar's subtitle line: its title, crossfading into
/// the next one's as the movie moves on (a plain change under reduced motion).
class _ChapterLine extends StatelessWidget {
  const _ChapterLine({
    required this.title,
    required this.number,
    required this.total,
  });

  final String title;

  /// The chapter's number, from 1.
  final int number;

  final int total;

  @override
  Widget build(BuildContext context) {
    final NumberFormat numbers = MovieLabels.numberFormat(context);
    return Semantics(
      key: MoviePlayerPage.chapterKey,
      label: Strings.movieChapterOf(
        current: numbers.format(number),
        total: numbers.format(total),
      ),
      value: title,
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: OsdMotion.d(context, OsdMotion.standard),
        switchInCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
        switchOutCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.center,
          children: <Widget>[...previous, ?current],
        ),
        child: Text(
          title,
          key: ValueKey<String>(title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The seek bar, following the movie's length once known.
class _MovieSeek extends StatelessWidget {
  const _MovieSeek({required this.playback});

  final MoviePlayback playback;

  @override
  Widget build(BuildContext context) {
    final List<MovieChapter> chapters = context
        .select<MoviePlayerCubit, List<MovieChapter>>(
          (MoviePlayerCubit cubit) => cubit.state.chapters,
        );
    return ValueListenableBuilder<Duration>(
      valueListenable: playback.duration,
      builder: (BuildContext context, Duration duration, _) => MovieSeekBar(
        progress: playback.progress,
        duration: duration,
        onSeek: playback.seekTo,
        chapters: chapters,
      ),
    );
  }
}
