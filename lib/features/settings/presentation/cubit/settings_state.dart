import 'package:equatable/equatable.dart';

/// The Settings tab's own state: the app version the About row shows.
final class SettingsState extends Equatable {
  const SettingsState({this.version});

  /// The installed version ("2.0.0"); null until it has been read.
  final String? version;

  @override
  List<Object?> get props => <Object?>[version];
}
