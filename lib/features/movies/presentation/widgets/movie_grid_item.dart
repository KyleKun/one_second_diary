import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/hero_tags.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_poster_view.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/controls/selection_badge.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/shared/widgets/media/clip_scrim.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A movie in My movies: the 16:9 poster with the play glyph, the title, then
/// its clips and length ("25 clips · 1:23"; none for a movie without).
class MovieGridItem extends StatelessWidget {
  const MovieGridItem({super.key, required this.movie, this.large = false});

  /// The item of the movie at [file] (its path in `Movies/`).
  static Key itemKey(String file) =>
      ValueKey<(String, String)>(('movieGridItem', file));

  /// The play glyph (its fade).
  static const Key playKey = Key('movieGridItem.play');

  static const Key titleKey = Key('movieGridItem.title');

  static const Key countKey = Key('movieGridItem.count');

  /// The selected shrink.
  static const Key scaleKey = Key('movieGridItem.scale');

  /// The scrim and the badge of selection mode (their fade).
  static const Key selectionKey = Key('movieGridItem.selection');

  /// The gap between the poster and the title.
  static const double posterGap = 6;

  /// The gap between the title and the count.
  static const double countGap = 2;

  /// The profile label on the poster.
  static const Key profileKey = Key('movieGridItem.profile');

  /// The tag badge of a movie made with a tag filter.
  static const Key tagBadgeKey = Key('movieGridItem.tagBadge');

  final MovieEntry movie;

  /// Whether it is the large view's item.
  final bool large;

  /// The title's style, which the grid measures its rows with.
  static TextStyle titleStyle(
    OsdTypography typography, {
    required bool large,
  }) => large ? typography.titleSmall : typography.label14Strong;

  Future<void> _play(BuildContext context) async {
    if (!await context.read<MyMoviesCubit>().canPlay(movie)) return;
    if (context.mounted) {
      unawaited(MoviePlayerArgs(file: movie.fileName).push<void>(context));
    }
  }

  void _tap(BuildContext context, {required bool selecting}) {
    if (selecting) {
      unawaited(OsdHaptic.selection.play());
      context.read<MyMoviesCubit>().toggle(movie);
    } else {
      unawaited(_play(context));
    }
  }

  void _longPress(BuildContext context, {required bool selecting}) {
    unawaited((selecting ? OsdHaptic.selection : OsdHaptic.medium).play());
    context.read<MyMoviesCubit>().select(movie);
  }

