import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/character/presentation/character_labels.dart';
import 'package:one_second_diary/features/character/presentation/widgets/character_figure.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/foundation/dashed_border.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/surfaces/clip_placeholder.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// What the sheet's cards open.
enum _Part {
  shape,
  eyes,
  mouth,
  colour;

  String get label => switch (this) {
    shape => Strings.characterPartShape,
    eyes => Strings.characterPartEyes,
    mouth => Strings.characterPartMouth,
    colour => Strings.characterPartColour,
  };
}

/// The character's options, like a game's character editor: the live
/// stage always on top (tap to poke), under it four cards (Shape, Eyes,
/// Mouth, Colour) and the No character switch; a card opens its options,
/// large, in the same room, so the sheet never grows or scrolls. At the
/// foot, Shuffle and Done on the cards; inside a part, Shuffle (that part
/// only) and Save, which returns to the cards, as Back does, keeping the
/// picks. Done pops with the look; dismissing the sheet pops with nothing,
/// so the page keeps the look it had.
class CharacterSheet extends StatefulWidget {
  const CharacterSheet({
    super.key,
    required this.look,
    required this.stampText,
  });

  /// The look to start from.
  final CharacterLook look;

  /// The date stamp the "No character" preview shows, in the user's format.
  final String stampText;

  /// Opens the sheet on [look]; completes with the look Done kept, or null
  /// when the sheet was dismissed.
  static Future<CharacterLook?> show(
    BuildContext context, {
    required CharacterLook look,
    required String stampText,
  }) => showOsdSheet<CharacterLook>(
    context,
    title: Strings.characterSheetTitle,
    child: CharacterSheet(look: look, stampText: stampText),
  );

  @override
  State<CharacterSheet> createState() => _CharacterSheetState();
}

class _CharacterSheetState extends State<CharacterSheet> {
  final GlobalKey<CharacterFigureState> _stage =
      GlobalKey<CharacterFigureState>();
  final math.Random _random = math.Random();
  late CharacterLook _look = widget.look;
  _Part? _open;

  /// The room under the stage, the same for the cards and every part's
  /// options.
  static const double _room = 300;

  void _set(CharacterLook look) {
    if (look == _look) return;
    unawaited(OsdHaptic.selection.play());
    setState(() => _look = look);
    _stage.currentState?.poke();
  }

  /// Into a part, or back to the cards.
  void _show(_Part? part) {
    unawaited(OsdHaptic.light.play());
    setState(() => _open = part);
  }

  T _other<T>(List<T> values, T current) {
    final List<T> rest = <T>[
      for (final T value in values)
        if (value != current) value,
    ];
    return rest[_random.nextInt(rest.length)];
  }

