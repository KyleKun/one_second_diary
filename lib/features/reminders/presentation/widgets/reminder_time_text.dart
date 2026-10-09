import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/reminders/presentation/reminder_time_label.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The big reminder time of the Notifications page: the digits in the
/// display style, and in a 12-hour language the day period beside them.
///
/// Each digit that changes rolls (`OsdMotion.digitRoll`); digits sit in slots
/// as wide as "0", so the line never shifts. Under reduced motion they
/// crossfade. The time is also a button, announced as "Reminder time, 20:00.
/// Double-tap to change."
class ReminderTimeText extends StatelessWidget {
  const ReminderTimeText({super.key, required this.label, this.onTap});

  static const Key digitsKey = Key('reminderTimeText.digits');

  final ReminderTimeLabel label;

  /// Opens the time sheet.
  final VoidCallback? onTap;

  static const double _periodGap = 6;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final TextScaler displayScaler = OsdTextScale.scalerFor(
      context,
      OsdTextScaleRole.display,
    );
    final TextStyle periodStyle = typography.timeSuffix.copyWith(
      color: colors.mu,
    );
    final String? before = label.before;
    final String? after = label.after;
    return OsdPressable(
      onTap: onTap,
      overlay: OsdPressOverlay.none,
      semanticsLabel: Strings.notificationsTimeSemantics(time: label.spoken),
      semanticsTapHint: Strings.change,
      excludeChildSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            if (before != null) ...<Widget>[
              Text(before, style: periodStyle),
              const SizedBox(width: _periodGap),
            ],
            _RollingText(
              key: digitsKey,
              text: label.time,
              style: typography.displayHero.copyWith(color: colors.tx),
              textScaler: displayScaler,
            ),
            if (after != null) ...<Widget>[
              const SizedBox(width: _periodGap),
              Text(after, style: periodStyle),
            ],
          ],
        ),
      ),
    );
  }
}

/// [text] as a row of character slots whose changes roll.
class _RollingText extends StatefulWidget {
  const _RollingText({
    super.key,
    required this.text,
    required this.style,
    required this.textScaler,
  });

  final String text;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  State<_RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<_RollingText> {
  /// The width of "0", measured once per style and text scale.
  double? _digitWidth;
  TextStyle? _measuredStyle;
  TextScaler? _measuredScaler;

  /// How many digits before each position changed in the last update.
  List<int> _staggers = const <int>[];

  double _widthOfZero() {
    if (_digitWidth != null &&
        _measuredStyle == widget.style &&
        _measuredScaler == widget.textScaler) {
      return _digitWidth!;
    }
    final TextPainter painter = TextPainter(
      text: TextSpan(text: '0', style: widget.style),
      textScaler: widget.textScaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _measuredStyle = widget.style;
    _measuredScaler = widget.textScaler;
    _digitWidth = painter.width;
    painter.dispose();
    return _digitWidth!;
  }

  @override
  void didUpdateWidget(_RollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    final List<int> staggers = <int>[];
    int changed = 0;
    for (int i = 0; i < widget.text.length; i++) {
      staggers.add(changed);
      final bool same =
          i < oldWidget.text.length && oldWidget.text[i] == widget.text[i];
      if (!same) changed++;
    }
    _staggers = staggers;
  }

  @override
  Widget build(BuildContext context) {
    final double digitWidth = _widthOfZero();
    final List<String> characters = widget.text.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        for (int i = 0; i < characters.length; i++)
          _RollingCharacter(
            // A new length re-lays the row out: slots are matched by position.
            key: ValueKey<(int, int)>((characters.length, i)),
            character: characters[i],
            width: _isDigit(characters[i]) ? digitWidth : null,
            stagger: i < _staggers.length ? _staggers[i] : 0,
            style: widget.style,
            textScaler: widget.textScaler,
          ),
      ],
    );
  }

  static bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39;
}

/// One character slot: when [character] changes, the old one rolls up and
/// out while the new one rolls in from below.
class _RollingCharacter extends StatefulWidget {
  const _RollingCharacter({
    super.key,
    required this.character,
    required this.width,
    required this.stagger,
    required this.style,
    required this.textScaler,
  });

  final String character;

  /// The slot width (digits), or null for the character's own width.
  final double? width;

  /// How many changed digits roll before this one.
  final int stagger;

  final TextStyle style;
  final TextScaler textScaler;

  @override
  State<_RollingCharacter> createState() => _RollingCharacterState();
}

class _RollingCharacterState extends State<_RollingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    value: 1,
  );
  String? _previous;
  Curve _curve = Curves.linear;
  bool _slides = true;

  @override
  void didUpdateWidget(_RollingCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character == widget.character) return;
    _previous = oldWidget.character;
    final bool reduced = OsdMotion.reduced(context);
    _slides = !reduced;
    final Duration delay = reduced
        ? Duration.zero
        : OsdMotion.digitRollStagger * widget.stagger;
    final Duration roll = OsdMotion.d(context, OsdMotion.digitRoll);
    final Duration total = delay + roll;
    _curve = Interval(
      delay.inMicroseconds / total.inMicroseconds,
      1,
      curve: OsdMotion.curve(context, Curves.easeOutCubic),
    );
    _roll
      ..duration = total
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  Widget _text(String character) => Text(
    character,
    style: widget.style,
    textScaler: widget.textScaler,
    maxLines: 1,
    softWrap: false,
    textAlign: TextAlign.center,
  );

  @override
  Widget build(BuildContext context) {
    final Widget slot = AnimatedBuilder(
      animation: _roll,
      builder: (BuildContext context, Widget? _) {
        final double t = _curve.transform(_roll.value);
        final String? previous = _previous;
        final double slide = _slides ? OsdMotion.digitRollSlide : 0;
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (previous != null && t < 1)
              Opacity(
                opacity: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, -slide * t),
                  child: _text(previous),
                ),
              ),
            Opacity(
              opacity: previous == null ? 1 : t,
              child: Transform.translate(
                offset: Offset(0, previous == null ? 0 : slide * (1 - t)),
                child: _text(widget.character),
              ),
            ),
          ],
        );
      },
    );
    final double? width = widget.width;
    return width == null ? slot : SizedBox(width: width, child: slot);
  }
}
