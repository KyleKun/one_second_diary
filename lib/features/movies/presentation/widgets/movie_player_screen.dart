import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/router/hero_tags.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/presentation/movie_playback.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_poster_view.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// The movie in the movie player: on black, no corners, its poster (the first
/// frame) at once and the video fading in over it once its player is ready.
class MoviePlayerScreen extends StatelessWidget {
  const MoviePlayerScreen({
    super.key,
    required this.playback,
    required this.posters,
    required this.file,
    required this.orientation,
    required this.missing,
  });

  /// The movie, as a button (its semantics).
  static const Key buttonKey = Key('moviePlayerScreen.button');

  /// The movie's path in `Movies/` (its hero's tag).
  final String file;

  final MoviePlayback playback;

  /// The poster's source (passed on: the hero flies above the route).
  final MoviePosters posters;

  /// The movie's shape; null while unknown (landscape).
  final VideoOrientation? orientation;

  /// Whether the movie is missing from `Movies/`: it can't be played.
  final bool missing;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MoviePhase>(
    valueListenable: playback.phase,
    builder: (BuildContext context, MoviePhase phase, Widget? frame) {
      final bool failed = missing || phase == MoviePhase.failed;
      return Semantics(
        key: buttonKey,
        container: true,
        button: !failed,
        label: failed
            ? null
            : phase == MoviePhase.playing
            ? Strings.playerPause
            : Strings.play,
        onTap: failed ? null : playback.toggle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: failed ? null : playback.toggle,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              frame!,
              if (failed)
                PlayerErrorBlock(
                  title: Strings.playerErrorTitle,
                  body: Strings.playerErrorBody,
                )
              else ...<Widget>[
                Center(
                  child: OsdLoadingDelay(
                    loading: phase == MoviePhase.loading,
                    builder: (BuildContext context, bool show) => show
                        ? const OsdSpinner(size: 28, color: OsdMedia.onMedia)
                        : const SizedBox.shrink(),
                  ),
                ),
                Center(
                  child: PlayOverlayButton(
                    visible:
                        phase == MoviePhase.paused || phase == MoviePhase.ended,
                    ended: phase == MoviePhase.ended,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
    child: ExcludeSemantics(
      child: OsdHero(
        tag: HeroTags.movie(file),
        radius: 0,
        child: _MovieFrame(
          playback: playback,
          posters: posters,
          file: file,
          orientation: orientation,
        ),
      ),
    ),
  );
}

/// The poster, and the video over it once shown: what flies.
class _MovieFrame extends StatelessWidget {
  const _MovieFrame({
    required this.playback,
    required this.posters,
    required this.file,
    required this.orientation,
  });

  final MoviePlayback playback;
  final MoviePosters posters;
  final String file;
  final VideoOrientation? orientation;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: OsdViewer.background,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MoviePosterView(
            posters: posters,
            file: file,
            orientation: orientation,
            slot: ClipThumbnailSlot.viewer,
          ),
          ValueListenableBuilder<PlayerHandle?>(
            valueListenable: playback.player,
            builder: (BuildContext context, PlayerHandle? player, _) =>
                ValueListenableBuilder<MoviePhase>(
                  valueListenable: playback.phase,
                  builder: (BuildContext context, MoviePhase phase, _) {
                    final bool ready =
                        player != null &&
                        phase != MoviePhase.loading &&
                        phase != MoviePhase.failed;
                    return AnimatedOpacity(
                      opacity: ready ? 1 : 0,
                      duration: OsdMotion.d(context, OsdMotion.fast),
                      curve: OsdMotion.curve(context, OsdMotion.fastCurve),
                      child: ready
                          ? Center(
                              child: AspectRatio(
                                aspectRatio: player.value.value.aspectRatio,
                                child: player.buildView(),
                              ),
                            )
                          : const SizedBox.expand(),
                    );
                  },
                ),
          ),
        ],
      ),
    ),
  );
}
