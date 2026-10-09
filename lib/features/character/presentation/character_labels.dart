import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';

/// The names the character's options go by in the app language.
extension CharacterShapeLabel on CharacterShape {
  String get label => switch (this) {
    CharacterShape.triangle => Strings.characterShapeTriangle,
    CharacterShape.round => Strings.characterShapeRound,
    CharacterShape.squircle => Strings.characterShapeSquircle,
    CharacterShape.drop => Strings.characterShapeDrop,
    CharacterShape.cloud => Strings.characterShapeCloud,
    CharacterShape.heart => Strings.characterShapeHeart,
    CharacterShape.star => Strings.characterShapeStar,
    CharacterShape.flower => Strings.characterShapeFlower,
    CharacterShape.ghost => Strings.characterShapeGhost,
    CharacterShape.mochi => Strings.characterShapeMochi,
    CharacterShape.hexagon => Strings.characterShapeHexagon,
    CharacterShape.pebble => Strings.characterShapePebble,
  };
}

extension CharacterEyesLabel on CharacterEyes {
  String get label => switch (this) {
    CharacterEyes.classic => Strings.characterEyesClassic,
    CharacterEyes.dots => Strings.characterEyesDots,
    CharacterEyes.big => Strings.characterEyesBig,
    CharacterEyes.shy => Strings.characterEyesShy,
    CharacterEyes.sleepy => Strings.characterEyesSleepy,
    CharacterEyes.sparkle => Strings.characterEyesSparkle,
  };
}

extension CharacterMouthLabel on CharacterMouth {
  String get label => switch (this) {
    CharacterMouth.simple => Strings.characterMouthSimple,
    CharacterMouth.cat => Strings.characterMouthCat,
    CharacterMouth.open => Strings.characterMouthOpen,
    CharacterMouth.tiny => Strings.characterMouthTiny,
  };
}
