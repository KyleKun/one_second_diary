import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:one_second_diary/theme/osd_artwork.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The white bubble the character talks in. A new [line] (a new [id])
/// springs up out of the tail and types itself out character by character
/// ([onTyping] says while), stays a moment, then lifts away and fades
/// ([onDone]). A line arriving while another shows replaces it: the old
/// one leaves first. Above the character its [room] is kept, so the
/// character never moves; [beside] it, it sits to its right with the
/// tail on its left.
class SpeechBubble extends StatefulWidget {
  /// The height kept for the bubble above the character, shown or not.
  static const double room = 92;

  const SpeechBubble({
    super.key,
    required this.line,
    required this.id,
    required this.onTyping,
    required this.onDone,
    this.beside = false,
  });

  final String? line;
  final int id;
  final bool beside;
  final ValueChanged<bool> onTyping;
  final VoidCallback onDone;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble>
    with TickerProviderStateMixin {
  static const Duration _perCharacter = Duration(milliseconds: 38);
  static const Duration _leave = Duration(milliseconds: 170);
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 21,
  );

  late final AnimationController _presence = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _typing = AnimationController(vsync: this);

  String? _shown;
  bool _leaving = false;
  Timer? _hold;

  /// Bumped on every switch, so a switch overtaken by a newer one stops.
  int _turn = 0;

