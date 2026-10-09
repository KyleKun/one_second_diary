import 'package:equatable/equatable.dart';

/// What deleting a profile left on the phone: on Android the clips a
/// previous install made need the user's consent, so they stay in the
/// gallery.
final class ProfileDeletion extends Equatable {
  const ProfileDeletion({required this.keptFiles});

  /// Files that could not be deleted, relative to `AppPaths.videos`.
  final List<String> keptFiles;

  /// Whether every file of the profile was deleted.
  bool get isComplete => keptFiles.isEmpty;

  @override
  List<Object?> get props => <Object?>[keptFiles];
}
