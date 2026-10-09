import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';

/// Whether the last change of a preference was stored.
///
/// Every change starts with [saving], so each refusal is a new transition to
/// [saveFailed] that a `BlocListener` sees, however many come in a row.
enum PreferencesStatus {
  /// The page shows what is stored.
  ready,

  /// A change is being stored.
  saving,

  /// The phone refused to store a change; the switch shows the stored value
  /// again.
  saveFailed,
}

/// The eight preferences as stored, what this phone allows, and what the
/// Originals folder holds.
final class PreferencesState extends Equatable {
  PreferencesState({
    required Map<AppPreference, bool> stored,
    this.nativeCameraRequired = false,
    this.status = PreferencesStatus.ready,
    this.originals,
    this.perRecordingBytes,
    this.deletingOriginals = false,
  }) : stored = Map<AppPreference, bool>.unmodifiable(stored);

  /// Each switch's stored value.
  final Map<AppPreference, bool> stored;

  /// Android below 10 always records with the phone's camera app: "Force
  /// native camera" shows on and can't be changed.
  final bool nativeCameraRequired;

  final PreferencesStatus status;

  /// What the Originals folder holds ("3 videos · 850 MB"): kept
  /// recordings and processed imports' originals; null until walked, or
  /// when the app keeps none.
  final OriginalsContents? originals;

  /// The bytes the Originals folder holds; null until walked.
  int? get originalsBytes => originals?.bytes;

  /// How many originals the folder holds; null until walked.
  int? get originalsCount => originals?.count;

  /// About the bytes one recording adds at the active profile's quality
  /// ("About 12 MB per recording at your quality"); null when not known.
  final int? perRecordingBytes;

  /// "Delete originals" is running.
  final bool deletingOriginals;

  /// Whether "Delete originals" is offered: the folder holds something
  /// and nothing is deleting it.
  bool get canDeleteOriginals =>
      (originalsCount ?? 0) > 0 && !deletingOriginals;

  /// Whether the "Original videos" group shows: while "Keep original
  /// recordings" is on, or while the folder holds anything (a processed
  /// import's original is kept whatever the switch says).
  bool get showsOriginals =>
      isOn(AppPreference.keepOriginals) || (originalsCount ?? 0) > 0;

  /// Whether [preference]'s switch shows on.
  ///
  /// The date filter works only with the in-app picker, so it shows off
  /// while that is off. Below Android 10 the phone's camera app is always
  /// used, so "Force native camera" shows on.
  bool isOn(AppPreference preference) => switch (preference) {
    AppPreference.forceNativeCamera when nativeCameraRequired => true,
    AppPreference.filterByDate =>
      (stored[preference] ?? false) && isEnabled(preference),
    _ => stored[preference] ?? false,
  };

  /// Whether [preference] can be changed: the date filter only while the
  /// in-app picker is on, "Force native camera" only from Android 10 on.
  bool isEnabled(AppPreference preference) => switch (preference) {
    AppPreference.forceNativeCamera => !nativeCameraRequired,
    AppPreference.filterByDate =>
      stored[AppPreference.experimentalPicker] ?? false,
    _ => true,
  };

  PreferencesState copyWith({
    Map<AppPreference, bool>? stored,
    bool? nativeCameraRequired,
    PreferencesStatus? status,
    OriginalsContents? Function()? originals,
    int? perRecordingBytes,
    bool? deletingOriginals,
  }) => PreferencesState(
    stored: stored ?? this.stored,
    nativeCameraRequired: nativeCameraRequired ?? this.nativeCameraRequired,
    status: status ?? this.status,
    originals: originals == null ? this.originals : originals(),
    perRecordingBytes: perRecordingBytes ?? this.perRecordingBytes,
    deletingOriginals: deletingOriginals ?? this.deletingOriginals,
  );

  @override
  List<Object?> get props => <Object?>[
    stored,
    nativeCameraRequired,
    status,
    originals,
    perRecordingBytes,
    deletingOriginals,
  ];
}