  @override
  void didUpdateWidget(SpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) unawaited(_switchTo(widget.line));
  }

  Future<void> _switchTo(String? line) async {
    final int turn = ++_turn;
    _hold?.cancel();
    _typing.stop();
    // Called from didUpdateWidget: the page must finish building first.
    await Future<void>.delayed(Duration.zero);
    if (!mounted || turn != _turn) return;
    widget.onTyping(false);
    final bool reduced = OsdMotion.reduced(context);
    if (_shown != null && _presence.value > .01) {
      setState(() => _leaving = true);
      if (reduced) {
        _presence.value = 0;
      } else {
        await _presence.animateTo(
          0,
          duration: _leave,
          curve: Curves.easeInCubic,
        );
      }
      if (!mounted || turn != _turn) return;
    }
    // Untyped and unseen before the new line's first frame, else it flashes
    // in full with the last line's progress.
    _typing.value = 0;
    _presence.value = 0;
    setState(() {
      _shown = line;
      _leaving = false;
    });
    if (line == null) return;
    final int length = line.characters.length;
    if (reduced) {
      _presence.value = 1;
      _typing.value = 1;
    } else {
      unawaited(_presence.animateWith(SpringSimulation(_spring, 0, 1, 0)));
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted || turn != _turn) return;
      widget.onTyping(true);
      _typing.duration = _perCharacter * length;
      await _typing.forward(from: 0);
      if (!mounted || turn != _turn) return;
      widget.onTyping(false);
    }
    _hold = Timer(Duration(milliseconds: 2200 + 30 * length), () {
      if (mounted && turn == _turn) widget.onDone();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _presence.dispose();
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? shown = _shown;
    final bool beside = widget.beside;
    return SizedBox(
      height: beside ? null : SpeechBubble.room,
      child: Align(
        alignment: beside ? Alignment.bottomLeft : Alignment.bottomCenter,
        widthFactor: beside ? 1 : null,
        heightFactor: beside ? 1 : null,
        child: shown == null
            ? const SizedBox.shrink()
            : AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_presence, _typing]),
                builder: (BuildContext context, _) {
                  final double p = _presence.value;
                  final double scale = _leaving ? .9 + .1 * p : .55 + .45 * p;
                  final double shift = _leaving ? -(1 - p) * 10 : (1 - p) * 14;
                  final double opacity = (_leaving ? p : p * 2.5).clamp(0, 1);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      // Out of the tail: up from below, or in from the left.
                      offset: beside && !_leaving
                          ? Offset(-shift, 0)
                          : Offset(0, shift),
                      child: Transform.scale(
                        scale: scale,
                        alignment: beside
                            ? Alignment.centerLeft
                            : Alignment.bottomCenter,
                        child: _Bubble(
                          text: shown,
                          typed: _typing.value,
                          tailLeft: beside,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// The bubble itself: white with a soft shadow, the tail at its bottom
/// centre, or on its left side when [tailLeft]. The whole [text] lays out
/// from the start, the part not [typed] yet clear, so the bubble never
/// grows as it types.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.typed,
    this.tailLeft = false,
  });

  final String text;
  final bool tailLeft;

  /// How much of [text] shows, 0 → 1.
  final double typed;

  static const double _maxWidth = 270;

  @override
  Widget build(BuildContext context) {
    final Characters characters = text.characters;
    final int shown = (characters.length * typed).floor();
    final TextStyle style = context.typography.displayPill.copyWith(
      color: OsdArtwork.ink,
      fontSize: 19,
    );
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0xFFFFFFFF),
              shape: _BubbleShape(tailLeft: tailLeft),
              shadows: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x2E000000),
                  offset: Offset(0, 6),
                  blurRadius: 18,
                ),
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Padding(
              padding: tailLeft
                  ? const EdgeInsets.fromLTRB(
                      18 + _BubbleShape.tail,
                      11,
                      18,
                      11,
                    )
                  : const EdgeInsets.fromLTRB(
                      18,
                      11,
                      18,
                      11 + _BubbleShape.tail,
                    ),
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: <TextSpan>[
                    TextSpan(text: characters.take(shown).toString()),
                    TextSpan(
                      text: characters.skip(shown).toString(),
                      style: style.copyWith(color: const Color(0x00000000)),
                    ),
                  ],
                ),
                textAlign: tailLeft ? TextAlign.start : TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded rectangle with a soft tail under its centre, or out of its
/// left side ([tailLeft]), as one outline so the shadow follows both.
class _BubbleShape extends ShapeBorder {
  const _BubbleShape({this.tailLeft = false});

  final bool tailLeft;

  static const double tail = 10;
  static const double _radius = 22;
  static const double _tailWidth = 22;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final Rect body = tailLeft
        ? Rect.fromLTRB(rect.left + tail, rect.top, rect.right, rect.bottom)
        : Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - tail);
    final Path tailPath = tailLeft
        ? _leftTail(rect, body)
        : _bottomTail(rect, body);
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(_radius)),
      ),
      tailPath,
    );
  }

  Path _bottomTail(Rect rect, Rect body) {
    final double cx = rect.center.dx;
    return Path()
      ..moveTo(cx - _tailWidth / 2, body.bottom - 1)
      ..cubicTo(
        cx - _tailWidth * .15,
        body.bottom + 1,
        cx - 2,
        rect.bottom,
        cx,
        rect.bottom,
      )
      ..cubicTo(
        cx + 2,
        rect.bottom,
        cx + _tailWidth * .15,
        body.bottom + 1,
        cx + _tailWidth / 2,
        body.bottom - 1,
      )
      ..close();
  }

  /// 24 above the bottom, or the middle of a one-line bubble, so the page
  /// can aim it from the bubble's bottom edge. Its root starts well inside
  /// the body: the side there is still the corner's curve, and a root on
  /// the edge leaves slivers between the two.
  Path _leftTail(Rect rect, Rect body) {
    final double cy = math.max(rect.center.dy, rect.bottom - 24);
    final double root = body.left + 8;
    return Path()
      ..moveTo(root, cy - _tailWidth / 2)
      ..cubicTo(
        body.left - 1,
        cy - _tailWidth * .15,
        rect.left,
        cy - 2,
        rect.left,
        cy,
      )
      ..cubicTo(
        rect.left,
        cy + 2,
        body.left - 1,
        cy + _tailWidth * .15,
        root,
        cy + _tailWidth / 2,
      )
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
