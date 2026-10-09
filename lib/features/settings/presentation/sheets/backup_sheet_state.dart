import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/settings/domain/backup_steps.dart';

/// Where the Backup & restore sheet is.
enum BackupSheetStage {
  /// "What do you want to do?"
  choice,

  /// The numbered steps of [BackupSheetState.mode].
  steps,

  /// "Look for new videos" is scanning.
  scanning,

  /// The scan answered ([BackupSheetState.found]).
  scanned,
}

/// What "Look for new videos" found across every profile.
final class BackupScanFound extends Equatable {
  const BackupScanFound({required this.newClips, required this.foreignFiles});

  static const BackupScanFound nothing = BackupScanFound(
    newClips: 0,
    foreignFiles: 0,
  );

  /// Clips that were not in the library before.
  final int newClips;

  /// Date-named videos with another extension found beside the clips
  /// (`ClipScan.foreignFiles`), which the processing sheet offers.
  final int foreignFiles;

  int get total => newClips + foreignFiles;

  @override
  List<Object?> get props => <Object?>[newClips, foreignFiles];
}

final class BackupSheetState extends Equatable {
  const BackupSheetState({
    required this.platform,
    this.stage = BackupSheetStage.choice,
    this.mode,
    this.found,
    this.openInFilesFailed = false,
    this.originalsBytes = 0,
  });

  final BackupPlatform platform;
  final BackupSheetStage stage;

  /// The mode chosen; null on the choice.
  final BackupMode? mode;

  /// The last scan's answer; null until one ran.
  final BackupScanFound? found;

  /// "Open in Files" was refused: the row says how to get there by hand.
  final bool openInFilesFailed;

  /// The Originals folder's size, for the import steps' note.
  final int originalsBytes;

  /// The steps of [mode]; empty on the choice.
  List<BackupStep> get steps => switch (mode) {
    null => const <BackupStep>[],
    final BackupMode mode => BackupSteps.of(platform: platform, mode: mode),
  };

  bool get showsVideoLink => switch (mode) {
    null => false,
    final BackupMode mode => BackupSteps.showsVideoLink(
      platform: platform,
      mode: mode,
    ),
  };

  BackupSheetState copyWith({
    BackupSheetStage? stage,
    BackupMode? mode,
    bool clearMode = false,
    BackupScanFound? found,
    bool? openInFilesFailed,
    int? originalsBytes,
  }) => BackupSheetState(
    platform: platform,
    stage: stage ?? this.stage,
    mode: clearMode ? null : mode ?? this.mode,
    found: found ?? this.found,
    openInFilesFailed: openInFilesFailed ?? this.openInFilesFailed,
    originalsBytes: originalsBytes ?? this.originalsBytes,
  );

  @override
  List<Object?> get props => <Object?>[
    platform,
    stage,
    mode,
    found,
    openInFilesFailed,
    originalsBytes,
  ];
}
