import 'package:equatable/equatable.dart';

/// Whether the last name change was stored.
///
/// Every change starts with [saving], so each refusal is a new transition
/// to [saveFailed] that a `BlocListener` sees, however many come in a row.
enum UserNameStatus {
  /// The app shows [UserNameState.name].
  ready,

  /// A change is being stored.
  saving,

  /// The phone refused to store a change; the name did not change.
  saveFailed,
}

/// The user's optional name.
final class UserNameState extends Equatable {
  const UserNameState({required this.name, this.status = UserNameStatus.ready});

  /// Trimmed; `''` when the user gave none.
  final String name;
  final UserNameStatus status;

  UserNameState copyWith({String? name, UserNameStatus? status}) =>
      UserNameState(name: name ?? this.name, status: status ?? this.status);

  @override
  List<Object?> get props => <Object?>[name, status];
}
