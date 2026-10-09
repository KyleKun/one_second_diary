import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';

/// The redirect of a route that needs its [T]: a location without one
/// (a deep link, a restored location; never a push, see `AppRoute.push`)
/// leads to [orElse], which replaces the stack.
GoRouterRedirect requireArgs<T extends RouteArgs>({required AppRoute orElse}) =>
    (BuildContext context, GoRouterState state) =>
        state.extra is T ? null : orElse.path;

/// The redirect of a route that takes an optional [T]: anything else leads
/// to [orElse].
GoRouterRedirect allowArgs<T extends RouteArgs>({required AppRoute orElse}) =>
    (BuildContext context, GoRouterState state) =>
        state.extra == null || state.extra is T ? null : orElse.path;

/// The [T] of a route whose redirect ([requireArgs]) made sure it has one.
/// Builders read their arguments with this, never by casting `state.extra`.
T argsOf<T extends RouteArgs>(GoRouterState state) => switch (state.extra) {
  final T args => args,
  _ => throw StateError(
    '${state.uri.path} was built without its $T; its redirect should have '
    'sent it elsewhere',
  ),
};

/// The [T] a route that [allowArgs] was opened with, or null.
T? maybeArgsOf<T extends RouteArgs>(GoRouterState state) =>
    switch (state.extra) {
      final T args => args,
      _ => null,
    };
