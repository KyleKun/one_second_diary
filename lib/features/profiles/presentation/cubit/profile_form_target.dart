import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// What a profile form edits: a profile being created or an existing one.
sealed class ProfileFormTarget extends Equatable {
  const ProfileFormTarget();

  @override
  List<Object?> get props => const <Object?>[];
}

final class NewProfileForm extends ProfileFormTarget {
  const NewProfileForm();
}

final class EditProfileForm extends ProfileFormTarget {
  const EditProfileForm(this.profile);

  final ProfileKey profile;

  @override
  List<Object?> get props => <Object?>[profile];
}