  /// Shuffles the open part only, or everything from the cards.
  void _shuffle() {
    final CharacterLook look = _look;
    switch (_open) {
      case null:
        _set(CharacterLook.random(_random));
      case _Part.shape:
        _set(
          look.copyWith(
            shape: _other(CharacterShape.values, look.shape),
            hidden: false,
          ),
        );
      case _Part.eyes:
        _set(look.copyWith(eyes: _other(CharacterEyes.values, look.eyes)));
      case _Part.mouth:
        _set(look.copyWith(mouth: _other(CharacterMouth.values, look.mouth)));
      case _Part.colour:
        _set(look.copyWith(color: _other(CharacterPalette.colors, look.color)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final Duration duration = OsdMotion.d(context, OsdMotion.standard);
    final _Part? open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: () => _stage.currentState?.poke(),
          child: Container(
            height: 168,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(OsdRadius.r22),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: duration,
              child: _look.hidden
                  ? SizedBox(
                      key: const ValueKey<bool>(true),
                      width: 210,
                      height: 118,
                      child: ClipPlaceholder(
                        stampText: widget.stampText,
                        semanticsLabel: Strings.characterNone,
                      ),
                    )
                  : CharacterFigure(
                      key: _stage,
                      look: _look,
                      happy: false,
                      size: 128,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _room,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              // The cards come back from the left, a part's options in from
              // the right.
              final bool cards = child.key == const ValueKey<String>('cards');
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(cards ? -.08 : .08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: open == null ? _cards(colors) : _options(open, colors),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          spacing: 10,
          children: <Widget>[
            Expanded(
              child: NeutralButton(
                label: Strings.characterShuffle,
                icon: OsdIcons.replay,
                onPressed: _shuffle,
              ),
            ),
            Expanded(
              child: PrimaryButton(
                label: open == null ? Strings.done : Strings.save,
                onPressed: open == null
                    ? () => Navigator.of(context).pop(_look)
                    : () => _show(null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// The four parts in a 2 × 2 grid, the No character switch under them.
  /// Without a character only Shape stays open: picking one brings it back.
  Widget _cards(OsdColors colors) {
    Widget card(_Part part) => Expanded(
      child: _PartCard(
        part: part,
        look: _look,
        onTap: _look.hidden && part != _Part.shape ? null : () => _show(part),
      ),
    );
    return Column(
      key: const ValueKey<String>('cards'),
      spacing: 10,
      children: <Widget>[
        Expanded(
          child: Row(
            spacing: 10,
            children: <Widget>[card(_Part.shape), card(_Part.eyes)],
          ),
        ),
        Expanded(
          child: Row(
            spacing: 10,
            children: <Widget>[card(_Part.mouth), card(_Part.colour)],
          ),
        ),
        _NoneSwitch(
          on: _look.hidden,
          onTap: () => _set(_look.copyWith(hidden: !_look.hidden)),
        ),
      ],
    );
  }

  /// A part's options, large, in two rows that scroll sideways when they
  /// run past the sheet. Each pick is kept at once; Save and Back both
  /// return to the cards.
  Widget _options(_Part part, OsdColors colors) {
    final List<Widget> tiles = switch (part) {
      _Part.shape => <Widget>[
        for (final CharacterShape shape in CharacterShape.values)
          _Choice(
            label: shape.label,
            selected: !_look.hidden && shape == _look.shape,
            onTap: () => _set(_look.copyWith(shape: shape, hidden: false)),
            look: _look.copyWith(shape: shape, hidden: false),
          ),
      ],
      _Part.eyes => <Widget>[
        for (final CharacterEyes eyes in CharacterEyes.values)
          _Choice(
            label: eyes.label,
            selected: eyes == _look.eyes,
            onTap: () => _set(_look.copyWith(eyes: eyes)),
            look: _look.copyWith(eyes: eyes),
          ),
      ],
      _Part.mouth => <Widget>[
        for (final CharacterMouth mouth in CharacterMouth.values)
          _Choice(
            label: mouth.label,
            selected: mouth == _look.mouth,
            onTap: () => _set(_look.copyWith(mouth: mouth)),
            look: _look.copyWith(mouth: mouth),
          ),
      ],
      _Part.colour => <Widget>[
        for (final Color color in CharacterPalette.colors)
          _Swatch(
            color: color,
            selected: color == _look.color,
            onTap: () => _set(_look.copyWith(color: color)),
          ),
      ],
    };
    return Column(
      key: ValueKey<_Part>(part),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 44,
          child: Row(
            spacing: 4,
            children: <Widget>[
              OsdIconButton(
                icon: OsdIcons.arrowBack,
                tooltip: CommonLabels.of(context).back,
                onPressed: () => _show(null),
              ),
              Text(
                part.label,
                style: context.typography.title18Strong.copyWith(
                  color: colors.tx,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          // The colours all fit, five to a row; the rest scroll sideways.
          child: part == _Part.colour
              ? GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: tiles,
                )
              : GridView.count(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: tiles,
                ),
        ),
      ],
    );
  }
}

/// A part's card: its icon over its name, a button into its options.
/// Disabled ([onTap] null), it fades.
class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.look,
    required this.onTap,
  });

  final _Part part;
  final CharacterLook look;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r18);
    return OsdPressable(
      onTap: onTap,
      opacity: OsdPressable.opacityFor(enabled: onTap != null),
      borderRadius: radius,
      semanticsLabel: part.label,
      excludeChildSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.bg, borderRadius: radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: <Widget>[
            SizedBox.square(
              dimension: 44,
              child: Center(
                child: _PartIcon(part: part, look: look),
              ),
            ),
            Text(
              part.label,
              style: context.typography.titleSmall.copyWith(color: colors.tx),
            ),
          ],
        ),
      ),
    );
  }
}

/// A part's icon: the shape's outline, a pair of eyes, a smile, or a dot
/// of the colour.
class _PartIcon extends StatelessWidget {
  const _PartIcon({required this.part, required this.look});

  final _Part part;
  final CharacterLook look;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.colors.tx;
    return switch (part) {
      _Part.shape => Transform.translate(
        offset: const Offset(0, -1),
        child: CharacterFigure(
          look: look.copyWith(color: ink),
          happy: false,
          still: true,
          outline: true,
          bare: true,
          size: 42,
        ),
      ),
      _Part.colour => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(shape: BoxShape.circle, color: look.color),
      ),
      _ => CustomPaint(
        size: const Size.square(36),
        painter: _PartGlyphPainter(eyes: part == _Part.eyes, color: ink),
      ),
    };
  }
}

/// Two eyes, or a smile, as a small glyph.
class _PartGlyphPainter extends CustomPainter {
  const _PartGlyphPainter({required this.eyes, required this.color});

  final bool eyes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = size.center(Offset.zero);
    if (eyes) {
      final Paint fill = Paint()..color = color;
      for (final double side in <double>[-1, 1]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: c.translate(side * s * .22, 0),
            width: s * .24,
            height: s * .42,
          ),
          fill,
        );
      }
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * .3, c.dy - s * .08)
        ..quadraticBezierTo(
          c.dx,
          c.dy + s * .34,
          c.dx + s * .3,
          c.dy - s * .08,
        ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PartGlyphPainter oldDelegate) =>
      eyes != oldDelegate.eyes || color != oldDelegate.color;
}

/// No character, as a switch row: Today then shows the dashed frame.
class _NoneSwitch extends StatelessWidget {
  const _NoneSwitch({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r18);
    return OsdPressable(
      onTap: onTap,
      borderRadius: radius,
      semanticsLabel: Strings.characterNone,
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: OsdMotion.d(context, OsdMotion.fast),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: radius,
          border: Border.all(
            color: on ? colors.tx : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          spacing: 12,
          children: <Widget>[
            _NoneArt(color: colors.mu),
            Expanded(
              child: Text(
                Strings.characterNone,
                style: context.typography.titleSmall.copyWith(color: colors.tx),
              ),
            ),
            OsdIcon(
              on ? OsdIcons.checkCircle : OsdIcons.radioButtonUnchecked,
              size: 24,
              fill: on ? 1 : 0,
              color: on ? colors.tx : colors.mu,
            ),
          ],
        ),
      ),
    );
  }
}

