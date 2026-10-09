import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/onboarding/domain/phone_check_progress.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';

/// Where the phone check stands.
enum PhoneCheckStatus {
  /// Not started (Settings shows the last result meanwhile).
  idle,

  /// The tests run; [PhoneCheckState.progress] names the one in flight.
  running,

  /// Every test ran: [PhoneCheckState.profile] and the recommendation.
  done,

  /// The check did not finish (the engine failed): Standard is selected.
  failed,

  /// "Skip": Standard is selected and the check finishes in the
  /// background for the next profile.
  skipped,
}

/// The phone check: its progress, its result, the recommendation and the
/// format the user selected from it.
final class PhoneCheckState extends Equatable {
  const PhoneCheckState({
    this.status = PhoneCheckStatus.idle,
    this.progress,
    this.profile,
    this.stale = false,
    this.recommendation,
    this.selected,
  });

  final PhoneCheckStatus status;

  /// The test in flight while [PhoneCheckStatus.running].
  final PhoneCheckProgress? progress;

  /// The result shown: this run's, or the stored one before a run.
  final DeviceMediaProfile? profile;

  /// Whether [profile] was made by another phone or app version.
  final bool stale;

  /// The advice from [profile] (Standard when none or stale).
  final QualityRecommendation? recommendation;

  /// The format the result card shows selected: the pick, or what the
  /// user chose with "Choose another".
  final ClipFormat? selected;

  bool get isRunning => status == PhoneCheckStatus.running;

  /// Whether a result card shows.
  bool get hasResult => recommendation != null && !isRunning;

  PhoneCheckState copyWith({
    PhoneCheckStatus? status,
    PhoneCheckProgress? Function()? progress,
    DeviceMediaProfile? Function()? profile,
    bool? stale,
    QualityRecommendation? Function()? recommendation,
    ClipFormat? Function()? selected,
  }) => PhoneCheckState(
    status: status ?? this.status,
    progress: progress == null ? this.progress : progress(),
    profile: profile == null ? this.profile : profile(),
    stale: stale ?? this.stale,
    recommendation: recommendation == null
        ? this.recommendation
        : recommendation(),
    selected: selected == null ? this.selected : selected(),
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    progress,
    profile,
    stale,
    recommendation,
    selected,
  ];
}
