import 'dart:math' as math;

import 'package:one_second_diary/features/today/domain/part_of_day.dart';

/// Everything the character can say on Today, by key. The page turns a
/// line into text in the app's language; the greetings take the user's
/// name when there is one.
///
/// Tagged per line, not found by a word, so every language behaves the
/// same: [looksDown] marks the lines about the record button under it.
enum TodayLine {
  helloAnyTime1,
  helloAnyTime2,
  helloAnyTime3,
  helloAnyTime4,
  goodMorning,
  goodAfternoon,
  goodEvening,
  stillUp,
  welcomeBack,
  waiting1,
  waiting2,
  waiting3,
  waiting4,
  waiting5,
  waiting6,
  waiting7,
  waiting8,
  waiting9,
  justSaved1,
  justSaved2,
  justSaved3,
  justSaved4,
  manySeconds,
  firstClipEver,
  milestone7,
  milestone30,
  milestone100,
  milestone365,
  keptOne1,
  keptOne2,
  keptOne3,
  keptOne4,
  keptOne5,
  keptOne6,
  keptSeveral1,
  keptSeveral2,
  keptSeveral3,
  keptSeveral4,
  deletedEmpty1,
  deletedEmpty2,
  deletedEmpty3,
  deletedEmpty4,
  deletedKept1,
  deletedKept2,
  deletedKept3,
  poke1,
  poke2,
  poke3,
  poke4,
  poke5,
  pokeWaiting1,
  pokeWaiting2,
  customized1,
  customized2,
  profileSwitched1,
  profileSwitched2,
  profileSwitched3;

  /// Said looking down at the record button.
  bool get looksDown => this == pokeWaiting1 || this == pokeWaiting2;
}

/// The pools the lines come from, and the rules that pick among them.
abstract final class TodayLinePools {
  /// Idle lines a visit can hear before the character goes quiet.
  static const int idlePerVisit = 3;

  /// Arriving on Today: half the time one of these, else the one for the
  /// part of the day ([partOfDay]).
  static const List<TodayLine> anyTime = <TodayLine>[
    TodayLine.helloAnyTime1,
    TodayLine.helloAnyTime2,
    TodayLine.helloAnyTime3,
    TodayLine.helloAnyTime4,
  ];

  static TodayLine partOfDay(PartOfDay part) => switch (part) {
    PartOfDay.morning => TodayLine.goodMorning,
    PartOfDay.afternoon => TodayLine.goodAfternoon,
    PartOfDay.evening => TodayLine.goodEvening,
    PartOfDay.lateNight => TodayLine.stillUp,
  };

  /// Idle while the day has no clip yet.
  static const List<TodayLine> waiting = <TodayLine>[
    TodayLine.waiting1,
    TodayLine.waiting2,
    TodayLine.waiting3,
    TodayLine.waiting4,
    TodayLine.waiting5,
    TodayLine.waiting6,
    TodayLine.waiting7,
    TodayLine.waiting8,
    TodayLine.waiting9,
  ];

  /// Said once, with the hop, on coming back to Today after saving the
  /// day's first clip.
  static const List<TodayLine> justSaved = <TodayLine>[
    TodayLine.justSaved1,
    TodayLine.justSaved2,
    TodayLine.justSaved3,
    TodayLine.justSaved4,
  ];

  /// Idle once the day has one clip.
  static const List<TodayLine> keptOne = <TodayLine>[
    TodayLine.keptOne1,
    TodayLine.keptOne2,
    TodayLine.keptOne3,
    TodayLine.keptOne4,
    TodayLine.keptOne5,
    TodayLine.keptOne6,
  ];

  /// Idle once the day has two clips or more.
  static const List<TodayLine> keptSeveral = <TodayLine>[
    TodayLine.keptSeveral1,
    TodayLine.keptSeveral2,
    TodayLine.keptSeveral3,
    TodayLine.keptSeveral4,
  ];

  /// A clip of the day went away (deleted, or its save undone) and the
  /// day has none left.
  static const List<TodayLine> deletedEmpty = <TodayLine>[
    TodayLine.deletedEmpty1,
    TodayLine.deletedEmpty2,
    TodayLine.deletedEmpty3,
    TodayLine.deletedEmpty4,
  ];

  /// A clip of the day went away and the day still has others.
  static const List<TodayLine> deletedKept = <TodayLine>[
    TodayLine.deletedKept1,
    TodayLine.deletedKept2,
    TodayLine.deletedKept3,
  ];

  /// The pool for a clip gone, by how many the day has left.
  static List<TodayLine> deleted(int clipCount) =>
      clipCount == 0 ? deletedEmpty : deletedKept;

  /// A tap on the character.
  static const List<TodayLine> poke = <TodayLine>[
    TodayLine.poke1,
    TodayLine.poke2,
    TodayLine.poke3,
    TodayLine.poke4,
    TodayLine.poke5,
  ];

  /// A tap on the character while the day has no clip: half the time one
  /// of these instead of [poke].
  static const List<TodayLine> pokeWaiting = <TodayLine>[
    TodayLine.pokeWaiting1,
    TodayLine.pokeWaiting2,
  ];

  /// The customisation sheet closed with a new look.
  static const List<TodayLine> customized = <TodayLine>[
    TodayLine.customized1,
    TodayLine.customized2,
  ];

  /// Another profile became the active one.
  static const List<TodayLine> profileSwitched = <TodayLine>[
    TodayLine.profileSwitched1,
    TodayLine.profileSwitched2,
    TodayLine.profileSwitched3,
  ];

  /// The idle pool of a day with [clipCount] clips.
  static List<TodayLine> idle(int clipCount) => switch (clipCount) {
    0 => waiting,
    1 => keptOne,
    _ => keptSeveral,
  };

  /// The line for a save that brings the profile's recorded days to
  /// [recordedDays], when that count has one; said in place of a
  /// [justSaved] line.
  static TodayLine? milestone(int recordedDays) => switch (recordedDays) {
    7 => TodayLine.milestone7,
    30 => TodayLine.milestone30,
    100 => TodayLine.milestone100,
    365 => TodayLine.milestone365,
    _ => null,
  };
}

/// Hands out a pool's lines in a shuffled order, without a repeat until
/// the pool is spent.
final class TodayLineRotation {
  TodayLineRotation(this._random);

  final math.Random _random;
  final Map<List<TodayLine>, List<TodayLine>> _left =
      <List<TodayLine>, List<TodayLine>>{};

  TodayLine next(List<TodayLine> pool) {
    final List<TodayLine> left = _left.putIfAbsent(pool, () => <TodayLine>[]);
    if (left.isEmpty) left.addAll(List<TodayLine>.of(pool)..shuffle(_random));
    return left.removeLast();
  }
}
