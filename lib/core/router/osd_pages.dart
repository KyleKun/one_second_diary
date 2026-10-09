import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/osd_fade_through_page.dart';
import 'package:one_second_diary/core/router/osd_media_flight_page.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The pages every route builds (`pageBuilder`, never `builder`).
///
/// go_router 18 can't build Flutter's `MaterialPage` itself: it looks for
/// `material_ui`'s `MaterialApp`, not Flutter's, and falls back to pages
/// with no transition and no iOS back swipe. So every route builds its page
/// here, keyed and named as go_router would:
/// - [material]: every push, with the theme's platform transition (the iOS
///   edge swipe, Android predictive back), or a 150 ms crossfade under
///   reduced motion; `fullscreenDialog` for the support page.
/// - [fadeThrough]: a page that takes another's place (the camera → the
///   clip editor, the Create movie steps, onboarding → Today): the
///   fade-through, keeping the platform's back gestures; [flow] when only
///   some openers replace (My movies → Create movie).
/// - [mediaFlight]: a page media flies into with a `Hero` (the camera, the
///   viewer, the movie player): the page fades in while the hero flies.
abstract final class OsdPages {
  /// The page of a pushed route, as go_router would build it in a Flutter
  /// `MaterialApp`.
  static Page<void> material(
    GoRouterState state,
    Widget child, {
    bool fullscreenDialog = false,
  }) => MaterialPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: _arguments(state),
    restorationId: state.pageKey.value,
    fullscreenDialog: fullscreenDialog,
    child: child,
  );

  /// The page of a route that replaces another (`RouteArgs.pushReplacement`,
  /// `AppRoute.go`): it enters with the fade-through
  /// (`OsdFadeThroughPage`).
  static Page<void> fadeThrough(GoRouterState state, Widget child) =>
      OsdFadeThroughPage<void>(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: _arguments(state),
        restorationId: state.pageKey.value,
        child: child,
      );

  /// The page of a flow that some open with a push and one with a
  /// replacement (Create movie: Journey pushes it, My movies' empty state
  /// replaces itself with it): the fade-through when [replacing], the
  /// platform push otherwise. Its route keeps the transition it was made
  /// with, so the flow's later rebuilds (without the arguments) never change
  /// it.
  static Page<void> flow(
    GoRouterState state,
    Widget child, {
    required bool replacing,
  }) => OsdFadeThroughPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: _arguments(state),
    restorationId: state.pageKey.value,
    fadeThrough: replacing,
    child: child,
  );

  /// The page of a route that media flies into (`OsdMediaFlightPage`):
  /// the camera, the viewer, the movie player.
  static Page<void> mediaFlight(
    GoRouterState state,
    Widget child, {
    Duration duration = OsdMotion.mediaFlight,
    Duration? fadeIn,
    Duration? reverseDuration,
  }) => OsdMediaFlightPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: _arguments(state),
    restorationId: state.pageKey.value,
    duration: duration,
    fadeIn: fadeIn ?? duration,
    reverseDuration: reverseDuration ?? duration,
    child: child,
  );

  static Map<String, String> _arguments(GoRouterState state) =>
      <String, String>{...state.pathParameters, ...state.uri.queryParameters};
}
