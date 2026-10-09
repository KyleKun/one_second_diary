import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The typed arguments of the routes that take them, and the only way to
/// open those routes: [push] opens [route] with them, so arguments of the
/// wrong type can't reach a route, and `AppRoute.push` refuses a route that
/// needs arguments (`AppRoute.needsArguments`).
///
/// They travel as go_router's `extra`. A route still checks the type in its
/// `redirect`, the last resort for a location that comes without them (a
/// deep link, a restored location); a page never casts `state.extra`.
sealed class RouteArgs extends Equatable {
  const RouteArgs();

  /// The route these arguments open.
  AppRoute get route;

  /// Where [push] goes: [route]'s path, with its query parameters.
  String get location => route.path;

  /// Pushes [route] with these arguments and completes with what it pops
  /// with.
  Future<T?> push<T extends Object?>(BuildContext context) =>
      context.push<T>(location, extra: this);

  /// Replaces the top route with [route] and these arguments: a page
  /// handing over to the next one, the camera to the clip editor when the
  /// recording is done (and the editor's "Record again" back to the
  /// camera).
  ///
  /// What the new route pops with also completes the push of the route it
  /// replaced, so whoever opened the chain always receives the result: a
  /// `SavedClip` reaches Today whether the user went through the camera or
  /// not. go_router drops the replaced push's future otherwise.
  Future<T?> pushReplacement<T extends Object?>(BuildContext context) {
    final GoRouter router = GoRouter.of(context);
    final RouteMatch? replaced =
        router.routerDelegate.currentConfiguration.lastOrNull;
    final Future<T?> result = router.pushReplacement<T>(location, extra: this);
    if (replaced is ImperativeRouteMatch) {
      unawaited(
        result.then((T? value) {
          if (!replaced.completer.isCompleted) replaced.complete(value);
        }),
      );
    }
    return result;
  }
}

/// The camera (`/record`): the day and profile the clip is for, and
/// whether it adds a clip or replaces one (Today's Edit sheet: Re-record).
///
/// The camera hands over to the clip editor with
/// `EditClipArgs(…).pushReplacement(context)`, so the `SavedClip` the
/// editor pops with reaches whoever opened the camera:
/// `final SavedClip? saved = await RecordArgs(…).push<SavedClip>(context)`.
final class RecordArgs extends RouteArgs {
  const RecordArgs({
    required this.day,
    required this.profile,
    this.mode = const AddClip(),
  });

  /// The day the origin records for (the camera is only for today).
  final LocalDay day;
  final ProfileKey profile;
  final ClipSaveMode mode;

  @override
  AppRoute get route => AppRoute.record;

  @override
  List<Object?> get props => <Object?>[day, profile, mode];
}

/// The clip editor (`/edit-clip`): the file a clip is made from, the day
/// and profile it goes to, and whether it adds a clip or replaces one.
///
/// It pops with the `SavedClip` it saved, or null when the user left
/// without saving:
/// `final SavedClip? saved = await EditClipArgs(…).push<SavedClip>(context)`.
final class EditClipArgs extends RouteArgs {
  const EditClipArgs({
    required this.source,
    required this.day,
    required this.profile,
    this.mode = const AddClip(),
    this.recovered = false,
    this.cameraSeconds,
    this.recordedSize,
    this.prefill,
    this.imported = false,
  });

  final ClipSource source;
  final LocalDay day;
  final ProfileKey profile;
  final ClipSaveMode mode;

  /// The source came back after Android killed the app while the system
  /// camera was open: the editor says so (`recordingRecovered`).
  final bool recovered;

  /// The clip length the in-app camera recorded this take for, in seconds:
  /// the editor opens its window on it, clamped to the file. Null for any
  /// other source (the phone's camera app, both cameras, a pick), which
  /// opens on the last quick cut.
  final int? cameraSeconds;

  /// The picture size the camera achieved, in the sensor's orientation:
  /// the editor notes "Recorded at 1080p" when it is below the profile's
  /// tier. Null when the platform did not say, or for a pick.
  final AchievedSize? recordedSize;

  /// How the clip was made the last time, for "Edit again" on a kept
  /// original: the editor opens pre-filled from it, clamped to the source
  /// field by field. Null opens with the editor's defaults.
  final ClipRecipe? prefill;

  /// The source is a foreign video processed into a clip (`origin=import`),
  /// opened again from its kept original: the save renders it as an import
  /// (`VideoRender.imported`), so the clip keeps its origin tag and the
  /// import's audio path. False for a recording and a gallery pick.
  final bool imported;

  @override
  AppRoute get route => AppRoute.editClip;

