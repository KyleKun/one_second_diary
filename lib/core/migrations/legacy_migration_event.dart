import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';

/// What `LegacyFolderMigration` tells its dialog.
sealed class LegacyMigrationEvent extends Equatable {
  const LegacyMigrationEvent();
}

/// [done] of [total] files handled so far (moved or kept), starting at 0.
final class LegacyMigrationProgress extends LegacyMigrationEvent {
  const LegacyMigrationProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  List<Object?> get props => <Object?>[done, total];
}

/// The migration ended; always the last event.
final class LegacyMigrationFinished extends LegacyMigrationEvent {
  const LegacyMigrationFinished(this.report);

  final LegacyMigrationReport report;

  @override
  List<Object?> get props => <Object?>[report];
}
