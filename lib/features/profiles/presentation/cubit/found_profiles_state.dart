import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Where the offer of found folders stands.
///
/// Every "Add back" starts with [adding], so each refusal is a new
/// transition to [addFailed] that a `BlocListener` sees.
enum FoundProfilesStatus {
  /// The folders are being read.
  loading,

  /// [FoundProfilesState.folders] is what the phone holds.
  ready,

  /// A folder is being listed as a profile again.
  adding,

  /// The phone refused to store it; the offer stays.
  addFailed,
}

/// The folders under `Profiles/` that hold clips but that no profile lists,
/// sorted.
final class FoundProfilesState extends Equatable {
  FoundProfilesState({
    List<ProfileKey> folders = const <ProfileKey>[],
    this.status = FoundProfilesStatus.loading,
  }) : folders = List<ProfileKey>.unmodifiable(folders);

  final List<ProfileKey> folders;

  final FoundProfilesStatus status;

  FoundProfilesState copyWith({
    List<ProfileKey>? folders,
    FoundProfilesStatus? status,
  }) => FoundProfilesState(
    folders: folders ?? this.folders,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => <Object?>[folders, status];
}
