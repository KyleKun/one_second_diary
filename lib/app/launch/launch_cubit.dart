import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';

/// Runs the post-frame launch once and exposes where it is: app-scoped,
/// provided at the root so the folder migration dialog can follow it.
///
/// The app root builds this cubit in the first frame, so it holds only a
/// way to get the launch: [start] builds `PostFrameLaunch` (and every
/// service and platform plugin behind it) after that frame.
class LaunchCubit extends Cubit<LaunchState> {
  LaunchCubit({required this._launch}) : super(const LaunchState());

  final PostFrameLaunch Function() _launch;

  /// The launch in flight or done: [start] runs it once.
  Future<void>? _started;

  /// Builds and runs the post-frame launch (`LaunchStarter` calls this
  /// after the first frame that shows the app). Calling it again returns
  /// the same run.
  Future<void> start() => _started ??= _run();

  Future<void> _run() async {
    await _launch().run(
      onMigrationEvent: _migrationChanged,
      onMigrationFailed: () => emit(
        state.copyWith(status: LaunchStatus.launching, migrationFailed: true),
      ),
    );
    emit(state.copyWith(status: LaunchStatus.ready));
  }

  void _migrationChanged(LegacyMigrationEvent event) => emit(switch (event) {
    LegacyMigrationProgress(:final int done, :final int total) =>
      state.copyWith(
        status: LaunchStatus.migrating,
        migrationDone: done,
        migrationTotal: total,
      ),
    LegacyMigrationFinished(:final report) => state.copyWith(
      status: LaunchStatus.launching,
      migrationReport: report,
    ),
  });
}
