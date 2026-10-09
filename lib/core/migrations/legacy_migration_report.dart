import 'package:equatable/equatable.dart';

/// The outcome of `LegacyFolderMigration`, for its closing dialog.
final class LegacyMigrationReport extends Equatable {
  const LegacyMigrationReport({
    required this.clipsMigrated,
    required this.failed,
    required this.moviesMigrated,
    required this.oldFoldersRemoved,
  });

  /// Nothing to migrate (iOS, or no old folder).
  static const LegacyMigrationReport nothingToDo = LegacyMigrationReport(
    clipsMigrated: 0,
    failed: <String>[],
    moviesMigrated: 0,
    oldFoldersRemoved: false,
  );

  final int clipsMigrated;

  /// Files left where they were, relative to the storage root (for example
  /// `OneSecondDiary/2021-01-01.mp4`), for the log and the error dialog.
  final List<String> failed;

  final int moviesMigrated;

  /// Whether the old folders are gone. False after a complete migration
  /// means they could not be deleted.
  final bool oldFoldersRemoved;

  bool get isComplete => failed.isEmpty;

  @override
  List<Object?> get props => <Object?>[
    clipsMigrated,
    failed,
    moviesMigrated,
    oldFoldersRemoved,
  ];
}
