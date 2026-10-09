import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';

/// Which part of onboarding shows.
enum OnboardingStep {
  /// The intro carousel.
  intro,

  /// The Default profile's orientation and the optional name.
  orientation,

  /// The permissions step: "Allow" per permission, then "Continue".
  permissions,

  /// The phone check: the tests, the recommended quality, "Use
  /// this" / "Choose another" / "Skip", which finish the diary.
  phoneCheck,
}

/// Where onboarding stands.
enum OnboardingStatus {
  /// The user is reading the intro, choosing an orientation or allowing
  /// permissions.
  choosing,

  /// The finish is at work ("Use this", "Choose another" or "Skip" on the
  /// phone check): asking for the gallery when its row was not tapped,
  /// then making the diary. Choices are frozen.
  finishing,

  /// The phone refused access to the gallery (Android): nothing is made
  /// yet, and [OnboardingState.access] says whether asking again can help.
  accessRefused,

  /// The phone refused a write: onboarding is not complete, and trying
  /// again is safe (every write is idempotent, `showIntro` comes last).
  failed,

  /// The diary is made: Today opens.
  done,
}

/// Where one row of the permissions step stands.
enum PermissionRowStatus {
  /// Not granted, and the prompt can show: "Allow". A check cannot tell a
  /// permission never asked from one refused once, so a refusal only shows
  /// after a tap on this step.
  notAsked,

  /// The system prompt is up (or the plugin is answering).
  requesting,

  /// Granted: "Allowed".
  granted,

  /// Refused on this step; the prompt can still show: "Allow" again, with
  /// "Not allowed yet" under the row.
  denied,

  /// Permanently denied or restricted: only the system Settings page can
  /// grant it, "Open settings".
  blocked;

  static PermissionRowStatus of(AccessOutcome outcome) => switch (outcome) {
    AccessOutcome.granted => granted,
    AccessOutcome.denied => denied,
    AccessOutcome.blocked => blocked,
  };
}

/// The onboarding flow: the step, the user's choices, the permissions
/// step's rows and the finish.
final class OnboardingState extends Equatable {
  const OnboardingState({
    required this.today,
    this.step = OnboardingStep.intro,
    this.orientation,
    this.name = '',
    this.status = OnboardingStatus.choosing,
    this.access,
    this.permissions = const <OnboardingPermission, PermissionRowStatus>{},
  });

  /// The day onboarding opened: the intro's polaroids are dated back from it.
  final LocalDay today;

  final OnboardingStep step;

  /// The Default profile's orientation; null until the user taps one,
  /// since nothing is preselected.
  final VideoOrientation? orientation;

  /// What the user typed in the optional name field, as typed: it is
  /// trimmed when stored.
  final String name;

  final OnboardingStatus status;

  /// The answer to the gallery request, while [status] is
  /// [OnboardingStatus.accessRefused]: `denied` (the prompt can show again)
  /// or `blocked` (only the system Settings can grant it).
  final AccessOutcome? access;

  /// The rows of the permissions step and where each stands, in the order
  /// they show. Empty until the step opens; a row this phone does not show
  /// is absent.
  final Map<OnboardingPermission, PermissionRowStatus> permissions;

  /// The rows the permissions step shows, in order.
  List<OnboardingPermission> get shownRows =>
      List<OnboardingPermission>.unmodifiable(permissions.keys);

  /// How many rows are allowed.
  int get grantedCount => permissions.values
      .where(
        (PermissionRowStatus status) => status == PermissionRowStatus.granted,
      )
      .length;

  /// Whether every row is allowed.
  bool get allGranted =>
      permissions.isNotEmpty && grantedCount == permissions.length;

  /// Whether the finish is at work or done: taps and choices are ignored.
  bool get isBusy =>
      status == OnboardingStatus.finishing || status == OnboardingStatus.done;

  /// A copy with the given changes. [access] lives only as long as the
  /// refusal: it is kept while [status] stays
  /// [OnboardingStatus.accessRefused], and dropped with any other status.
  OnboardingState copyWith({
    OnboardingStep? step,
    VideoOrientation? orientation,
    String? name,
    OnboardingStatus? status,
    AccessOutcome? access,
    Map<OnboardingPermission, PermissionRowStatus>? permissions,
  }) {
    final OnboardingStatus next = status ?? this.status;
    return OnboardingState(
      today: today,
      step: step ?? this.step,
      orientation: orientation ?? this.orientation,
      name: name ?? this.name,
      status: next,
      access: next == OnboardingStatus.accessRefused
          ? access ?? this.access
          : null,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    today,
    step,
    orientation,
    name,
    status,
    access,
    permissions,
  ];
}
