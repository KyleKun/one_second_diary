import 'package:equatable/equatable.dart';

/// Whether the last theme change was stored.
///
/// Every change starts with [saving], so each refusal is a new transition
/// to [saveFailed] that a `BlocListener` sees, however many come in a row.
enum ThemeStatus {
  /// The app shows [ThemeState.darkMode].
  ready,

  /// A change is being stored.
  saving,

  /// The phone refused to store a change; the theme did not change.
  saveFailed,
}

/// The app theme: dark or light (`isDarkMode`).
final class ThemeState extends Equatable {
  const ThemeState({
    required this.darkMode,
    this.status = ThemeStatus.ready,
    this.revealed = false,
  });

  /// Dark or light; the app never follows the phone's theme after the
  /// first launch. `OsdMaterialApp` turns it into the theme mode.
  final bool darkMode;
  final ThemeStatus status;

  /// Whether the last change shows through the reveal (`ThemeReveal`): the
  /// app then changes its theme at once, with no crossfade under the
  /// picture.
  final bool revealed;

  ThemeState copyWith({bool? darkMode, ThemeStatus? status}) => ThemeState(
    darkMode: darkMode ?? this.darkMode,
    status: status ?? this.status,
    revealed: revealed,
  );

  @override
  List<Object?> get props => <Object?>[darkMode, status, revealed];
}