  @override
  Widget build(BuildContext context) {
    final (bool selecting, bool selected) = context
        .select<MyMoviesCubit, (bool, bool)>(
          (MyMoviesCubit movies) => (
            movies.state.selecting,
            movies.state.selected.contains(movie.fileName),
          ),
        );
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final double corner = large ? OsdRadius.r20 : OsdRadius.r14;
    final BorderRadius radius = BorderRadius.circular(corner);
    // The title is the movie's own; a screen reader hears the profile too.
    final String title = MovieLabels.baseTitle(context, movie);
    final String spoken = MovieLabels.movieTitle(context, movie);
    final String? count = MovieLabels.clipsLine(context, movie);
    final Duration fast = OsdMotion.d(context, OsdMotion.fast);
    final Curve fastCurve = OsdMotion.curve(context, OsdMotion.fastCurve);
    final String semantics = count == null
        ? Strings.movieItemSemanticsNoCount(name: spoken)
        : Strings.movieItemSemantics(name: spoken, clips: count);
    return OsdPressable(
      onTap: () => _tap(context, selecting: selecting),
      onLongPress: () => _longPress(context, selecting: selecting),
      pressScale: OsdPressScale.button.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: radius,
      selected: selecting ? selected : null,
      // A screen reader hears the tag filter too (the badge says it).
      semanticsLabel: movie.hasTagFilter
          ? '$semantics. ${Strings.movieHasTagFilter}'
          : semantics,
      // The platform says the gestures ("double-tap to play"); selecting,
      // a tap picks, which the platform's own words say.
      semanticsTapHint: selecting ? null : Strings.play,
      semanticsLongPressHint: selecting ? null : Strings.movieItemLongPressHint,
      excludeChildSemantics: true,
      child: AnimatedScale(
        key: scaleKey,
        // No scale under reduced motion: the ring and the badge say it is
        // selected.
        scale: selected && !OsdMotion.reduced(context) ? .94 : 1,
        duration: OsdMotion.d(context, OsdMotion.standard),
        curve: OsdMotion.curve(context, OsdMotion.standardCurve),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: selected ? 1 : 0),
                duration: fast,
                curve: fastCurve,
                builder: (BuildContext context, double ring, Widget? child) =>
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: ring == 0
                            ? null
                            : <BoxShadow>[
                                BoxShadow(
                                  color: colors.tx,
                                  spreadRadius: 3 * ring,
                                ),
                              ],
                      ),
                      child: child,
                    ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    OsdHero(
                      tag: HeroTags.movie(movie.fileName),
                      radius: corner,
                      child: RepaintBoundary(
                        child: MoviePosterView(
                          posters: context.read<MoviePosters>(),
                          file: movie.fileName,
                          orientation: movie.orientation,
                          radius: corner,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      // Clear of the selection badge at the other corner.
                      end: 40,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: _ProfileLabel(movie: movie),
                      ),
                    ),
                    // A movie made with private clips wears a lock, so it is
                    // not shared by mistake; one made with a tag filter wears a
                    // tag.
                    if (movie.privateClipCount > 0 || movie.hasTagFilter)
                      PositionedDirectional(
                        end: 8,
                        bottom: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: <Widget>[
                            if (movie.hasTagFilter) const _TagBadge(),
                            if (movie.privateClipCount > 0)
                              const _PrivateBadge(),
                          ],
                        ),
                      ),
                    AnimatedOpacity(
                      key: selectionKey,
                      opacity: selecting ? 1 : 0,
                      duration: fast,
                      curve: fastCurve,
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            const ClipScrim(),
                            PositionedDirectional(
                              top: 8,
                              end: 8,
                              child: SelectionBadge(
                                selected: selected,
                                style: SelectionBadgeStyle.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (large)
                      Center(
                        child: AnimatedOpacity(
                          key: playKey,
                          opacity: selecting ? 0 : 1,
                          duration: fast,
                          curve: fastCurve,
                          child: const PlayOverlayButton(
                            size: PlayOverlaySize.medium,
                          ),
                        ),
                      )
                    else
                      PositionedDirectional(
                        start: 8,
                        bottom: 6,
                        child: AnimatedOpacity(
                          key: playKey,
                          opacity: selecting ? 0 : 1,
                          duration: fast,
                          curve: fastCurve,
                          child: const OsdIcon(
                            OsdIcons.playArrow,
                            fill: 1,
                            color: OsdMedia.onMedia,
                            shadows: <Shadow>[OsdMedia.playIconShadow],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: posterGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedSwitcher(
                duration: fast,
                layoutBuilder: _stackStart,
                child: KeyedSubtree(
                  key: ValueKey<String>(title),
                  child: Text(
                    title,
                    key: titleKey,
                    // Two lines from text scale 1.3.
                    maxLines: OsdTextScale.nameLines(context),
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle(
                      typography,
                      large: large,
                    ).copyWith(color: colors.tx),
                  ),
                ),
              ),
            ),
            if (count != null) ...<Widget>[
              const SizedBox(height: countGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  count,
                  key: countKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(color: colors.mu),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The title crossfade (a rename, tags read) keeps its start alignment.
  static Widget _stackStart(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.centerStart,
    children: <Widget>[...previous, ?current],
  );
}

/// The tag of a movie made with a tag filter ("only tagged…", "leave out
/// tagged…"); the player names the tags.
class _TagBadge extends StatelessWidget {
  const _TagBadge();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: Strings.movieHasTagFilter,
    child: const DecoratedBox(
      key: MovieGridItem.tagBadgeKey,
      decoration: BoxDecoration(
        color: OsdMedia.scrim55,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(5),
        child: OsdIcon(
          OsdIcons.sell,
          size: 14,
          fill: 1,
          color: OsdMedia.onMedia,
        ),
      ),
    ),
  );
}

/// The lock of a movie that includes private clips.
class _PrivateBadge extends StatelessWidget {
  const _PrivateBadge();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(color: OsdMedia.scrim55, shape: BoxShape.circle),
    child: Padding(
      padding: EdgeInsets.all(5),
      child: OsdIcon(OsdIcons.lock, size: 14, fill: 1, color: OsdMedia.onMedia),
    ),
  );
}

/// The profile a movie was made from, as a small chip on its poster: the
/// profile's picture and its current name.
class _ProfileLabel extends StatelessWidget {
  const _ProfileLabel({required this.movie});

  final MovieEntry movie;

  static const double _avatar = 18;

  @override
  Widget build(BuildContext context) {
    final ProfileKey? owner = movie.profile;
    if (owner == null) return const SizedBox.shrink();
    final (Profile? profile, bool several) = context
        .select<ProfilesCubit, (Profile?, bool)>(
          (ProfilesCubit profiles) => (
            profiles.state.profiles
                .where((Profile profile) => profile.key == owner)
                .firstOrNull,
            profiles.state.profiles.length > 1,
          ),
        );
    if (owner.isDefault && !several) return const SizedBox.shrink();
    final String name = profile?.displayName ?? owner.value;
    final OsdColors colors = context.colors;
    return ExcludeSemantics(
      child: DecoratedBox(
        key: MovieGridItem.profileKey,
        decoration: BoxDecoration(
          color: colors.c2,
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(3, 3, 9, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: <Widget>[
              OsdAvatar(
                name: name,
                photo: profile == null
                    ? null
                    : ProfileAvatar.photoOf(context, profile),
                size: _avatar,
              ),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: colors.tx,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
