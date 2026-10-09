import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/clip_subtitles.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';

import '../shared/robots/app_robot.dart';
import '../support/support.dart';

void main() {
  testWidgets('every page reads the app-scoped cubits of the container', (
    WidgetTester tester,
  ) async {
    await AppRobot.launch(tester, prefs: legacyPrefs());

    final BuildContext page = tester.element(find.byType(Navigator).first);
    expect(page.read<LaunchCubit>(), same(sl<LaunchCubit>()));
    expect(page.read<ThemeCubit>(), same(sl<ThemeCubit>()));
    expect(page.read<LocaleCubit>(), same(sl<LocaleCubit>()));
    expect(page.read<ProfilesCubit>(), same(sl<ProfilesCubit>()));
    expect(page.read<UserNameCubit>(), same(sl<UserNameCubit>()));
  });

  // The shared flows and media widgets read the clip library from the tree,
  // never from the container.
  testWidgets('every page reads the services of the shared flows', (
    WidgetTester tester,
  ) async {
    await AppRobot.launch(tester, prefs: legacyPrefs());

    final BuildContext page = tester.element(find.byType(Navigator).first);
    expect(page.read<AppPaths>(), same(sl<AppPaths>()));
    expect(page.read<ImportFlow>(), same(sl<ImportFlow>()));
    expect(page.read<PermissionRequester>(), same(sl<PermissionRequester>()));
    expect(page.read<ClipRepository>(), same(sl<ClipRepository>()));
    expect(page.read<ClipStore>(), same(sl<ClipStore>()));
    expect(page.read<ClipSubtitles>(), same(sl<ClipSubtitles>()));
    expect(page.read<ThumbnailRepository>(), same(sl<ThumbnailRepository>()));
  });

  // The profile sheets open from any page: each reads its form's factory from
  // the tree, never from the container.
  testWidgets("every page reads the profile sheets' form factory", (
    WidgetTester tester,
  ) async {
    await AppRobot.launch(tester, prefs: legacyPrefs());

    final BuildContext page = tester.element(find.byType(Navigator).first);
    expect(page.read<ProfileFormFactory>(), same(sl<ProfileFormFactory>()));
  });

  // The movie job goes on outside the Create movie flow (Journey offers it):
  // one for the app, provided at the root.
  testWidgets('every page reads the app\'s movie job', (
    WidgetTester tester,
  ) async {
    await AppRobot.launch(tester, prefs: legacyPrefs());

    final BuildContext page = tester.element(find.byType(Navigator).first);
    expect(page.read<MovieJobBloc>(), same(sl<MovieJobBloc>()));
  });

  testWidgets('the theme switch changes the whole app at once', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    app.expectBrightness(Brightness.dark);

    await app.settings.setDarkMode(false);

    app.expectBrightness(Brightness.light);
  });
}
