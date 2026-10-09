import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Every screen the router knows, by path.
///
/// The four tabs live in the shell; every other route is full screen on the
/// root navigator, above the shell (no nav), and is always pushed, never
/// gone to, so back returns to the tab as it was. Use [AppRouteNavigation]
/// (and `RouteArgs.push` for a route that [needsArguments]) instead of
/// spelling paths.
enum AppRoute {
  /// The intro carousel. With [onboardingOrientation] and
  /// [onboardingPermissions], the only routes before onboarding is done.
  onboarding('/onboarding'),

  /// The Default profile's orientation (and the optional name), pushed from
  /// the carousel (Next on its last page).
  onboardingOrientation('/onboarding/orientation'),

  /// The permissions step: one "Allow" per permission the app uses,
  /// then "Continue". Pushed from the orientation step (Continue), or
  /// from the carousel when the canvas is already decided (a reinstall).
  onboardingPermissions('/onboarding/permissions'),

  /// The phone check: the tests and the recommended quality, whose
  /// "Use this" / "Choose another" / "Skip" finish onboarding. Pushed from
  /// the permissions step (Continue).
  onboardingPhoneCheck('/onboarding/phone-check'),

  /// Tab 0.
  today('/today'),

  /// Tab 1.
  diary('/diary'),

  /// Tab 2.
  journey('/journey'),

  /// Tab 3.
  settings('/settings'),

  /// Journey › Places: the globe of where the clips were filmed.
  placesMap('/journey/places'),

  /// The clips of one place (or a group of places), always dark; needs
  /// `PlaceClipsArgs`.
  placeClips('/journey/places/clips'),

  /// Every country or every place of the year shown; needs
  /// `PlacesListArgs`.
  placesList('/journey/places/list'),

  /// Always dark; needs `RecordArgs`.
  record('/record'),

  /// Needs `EditClipArgs`.
  editClip('/edit-clip'),

  /// Always dark; needs `ViewerArgs`.
  viewer('/viewer'),

  myMovies('/movies'),

  /// The movie player, always dark; needs `MoviePlayerArgs` (the `file`
  /// query parameter: the movie's path relative to `Movies/`).
  moviePlayer('/movies/play'),

  /// The start of the Create movie flow; takes `CreateMovieArgs`.
  createMovie('/movies/create'),

  pickClips('/movies/create/pick'),

  /// The Diary's "Make movie" lands here with `CreateMovieArgs`.
  confirmMovie('/movies/create/confirm'),

  makingMovie('/movies/create/making'),

  movieCreated('/movies/create/done'),

  notifications('/settings/notifications'),

  preferences('/settings/preferences'),

  /// Settings › Check again: the phone check on demand.
  phoneCheck('/settings/phone-check'),

  profiles('/settings/profiles'),

  /// Settings › Tags: every tag with its clip count (rename, merge,
  /// remove, colour).
  tags('/settings/tags'),

  /// Settings › Places: the places saved for the clip editor (add, rename,
  /// coordinates, remove).
  places('/settings/places'),

  about('/settings/about'),

  changelog('/settings/about/changelog'),

  thanks('/settings/about/thanks'),

  /// The open-source licences (Flutter's `LicensePage`).
  licenses('/settings/about/licenses'),

  support('/settings/support');

  const AppRoute(this.path);

  /// The absolute path.
  final String path;

  /// The query parameter of [moviePlayer] naming the movie.
  static const String movieFileParameter = 'file';

  /// The `GoRoute.path` of this route: the rest of its path below
  /// [parent], or its absolute path when it has none.
  String pathBelow(AppRoute? parent) =>
      parent == null ? path : path.substring(parent.path.length + 1);

  /// Whether this route only opens with its arguments, through
  /// `RouteArgs.push`.
  bool get needsArguments => switch (this) {
    record ||
    editClip ||
    viewer ||
    moviePlayer ||
    placeClips ||
    placesList => true,
    _ => false,
  };
}

/// Navigation by [AppRoute], from any context below the router.
extension AppRouteNavigation on AppRoute {
  /// Replaces the whole stack with this route. Only for the tabs and flow
  /// resets (onboarding → Today, a reminder tap, the created movie's "Done").
  void go(BuildContext context) => context.go(path);

  /// Pushes this route, which takes no arguments, and completes with what
  /// it pops with.
  ///
  /// A route that [AppRoute.needsArguments] opens with them instead
  /// (`EditClipArgs(…).push(context)`); pushing it here throws a
  /// [StateError]. Its redirect, the last resort without arguments, would
  /// otherwise push its fallback tab into the tab the user is on.
  Future<T?> push<T extends Object?>(BuildContext context) {
    if (needsArguments) {
      throw StateError(
        '$path needs its arguments: open it with its RouteArgs.push',
      );
    }
    return context.push<T>(path);
  }
}
