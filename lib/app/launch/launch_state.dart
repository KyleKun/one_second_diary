import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_report.dart';

/// Where the post-frame launch is.
enum LaunchStatus {
  /// Launch steps are running; the app is usable.
  launching,

  /// The pre-2023 Android folder migration is moving files: its
  /// non-dismissable progress dialog shows.
  migrating,

  /// Every launch step ran.
  ready,
}

/// The post-frame launch, for the app root: the folder migration dialog
/// (progress, then its outcome) listens to it.
final class LaunchState extends Equatable {
  const LaunchState({
    this.status = LaunchStatus.launching,
    this.migrationDone = 0,
    this.migrationTotal = 0,
    this.migrationReport,
    this.migrationFailed = false,
  });

  final LaunchStatus status;

  /// Files the migration handled so far, of [migrationTotal].
  final int migrationDone;
  final int migrationTotal;

  /// What the migration did, once it finished; null when none ran.
  final LegacyMigrationReport? migrationReport;

  /// The migration ended with an error (an old folder could not be read,
  /// or a preference could not be written).
  final bool migrationFailed;

  /// Whether the folder migration dialog shows: while files move, and
  /// once it ended (with a report or an error).
  bool get showsMigration =>
      status == LaunchStatus.migrating ||
      migrationReport != null ||
      migrationFailed;

  LaunchState copyWith({
    LaunchStatus? status,
    int? migrationDone,
    int? migrationTotal,
    LegacyMigrationReport? migrationReport,
    bool? migrationFailed,
  }) => LaunchState(
    status: status ?? this.status,
    migrationDone: migrationDone ?? this.migrationDone,
    migrationTotal: migrationTotal ?? this.migrationTotal,
    migrationReport: migrationReport ?? this.migrationReport,
    migrationFailed: migrationFailed ?? this.migrationFailed,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    migrationDone,
    migrationTotal,
    migrationReport,
    migrationFailed,
  ];
}
