import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/legacy_migration_dialog.dart';
import 'package:one_second_diary/app/launch/legacy_migration_listener.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/app/osd_material_app.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/shared/widgets/chrome/dialog_icon_badge.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// A post-frame launch whose migration events the test sends.
class _ScriptedLaunch extends Fake implements PostFrameLaunch {
  late void Function(LegacyMigrationEvent event) send;
  late void Function() fail;
  final Completer<void> done = Completer<void>();

  @override
  Future<void> run({
    required void Function(LegacyMigrationEvent event) onMigrationEvent,
    required void Function() onMigrationFailed,
  }) {
    send = onMigrationEvent;
    fail = onMigrationFailed;
    return done.future;
  }
}

LegacyMigrationReport report({
  List<String> failed = const <String>[],
  bool oldFoldersRemoved = true,
}) => LegacyMigrationReport(
  clipsMigrated: 3 - failed.length,
  failed: failed,
  moviesMigrated: 0,
  oldFoldersRemoved: oldFoldersRemoved,
);

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  tearDown(rootBundle.clear);

  late _ScriptedLaunch launch;

  /// Mounts the app with the listener, then starts the launch. With
  /// [before], the launch starts first and sends those events before the
  /// app's first frame, as on a device where the launch outruns the
  /// translations the first frame waits for.
  Future<void> pump(
    WidgetTester tester, {
    bool darkMode = true,
    List<LegacyMigrationEvent>? before,
  }) async {
    launch = _ScriptedLaunch();
    final LaunchCubit cubit = LaunchCubit(launch: () => launch);
    addTearDown(cubit.close);
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(),
        ),
      ],
    );
    addTearDown(router.dispose);
    if (before != null) {
      unawaited(cubit.start());
      before.forEach(launch.send);
    }
    await tester.pumpWidget(
      BlocProvider<LaunchCubit>.value(
        value: cubit,
        child: OsdLocalizationRoot(
          language: AppLanguage.en,
          child: OsdMaterialApp(
            darkMode: darkMode,
            routerConfig: router,
            builder: (BuildContext context, Widget? child) =>
                LegacyMigrationListener(
                  navigatorKey: router.routerDelegate.navigatorKey,
                  child: child!,
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (before != null) return;
    unawaited(cubit.start());
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, LegacyMigrationEvent event) async {
    launch.send(event);
    await tester.pumpAndSettle();
  }

  double progress(WidgetTester tester) => tester
      .widget<OsdProgressBar>(find.byKey(LegacyMigrationDialog.progressKey))
      .value;

  testWidgets('shows the move as it happens, then its outcome, until OK', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    await send(tester, const LegacyMigrationProgress(done: 0, total: 3));
    expect(
      find.text(
        'Migrating all your videos to the new app folder, please wait...',
      ),
      findsOneWidget,
    );
    expect(find.text('Keep the app open'), findsOneWidget);
    expect(progress(tester), 0);

    // Neither back nor the scrim closes it while files move.
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    await send(tester, const LegacyMigrationProgress(done: 2, total: 3));
    expect(progress(tester), closeTo(2 / 3, 1e-9));

    await send(tester, LegacyMigrationFinished(report()));
    expect(find.text('Success'), findsOneWidget);
    expect(
      find.textContaining('All videos and movies are now saved inside'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(LegacyMigrationDialog.okKey));
    await tester.pumpAndSettle();
    expect(find.byType(LegacyMigrationDialog), findsNothing);
  });

  // The token rules: GREEN on theme surfaces is for dark ones; glyphs on a
  // light sheet take GREEN_INK.
  for (final bool darkMode in <bool>[false, true]) {
    testWidgets('the success badge is GREEN_INK (dark mode $darkMode)', (
      WidgetTester tester,
    ) async {
      await pump(tester, darkMode: darkMode);

      await send(tester, const LegacyMigrationProgress(done: 0, total: 3));
      await send(tester, LegacyMigrationFinished(report()));

      final BuildContext dialog = tester.element(
        find.byType(LegacyMigrationDialog),
      );
      expect(
        tester
            .widget<OsdIcon>(
              find.descendant(
                of: find.byType(DialogIconBadge),
                matching: find.byType(OsdIcon),
              ),
            )
            .color,
        dialog.colors.greenInk,
      );
    });
  }

  // Nothing to press while files move, so no empty action row either.
  testWidgets('the progress bar ends 18 above the bottom of the dialog', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    await send(tester, const LegacyMigrationProgress(done: 1, total: 3));

    expect(
      tester.getRect(find.byKey(OsdDialog.surfaceKey)).bottom -
          tester.getRect(find.byKey(LegacyMigrationDialog.progressKey)).bottom,
      18,
    );
  });

  // The listener sees only what changes after it is mounted; files may
  // already be moving by then.
  testWidgets('a move that began before the app showed still shows, then '
      'its outcome', (WidgetTester tester) async {
    await pump(
      tester,
      before: const <LegacyMigrationEvent>[
        LegacyMigrationProgress(done: 1, total: 3),
      ],
    );

    expect(find.byType(LegacyMigrationDialog), findsOneWidget);
    expect(progress(tester), closeTo(1 / 3, 1e-9));

    await send(tester, LegacyMigrationFinished(report()));
    expect(find.text('Success'), findsOneWidget);
    await tester.tap(find.byKey(LegacyMigrationDialog.okKey));
    await tester.pumpAndSettle();
    expect(find.byType(LegacyMigrationDialog), findsNothing);
  });

  testWidgets('an outcome that came before the app showed is shown once', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      before: <LegacyMigrationEvent>[
        const LegacyMigrationProgress(done: 3, total: 3),
        LegacyMigrationFinished(report()),
      ],
    );

    expect(find.text('Success'), findsOneWidget);
    expect(find.byType(LegacyMigrationDialog), findsOneWidget);
  });

  testWidgets('says when some files could not be moved', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    await send(tester, const LegacyMigrationProgress(done: 0, total: 3));
    await send(
      tester,
      LegacyMigrationFinished(
        report(failed: <String>['OneSecondDiary/2021-01-01.mp4']),
      ),
    );

    expect(find.text('Error'), findsOneWidget);
    expect(
      find.textContaining('An error occurred while migrating your videos'),
      findsOneWidget,
    );
  });

  testWidgets('says when the old folders stayed behind', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    await send(tester, const LegacyMigrationProgress(done: 0, total: 3));
    await send(
      tester,
      LegacyMigrationFinished(report(oldFoldersRemoved: false)),
    );

    expect(
      find.textContaining('error occurred while deleting the old folders'),
      findsOneWidget,
    );
  });

  testWidgets('a migration that fails at once shows the error', (
    WidgetTester tester,
  ) async {
    await pump(tester);

    launch.fail();
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('nothing to move, no dialog', (WidgetTester tester) async {
    await pump(tester);

    launch.done.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LegacyMigrationDialog), findsNothing);
  });
}