/// An option: the character wearing it over its [label], ringed when
/// [selected].
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.look,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final CharacterLook look;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r18);
    return OsdPressable(
      onTap: onTap,
      borderRadius: radius,
      semanticsLabel: label,
      child: AnimatedContainer(
        duration: OsdMotion.d(context, OsdMotion.fast),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.tx : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              child: FittedBox(
                child: CharacterFigure(
                  look: look,
                  happy: false,
                  size: 72,
                  still: true,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              style: context.typography.label13.copyWith(color: colors.tx),
            ),
          ],
        ),
      ),
    );
  }
}

/// A colour option: a large dot, ringed when [selected].
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: OsdPressable(
      onTap: onTap,
      shape: BoxShape.circle,
      semanticsLabel: Strings.characterColourA11y,
      child: AnimatedContainer(
        duration: OsdMotion.d(context, OsdMotion.fast),
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? context.colors.tx : Colors.transparent,
            width: 3,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    ),
  );
}

/// "No character" in small: a dashed frame with a stamp-like line.
class _NoneArt extends StatelessWidget {
  const _NoneArt({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 30,
    child: DashedBorder(
      color: color,
      borderRadius: BorderRadius.circular(OsdRadius.r8),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.fromLTRB(6, 0, 0, 6),
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ),
  );
}
