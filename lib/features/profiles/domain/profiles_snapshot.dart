import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';

/// Every profile, in list order (Default first), and the active one.
final class ProfilesSnapshot extends Equatable {
  const ProfilesSnapshot({required this.profiles, required this.active});

  final List<Profile> profiles;

  /// The profile new clips are recorded into.
  final Profile active;

  @override
  List<Object?> get props => <Object?>[profiles, active];
}
