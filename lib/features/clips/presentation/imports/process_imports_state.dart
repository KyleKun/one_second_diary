import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/imported_video.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Where the processing sheet is.
enum ProcessImportsStage {
  /// Listing the foreign videos and reading their lengths.
  listing,

  /// The list and the two choices; "Process N videos" waits.
  ready,

  /// Working through the list, one by one.
  running,

  /// The run ended (through, cancelled, or refused as a batch).
  done,
}

/// One profile's line: "Work · 12 imported videos · 4 min".
final class ImportedProfileSummary extends Equatable {
  const ImportedProfileSummary({
    required this.profile,
    required this.count,
    required this.durationMs,
  });

  final ProfileKey profile;
  final int count;

  /// The summed length of the videos whose length is known.
  final int durationMs;

  @override
  List<Object?> get props => <Object?>[profile, count, durationMs];
}

/// The processing sheet's state.
final class ProcessImportsState extends Equatable {
  const ProcessImportsState({
    required this.stage,
    required this.choices,
    this.videos = const <ImportedVideo>[],
    this.done = 0,
    this.fraction = 0,
    this.report,
    this.originalsBytes = 0,
  });

  final ProcessImportsStage stage;

  /// The two remembered choices with the quick cut they are about.
  final ImportChoices choices;

  /// Every foreign video found, per profile in the app's order, with the
  /// lengths read so far.
  final List<ImportedVideo> videos;

  /// Videos finished (done or skipped) in the run.
  final int done;

  /// How much of the video in flight is rendered.
  final double fraction;

  /// What the run did; null until it ends.
  final ImportReport? report;

  /// The bytes the Originals folder holds, for "Originals: 1.2 GB".
  final int originalsBytes;

  int get total => videos.length;

  /// The per-profile lines, in the order the videos came.
  List<ImportedProfileSummary> get perProfile {
    final Map<ProfileKey, (int, int)> sums = <ProfileKey, (int, int)>{};
    for (final ImportedVideo video in videos) {
      final (int count, int ms) = sums[video.profile] ?? (0, 0);
      sums[video.profile] = (count + 1, ms + (video.durationMs ?? 0));
    }
    return <ImportedProfileSummary>[
      for (final MapEntry<ProfileKey, (int, int)> entry in sums.entries)
        ImportedProfileSummary(
          profile: entry.key,
          count: entry.value.$1,
          durationMs: entry.value.$2,
        ),
    ];
  }

  /// Σ the known lengths, for the time estimate.
  int get totalDurationMs => videos.fold(
    0,
    (int sum, ImportedVideo video) => sum + (video.durationMs ?? 0),
  );

  bool get canStart => stage == ProcessImportsStage.ready && videos.isNotEmpty;

  ProcessImportsState copyWith({
    ProcessImportsStage? stage,
    ImportChoices? choices,
    List<ImportedVideo>? videos,
    int? done,
    double? fraction,
    ImportReport? report,
    int? originalsBytes,
  }) => ProcessImportsState(
    stage: stage ?? this.stage,
    choices: choices ?? this.choices,
    videos: videos ?? this.videos,
    done: done ?? this.done,
    fraction: fraction ?? this.fraction,
    report: report ?? this.report,
    originalsBytes: originalsBytes ?? this.originalsBytes,
  );

  @override
  List<Object?> get props => <Object?>[
    stage,
    choices,
    videos,
    done,
    fraction,
    report,
    originalsBytes,
  ];
}
