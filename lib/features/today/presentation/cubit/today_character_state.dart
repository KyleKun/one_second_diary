import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/today/domain/today_lines.dart';

/// The character on Today: how it looks and what it is saying.
final class TodayCharacterState extends Equatable {
  const TodayCharacterState({required this.look, this.line, this.lineId = 0});

  final CharacterLook look;

  /// The line in its bubble; null when it is quiet.
  final TodayLine? line;

  /// Bumped with every line, so the same line twice shows twice.
  final int lineId;

  /// The line is about the record button under it: the eyes go down.
  bool get lookingDown => line?.looksDown ?? false;

  TodayCharacterState withLine(TodayLine? line) =>
      TodayCharacterState(look: look, line: line, lineId: lineId + 1);

  TodayCharacterState withLook(CharacterLook look) =>
      TodayCharacterState(look: look, line: line, lineId: lineId);

  @override
  List<Object?> get props => <Object?>[look, line, lineId];
}
