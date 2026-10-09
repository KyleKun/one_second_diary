import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';

/// The body the character is drawn with.
enum CharacterShape {
  triangle,
  round,
  squircle,
  drop,
  cloud,
  heart,
  star,
  flower,
  ghost,
  mochi,
  hexagon,
  pebble,
}

enum CharacterEyes { classic, dots, big, shy, sleepy, sparkle }

enum CharacterMouth { simple, cat, open, tiny }

/// The colours the character can take: all dark enough for ink eyes to
/// read on them, light enough to stand out on BG in both themes.
abstract final class CharacterPalette {
  static const List<Color> colors = <Color>[
    Color(0xFFEF5558),
    Color(0xFFF28C4B),
    Color(0xFFE5B25D),
    Color(0xFF9CC48A),
    Color(0xFF4FB3A9),
    Color(0xFF6FA8C7),
    Color(0xFF7D7ABC),
    Color(0xFFB98AD6),
    Color(0xFFE58FA4),
    Color(0xFFA3A0A8),
  ];
}

/// How the character looks. Stored as one string ([encode] / [decode]).
final class CharacterLook extends Equatable {
  const CharacterLook({
    this.shape = CharacterShape.triangle,
    this.eyes = CharacterEyes.classic,
    this.mouth = CharacterMouth.simple,
    this.color = const Color(0xFFEF5558),
    this.hidden = false,
  });

  static const CharacterLook defaults = CharacterLook();

  final CharacterShape shape;
  final CharacterEyes eyes;
  final CharacterMouth mouth;
  final Color color;

  /// No character: Today shows the dashed frame with the date stamp
  /// instead. The rest is kept for when it comes back.
  final bool hidden;

  CharacterLook copyWith({
    CharacterShape? shape,
    CharacterEyes? eyes,
    CharacterMouth? mouth,
    Color? color,
    bool? hidden,
  }) => CharacterLook(
    shape: shape ?? this.shape,
    eyes: eyes ?? this.eyes,
    mouth: mouth ?? this.mouth,
    color: color ?? this.color,
    hidden: hidden ?? this.hidden,
  );

  /// A look picked at random, never hidden.
  static CharacterLook random(math.Random random) => CharacterLook(
    shape: CharacterShape.values[random.nextInt(CharacterShape.values.length)],
    eyes: CharacterEyes.values[random.nextInt(CharacterEyes.values.length)],
    mouth: CharacterMouth.values[random.nextInt(CharacterMouth.values.length)],
    color:
        CharacterPalette.colors[random.nextInt(CharacterPalette.colors.length)],
  );

  static const String _separator = ',';

  /// `shape,eyes,mouth,AARRGGBB,hidden`, each an enum name or a flag word.
  String encode() => <String>[
    shape.name,
    eyes.name,
    mouth.name,
    color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase(),
    if (hidden) 'hidden' else 'shown',
  ].join(_separator);

  /// The look [stored] holds. A field it lacks, or one with a token this
  /// version does not know, reads as that field's default; a colour outside
  /// the palette reads as the default colour.
  static CharacterLook decode(String stored) {
    final List<String> parts = stored.split(_separator);
    String part(int index) => index < parts.length ? parts[index].trim() : '';
    return CharacterLook(
      shape: _byName(CharacterShape.values, part(0), defaults.shape),
      eyes: _byName(CharacterEyes.values, part(1), defaults.eyes),
      mouth: _byName(CharacterMouth.values, part(2), defaults.mouth),
      color: _paletteColor(part(3)),
      hidden: part(4) == 'hidden',
    );
  }

  static T _byName<T extends Enum>(List<T> values, String name, T fallback) {
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static Color _paletteColor(String hex) {
    final int? argb = int.tryParse(hex, radix: 16);
    if (argb == null) return defaults.color;
    for (final Color color in CharacterPalette.colors) {
      if (color.toARGB32() == argb) return color;
    }
    return defaults.color;
  }

  @override
  List<Object?> get props => <Object?>[shape, eyes, mouth, color, hidden];
}