  @override
  List<Object?> get props => <Object?>[
    source,
    day,
    profile,
    mode,
    recovered,
    cameraSeconds,
    recordedSize,
    prefill,
  ];
}

/// The full-screen viewer (`/viewer`): the clip it opens on.
///
/// It pops with the `ClipRef` it shows last (the user may have stepped to
/// other clips and days), or null when it closed because none is left, so
/// the origin can select that day before the hero flies back:
/// `final ClipRef? last = await ViewerArgs(…).push<ClipRef>(context)`.
final class ViewerArgs extends RouteArgs {
  const ViewerArgs({
    required this.clip,
    this.warmPlayer,
    this.filter = const ClipFilter.none(),
  });

  final ClipRef clip;

  /// The Diary's filter when it opened the viewer: Previous and Next step
  /// through the clips it keeps only. Empty from Today and by default.
  final ClipFilter filter;

  /// The opener's ready player of [clip] (`PlayerPool.release`), which the
  /// viewer's pool adopts, so the clip plays at once; null opens it cold.
  /// The viewer owns it from the push. Not part of the arguments' identity.
  final ShownPlayer? warmPlayer;

  @override
  AppRoute get route => AppRoute.viewer;

  @override
  List<Object?> get props => <Object?>[clip, filter];
}

/// The clips of a place (`/journey/places/clips`): [clips] oldest first,
/// under [title] (the place, or a group's title), opened on
/// [initialIndex]; with [autoplay] each clip plays and the next follows.
final class PlaceClipsArgs extends RouteArgs {
  const PlaceClipsArgs({
    required this.title,
    required this.clips,
    this.initialIndex = 0,
    this.autoplay = false,
  });

  final String title;

  /// Oldest first; never empty.
  final List<ClipRef> clips;

  final int initialIndex;
  final bool autoplay;

  @override
  AppRoute get route => AppRoute.placeClips;

  @override
  List<Object?> get props => <Object?>[title, clips, initialIndex, autoplay];
}

/// Which list [PlacesListArgs] opens.
enum PlacesListKind { countries, places }

/// Places' full list (`/journey/places/list`): every country or every
/// place of [places] (the year shown, most clips first), under [year] (null
/// for all time). It pops with the `DiaryPlace` or `PlaceCountry` picked,
/// or null: `await PlacesListArgs(…).push<Object?>(context)`.
final class PlacesListArgs extends RouteArgs {
  const PlacesListArgs({
    required this.kind,
    required this.places,
    required this.year,
  });

  final PlacesListKind kind;
  final List<DiaryPlace> places;
  final int? year;

  @override
  AppRoute get route => AppRoute.placesList;

  @override
  List<Object?> get props => <Object?>[kind, places, year];
}

/// The movie player (`/movies/play?file=`): the movie, by its path
/// relative to `Movies/`. It travels as the `file` query parameter, which
/// the player reads.
final class MoviePlayerArgs extends RouteArgs {
  const MoviePlayerArgs({required this.file});

  final String file;

  @override
  AppRoute get route => AppRoute.moviePlayer;

  @override
  String get location => Uri(
    path: route.path,
    queryParameters: <String, String>{AppRoute.movieFileParameter: file},
  ).toString();

  @override
  List<Object?> get props => <Object?>[file];
}

/// The Create movie flow: [source] is the clips the flow starts with. With
/// one (the Diary's "Make movie", the month shown) the flow opens on the
/// confirmation (`/movies/create/confirm`); without, on the range choice
/// (`/movies/create`, also `AppRoute.createMovie.push`), with [preset]
/// picked when given (Journey's "Your life so far": All time), else the
/// default range. [tags] is the tag filter the flow opens with (the
/// Diary's, so "Make movie" under a filter makes a movie of what it
/// shows); every range and the picker follow it.
final class CreateMovieArgs extends RouteArgs {
  const CreateMovieArgs({
    this.source,
    this.preset,
    this._tags,
    this.replacing = false,
  });

  final MovieSource? source;

  /// The range the flow opens on.
  final MoviePreset? preset;

  // Nullable so the constructor stays const (`TagFilter.none` is not).
  final TagFilter? _tags;

  /// The tag filter the flow opens with; every clip without one.
  TagFilter get tags => _tags ?? TagFilter.none;

  /// The flow takes the opener's place (`pushReplacement`, My movies'
  /// empty state): it enters with the fade-through. Not part of the
  /// arguments' identity.
  final bool replacing;

  @override
  AppRoute get route =>
      source == null ? AppRoute.createMovie : AppRoute.confirmMovie;

  @override
  List<Object?> get props => <Object?>[source, preset, tags];
}
