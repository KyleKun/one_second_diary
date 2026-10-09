import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';

/// A launch that reports [events] and then, when [fails], a failed
/// migration.
class _ScriptedLaunch extends Fake implements PostFrameLaunch {
  _ScriptedLaunch({
    this.events = const <LegacyMigrationEvent>[],
    this.fails = false,
  });

  final List<LegacyMigrationEvent> events;
  final bool fails;

  @override
  Future<void> run({
    required void Function(LegacyMigrationEvent event) onMigrationEvent,
    required void Function() onMigrationFailed,
  }) async {
    events.forEach(onMigrationEvent);
    if (fails) onMigrationFailed();
  }
}

const LegacyMigrationReport report = LegacyMigrationReport(
  clipsMigrated: 2,
  failed: <String>[],
  moviesMigrated: 0,
  oldFoldersRemoved: true,
);

void main() {
  test('starts in the launching state', () {
    expect(
      LaunchCubit(launch: () => _ScriptedLaunch()).state,
      const LaunchState(),
    );
  });

  blocTest<LaunchCubit, LaunchState>(
    'is ready once the launch has run',
    build: () => LaunchCubit(launch: () => _ScriptedLaunch()),
    act: (LaunchCubit cubit) => cubit.start(),
    expect: () => <LaunchState>[const LaunchState(status: LaunchStatus.ready)],
  );

  blocTest<LaunchCubit, LaunchState>(
    'follows the legacy folder migration for its dialog',
    build: () => LaunchCubit(
      launch: () => _ScriptedLaunch(
        events: const <LegacyMigrationEvent>[
          LegacyMigrationProgress(done: 0, total: 2),
          LegacyMigrationProgress(done: 1, total: 2),
          LegacyMigrationProgress(done: 2, total: 2),
          LegacyMigrationFinished(report),
        ],
      ),
    ),
    act: (LaunchCubit cubit) => cubit.start(),
    expect: () => <LaunchState>[
      const LaunchState(
        status: LaunchStatus.migrating,
        migrationDone: 0,
        migrationTotal: 2,
      ),
      const LaunchState(
        status: LaunchStatus.migrating,
        migrationDone: 1,
        migrationTotal: 2,
      ),
      const LaunchState(
        status: LaunchStatus.migrating,
        migrationDone: 2,
        migrationTotal: 2,
      ),
      const LaunchState(
        migrationDone: 2,
        migrationTotal: 2,
        migrationReport: report,
      ),
      const LaunchState(
        status: LaunchStatus.ready,
        migrationDone: 2,
        migrationTotal: 2,
        migrationReport: report,
      ),
    ],
  );

  blocTest<LaunchCubit, LaunchState>(
    'says when the migration failed',
    build: () => LaunchCubit(
      launch: () => _ScriptedLaunch(
        events: const <LegacyMigrationEvent>[
          LegacyMigrationProgress(done: 0, total: 3),
        ],
        fails: true,
      ),
    ),
    act: (LaunchCubit cubit) => cubit.start(),
    expect: () => <LaunchState>[
      const LaunchState(status: LaunchStatus.migrating, migrationTotal: 3),
      const LaunchState(migrationTotal: 3, migrationFailed: true),
      const LaunchState(
        status: LaunchStatus.ready,
        migrationTotal: 3,
        migrationFailed: true,
      ),
    ],
  );

  // The root builds this cubit in the first frame; the launch and its
  // services wait for start().
  test('builds the launch only when it starts', () async {
    int built = 0;
    final LaunchCubit cubit = LaunchCubit(
      launch: () {
        built++;
        return _ScriptedLaunch();
      },
    );
    addTearDown(cubit.close);
    expect(built, 0);

    await cubit.start();
    await cubit.start();

    expect(built, 1);
  });

  // A second run would move the old folders again and show the dialog twice.
  blocTest<LaunchCubit, LaunchState>(
    'runs the launch once however often it is started',
    build: () => LaunchCubit(
      launch: () => _ScriptedLaunch(
        events: const <LegacyMigrationEvent>[
          LegacyMigrationProgress(done: 0, total: 1),
          LegacyMigrationFinished(report),
        ],
      ),
    ),
    act: (LaunchCubit cubit) async {
      await Future.wait(<Future<void>>[cubit.start(), cubit.start()]);
      await cubit.start();
    },
    expect: () => <LaunchState>[
      const LaunchState(status: LaunchStatus.migrating, migrationTotal: 1),
      const LaunchState(migrationTotal: 1, migrationReport: report),
      const LaunchState(
        status: LaunchStatus.ready,
        migrationTotal: 1,
        migrationReport: report,
      ),
    ],
  );
}
