import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A profile joined or left the list, for the owners of per-profile data
/// (the clip index builds or drops that profile's index).
sealed class ProfileChange extends Equatable {
  const ProfileChange(this.key);

  final ProfileKey key;

  @override
  List<Object?> get props => <Object?>[key];
}

/// [key] was created, or a folder found on the phone was added back.
final class ProfileAdded extends ProfileChange {
  const ProfileAdded(super.key);
}

/// [key] was deleted.
final class ProfileRemoved extends ProfileChange {
  const ProfileRemoved(super.key);
}
