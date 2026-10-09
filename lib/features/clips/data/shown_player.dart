import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';

/// The player on screen and the file it plays.
final class ShownPlayer extends Equatable {
  const ShownPlayer({required this.path, required this.handle});

  /// Absolute path of the file.
  final String path;

  final PlayerHandle handle;

  @override
  List<Object?> get props => <Object?>[path, handle];
}
