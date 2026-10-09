import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/theme/osd_artwork.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The app's character, drawn from its [look]. It breathes slowly, blinks
/// now and then and glances around (up and away while waiting). [talking],
/// its mouth moves. Waiting it has a calm face; [happy], its eyes squint
/// into arcs over a smile, and it hops once as it turns happy. [poke]
/// squishes it. [still] (option tiles), or under reduced motion, it holds
/// still and changes mood at once.
class CharacterFigure extends StatefulWidget {
  const CharacterFigure({
    super.key,
    required this.look,
    required this.happy,
    required this.size,
    this.talking = false,
    this.lookingDown = false,
    this.still = false,
    this.outline = false,
    this.bare = false,
  });

  final CharacterLook look;
  final bool happy;
  final bool talking;

  /// Eyes held down (at the record button under it); no glances meanwhile.
  final bool lookingDown;
  final double size;
  final bool still;

  /// Drawn as a line figure in its colour, face included, like an icon.
  final bool outline;

  /// The body alone, without a face.
  final bool bare;

  @override
  State<CharacterFigure> createState() => CharacterFigureState();
}

class CharacterFigureState extends State<CharacterFigure>
    with TickerProviderStateMixin {
  static final math.Random _random = math.Random();

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  late final AnimationController _mood = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: widget.happy ? 1 : 0,
  );
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _squish = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late final AnimationController _talk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  );
  late final AnimationController _glance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  final _Gaze _gaze = _Gaze();

  Timer? _nextBlink;
  Timer? _nextGlance;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _gaze.to = _restingGaze;
    _gaze.from = _gaze.to;
  }

  /// Where the eyes rest: a little up while waiting, at the user when
  /// happy.
  Offset get _restingGaze => widget.happy ? Offset.zero : const Offset(0, -.02);

  /// As far down as the eyes go.
  static const Offset _down = Offset(0, .04);

  /// Where an idle glance can go, in fractions of the character's size:
  /// at the user more often than not, else around (up more while waiting).
  static const List<Offset> _waitingGlances = <Offset>[
    Offset.zero,
    Offset.zero,
    Offset(0, -.035),
    Offset(-.035, -.03),
    Offset(.035, -.03),
    Offset(-.04, 0),
    Offset(.04, 0),
  ];
  static const List<Offset> _happyGlances = <Offset>[
    Offset.zero,
    Offset.zero,
    Offset.zero,
    Offset(-.03, 0),
    Offset(.03, 0),
    Offset(0, -.025),
    Offset(0, .015),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = widget.still || OsdMotion.reduced(context);
    if (_still) {
      _breath.stop();
      _nextBlink?.cancel();
      _nextGlance?.cancel();
    } else if (!_breath.isAnimating) {
      unawaited(_breath.repeat(reverse: true));
      _scheduleBlink();
      _scheduleGlance();
    }
  }

  @override
  void didUpdateWidget(CharacterFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lookingDown != oldWidget.lookingDown && !_still) {
      _lookAt(widget.lookingDown ? _down : _restingGaze);
    }
    if (widget.talking != oldWidget.talking && !_still) {
      if (widget.talking) {
        _lookAt(widget.lookingDown ? _down : Offset.zero);
        unawaited(_talk.repeat(reverse: true));
      } else {
        _talk
          ..stop()
          ..value = 0;
      }
    }
    if (widget.happy == oldWidget.happy) return;
    if (_still) {
      _mood.value = widget.happy ? 1 : 0;
      _gaze
        ..from = _restingGaze
        ..to = _restingGaze;
      return;
    }
    unawaited(
      _mood.animateTo(widget.happy ? 1 : 0, curve: Curves.easeOutCubic),
    );
    _lookAt(_restingGaze);
    if (widget.happy) unawaited(_hop.forward(from: 0));
  }

  void poke() {
    if (_still) return;
    unawaited(_squish.forward(from: 0));
    _lookAt(Offset.zero);
  }

  void _lookAt(Offset target) {
    _gaze
      ..from = _gaze.at(_glance.value)
      ..to = target;
    unawaited(_glance.forward(from: 0));
  }

  void _scheduleBlink() {
    _nextBlink?.cancel();
    _nextBlink = Timer(
      Duration(milliseconds: 2600 + _random.nextInt(3800)),
      () async {
        if (!mounted) return;
        await _blink.forward(from: 0);
        // Now and then a double blink.
        if (mounted && _random.nextInt(4) == 0) {
          await _blink.forward(from: 0);
        }
        if (mounted) _scheduleBlink();
      },
    );
  }

  void _scheduleGlance() {
    _nextGlance?.cancel();
    _nextGlance = Timer(
      Duration(milliseconds: 1800 + _random.nextInt(2800)),
      () {
        if (!mounted) return;
        if (!widget.talking && !widget.lookingDown) {
          final List<Offset> glances = widget.happy
              ? _happyGlances
              : _waitingGlances;
          _lookAt(glances[_random.nextInt(glances.length)]);
        }
        _scheduleGlance();
      },
    );
  }

  @override
  void dispose() {
    _nextBlink?.cancel();
    _nextGlance?.cancel();
    _breath.dispose();
    _mood.dispose();
    _hop.dispose();
    _squish.dispose();
    _blink.dispose();
    _talk.dispose();
    _glance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _CharacterPainter(
          look: widget.look,
          breath: _breath,
          mood: _mood,
          hop: _hop,
          squish: _squish,
          blink: _blink,
          talk: _talk,
          speaking: widget.talking && !_still,
          glance: _glance,
          gaze: _gaze,
          outline: widget.outline,
          bare: widget.bare,
        ),
      ),
    ),
  );
}

/// Where the eyes look, in fractions of the character's size: they move
/// from [from] to [to] as the glance runs.
class _Gaze {
  Offset from = Offset.zero;
  Offset to = Offset.zero;

  Offset at(double t) =>
      Offset.lerp(from, to, Curves.easeOutCubic.transform(t))!;
}

/// A body's outline and where its face sits, for a character [s]
/// tall whose base is at `s * .42` below the origin.
typedef _Body = ({Path path, double eyeY});

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.look,
    required this.breath,
    required this.mood,
    required this.hop,
    required this.squish,
    required this.blink,
    required this.talk,
    required this.speaking,
    required this.glance,
    required this.gaze,
    required this.outline,
    required this.bare,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           breath,
           mood,
           hop,
           squish,
           blink,
           talk,
           glance,
         ]),
       );

  final CharacterLook look;
  final Animation<double> breath;
  final Animation<double> mood;
  final Animation<double> hop;
  final Animation<double> squish;
  final Animation<double> blink;
  final Animation<double> talk;

  /// Whether it is talking: the mouth stays the talking one throughout,
  /// [talk] only opening and closing it.
  final bool speaking;

  /// The calm face's mouth already curves this much of the happy one's: a
  /// slight smile, never flat.
  static const double _restingSmile = .45;

  /// The furthest a glance goes, in fractions of the character's size: a
  /// glance this far puts the glint at the eye's edge.
  static const double _gazeReach = .04;
  final Animation<double> glance;
  final _Gaze gaze;
  final bool outline;
  final bool bare;

  /// The face's colour: the body's own when [outline], where glints are
  /// left out.
  Color get _ink => outline ? look.color : OsdArtwork.ink;

  static const double _base = .42;

  /// Where the ghost's hem lobes start, above the base they reach.
  static const double _ghostHem = .34;

  static _Body _bodyOf(CharacterShape shape, double s) => switch (shape) {
    CharacterShape.triangle => (
      path: _roundedPolygon(<Offset>[
        Offset(0, -s * .42),
        Offset(s * .48, s * _base),
        Offset(-s * .48, s * _base),
      ], s * .2),
      eyeY: s * .07,
    ),
    CharacterShape.round => (
      path: Path()
        ..addOval(Rect.fromCircle(center: Offset(0, s * .02), radius: s * .4)),
      eyeY: -s * .01,
    ),
    CharacterShape.squircle => (
      path: Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(-s * .41, -s * .34, s * .41, s * _base),
            Radius.circular(s * .26),
          ),
        ),
      eyeY: -s * .01,
    ),
    CharacterShape.drop => (
      path: Path()
        ..moveTo(0, -s * .44)
        ..cubicTo(s * .14, -s * .3, s * .42, -s * .08, s * .42, s * .12)
        ..cubicTo(s * .42, s * .32, s * .24, s * _base, 0, s * _base)
        ..cubicTo(-s * .24, s * _base, -s * .42, s * .32, -s * .42, s * .12)
        ..cubicTo(-s * .42, -s * .08, -s * .14, -s * .3, 0, -s * .44)
        ..close(),
      eyeY: s * .09,
    ),
    CharacterShape.cloud => (
      path:
          <Path>[
            Path()..addOval(
              Rect.fromCircle(
                center: Offset(-s * .22, -s * .04),
                radius: s * .2,
              ),
            ),
            Path()..addOval(
              Rect.fromCircle(center: Offset(0, -s * .15), radius: s * .23),
            ),
            Path()..addOval(
              Rect.fromCircle(
                center: Offset(s * .22, -s * .04),
                radius: s * .2,
              ),
            ),
          ].fold(
            Path()..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTRB(-s * .42, -s * .06, s * .42, s * _base),
                Radius.circular(s * .18),
              ),
            ),
            (Path union, Path bump) =>
                Path.combine(PathOperation.union, union, bump),
          ),
      eyeY: s * .09,
    ),
    CharacterShape.heart => (
      path: Path()
        ..moveTo(0, -s * .2)
        ..cubicTo(-s * .07, -s * .38, -s * .46, -s * .37, -s * .45, -s * .07)
        ..cubicTo(-s * .44, s * .16, -s * .14, s * .3, 0, s * _base)
        ..cubicTo(s * .14, s * .3, s * .44, s * .16, s * .45, -s * .07)
        ..cubicTo(s * .46, -s * .37, s * .07, -s * .38, 0, -s * .2)
        ..close(),
      eyeY: -s * .02,
    ),
    CharacterShape.star => (
      path: _roundedPolygon(<Offset>[
        for (int i = 0; i < 10; i++)
          Offset.fromDirection(
            -math.pi / 2 + i * math.pi / 5,
            s * (i.isEven ? .47 : .25),
          ).translate(0, s * .04),
      ], s * .07),
      eyeY: s * .05,
    ),
    CharacterShape.flower => (
      path:
          <Path>[
            for (int i = 0; i < 8; i++)
              Path()..addOval(
                Rect.fromCircle(
                  center: Offset.fromDirection(
                    i * math.pi / 4,
                    s * .26,
                  ).translate(0, s * .02),
                  radius: s * .15,
                ),
              ),
          ].fold(
            Path()..addOval(
              Rect.fromCircle(center: Offset(0, s * .02), radius: s * .3),
            ),
            (Path union, Path petal) =>
                Path.combine(PathOperation.union, union, petal),
          ),
      eyeY: s * .0,
    ),
    CharacterShape.ghost => (
      path: () {
        final double r = s * .38;
        final Path path = Path()
          ..moveTo(-r, 0)
          ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
          ..lineTo(r, _ghostHem * s);
        // The hem: three rounded lobes back to the left. Each lobe follows
        // sin^0.7, which leaves the sides straight down (no corner) and
        // meets the next lobe in a soft dip.
        const int lobes = 3;
        const int steps = 24;
        for (int i = 1; i <= lobes * steps; i++) {
          final double t = i / steps;
          final double depth = math
              .pow(math.sin(math.pi * (t - t.floor())).abs(), .7)
              .toDouble();
          path.lineTo(
            r - 2 * r * i / (lobes * steps),
            s * (_ghostHem + (_base - _ghostHem) * depth),
          );
        }
        return path..close();
      }(),
      eyeY: -s * .02,
    ),
    CharacterShape.mochi => (
      path: Path()
        ..moveTo(-s * .34, s * _base)
        ..quadraticBezierTo(-s * .48, s * _base, -s * .47, s * .28)
        ..cubicTo(-s * .45, -s * .08, -s * .24, -s * .24, 0, -s * .24)
        ..cubicTo(s * .24, -s * .24, s * .45, -s * .08, s * .47, s * .28)
        ..quadraticBezierTo(s * .48, s * _base, s * .34, s * _base)
        ..close(),
      eyeY: s * .1,
    ),
    CharacterShape.hexagon => (
      path: _roundedPolygon(<Offset>[
        for (int i = 0; i < 6; i++)
          Offset.fromDirection(i * math.pi / 3, s * .46).translate(0, s * .02),
      ], s * .09),
      eyeY: -s * .01,
    ),
    CharacterShape.pebble => (
      path: Path()
        ..moveTo(-s * .02, -s * .36)
        ..cubicTo(s * .3, -s * .38, s * .46, -s * .12, s * .44, s * .1)
        ..cubicTo(s * .42, s * .34, s * .2, s * _base, -s * .02, s * _base)
        ..cubicTo(-s * .3, s * _base, -s * .46, s * .28, -s * .44, s * .04)
        ..cubicTo(-s * .42, -s * .2, -s * .3, -s * .34, -s * .02, -s * .36)
        ..close(),
      eyeY: s * .01,
    ),
  };

  /// The polygon through [corners], each corner rounded by [radius].
  static Path _roundedPolygon(List<Offset> corners, double radius) {
    Offset toward(Offset from, Offset to, double distance) =>
        from +
        (to - from) /
            (to - from).distance *
            math.min(distance, (to - from).distance / 2);
    final int count = corners.length;
    final Path path = Path();
    for (int i = 0; i < count; i++) {
      final Offset corner = corners[i];
      final Offset start = toward(
        corner,
        corners[(i + count - 1) % count],
        radius,
      );
      final Offset end = toward(corner, corners[(i + 1) % count], radius);
      i == 0
          ? path.moveTo(start.dx, start.dy)
          : path.lineTo(start.dx, start.dy);
      path.quadraticBezierTo(corner.dx, corner.dy, end.dx, end.dy);
    }
    return path..close();
  }

  /// The eyes by style: half the gap between them, their size and glint.
  static ({double apart, double width, double height, double glint}) _eyeShape(
    CharacterEyes eyes,
    double s,
  ) => switch (eyes) {
    CharacterEyes.classic => (
      apart: s * .1,
      width: s * .07,
      height: s * .1,
      glint: s * .013,
    ),
    CharacterEyes.dots => (
      apart: s * .1,
      width: s * .05,
      height: s * .05,
      glint: 0,
    ),
    CharacterEyes.big => (
      apart: s * .12,
      width: s * .1,
      height: s * .115,
      glint: s * .024,
    ),
    CharacterEyes.shy => (
      apart: s * .065,
      width: s * .045,
      height: s * .06,
      glint: 0,
    ),
    CharacterEyes.sleepy => (
      apart: s * .1,
      width: s * .08,
      height: s * .1,
      glint: 0,
    ),
    CharacterEyes.sparkle => (
      apart: s * .105,
      width: s * .08,
      height: s * .105,
      glint: s * .018,
    ),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = size.center(Offset.zero);
    final double happy = mood.value;
    final double up = math.sin(math.pi * hop.value);
    final double open = 1 - math.sin(math.pi * blink.value);
    final double swell = .012 * (breath.value * 2 - 1);
    // Squashed on take-off and landing, stretched in the air.
    final double stretch = .05 * math.sin(2 * math.pi * hop.value);
    // A poke squashes it wide, then it wobbles back.
    final double poke =
        .1 * math.sin(math.pi * 2.5 * squish.value) * (1 - squish.value);

    final _Body body = _bodyOf(look.shape, s);
    canvas
      ..save()
      // Scaled about its base, so the body grows from the ground.
      ..translate(c.dx, c.dy + s * _base - up * s * .1)
      ..scale(
        1 - swell - stretch * .5 + poke,
        1 + swell + stretch - poke + talk.value * .01,
      )
      ..translate(0, -s * _base)
      ..drawPath(
        body.path,
        outline
            ? (Paint()
                ..color = look.color
                ..style = PaintingStyle.stroke
                ..strokeWidth = s * .045
                ..strokeJoin = StrokeJoin.round)
            : (Paint()..color = look.color),
      );

    if (!bare) {
      _paintEyes(canvas, s, body.eyeY, happy, open);
      _paintMouth(
        canvas,
        s,
        body.eyeY + s * .135,
        math.max(happy, _restingSmile),
      );
    }
    canvas.restore();
  }

  void _paintEyes(
    Canvas canvas,
    double s,
    double y,
    double happy,
    double open,
  ) {
    final ({double apart, double width, double height, double glint}) shape =
        _eyeShape(look.eyes, s);
    final Paint ink = Paint()..color = _ink;
    final Paint glint = Paint()..color = const Color(0xFFFFFFFF);
    final Paint arc = Paint()
      ..color = _ink.withValues(alpha: happy.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .032
      ..strokeCap = StrokeCap.round;
    final Offset glanceAt = gaze.at(glance.value) * s;
    for (final double side in <double>[-1, 1]) {
      final Offset eye = Offset(side * shape.apart, y) + glanceAt;
      final double height = shape.height * open * (1 - happy);
      if (height > .5) {
        final Rect oval = Rect.fromCenter(
          center: eye,
          width: shape.width,
          height: height,
        );
        if (look.eyes == CharacterEyes.sleepy) {
          // A heavy lid: only the lower part of the eye shows.
          final double lid = eye.dy - height * .1;
          canvas
            ..save()
            ..clipRect(
              Rect.fromLTRB(
                oval.left - 2,
                lid,
                oval.right + 2,
                oval.bottom + 2,
              ),
            )
            ..drawOval(oval, ink)
            ..restore()
            ..drawLine(
              Offset(oval.left - s * .008, lid),
              Offset(oval.right + s * .008, lid),
              Paint()
                ..color = _ink
                ..strokeWidth = s * .022
                ..strokeCap = StrokeCap.round,
            );
        } else {
          canvas.drawOval(oval, ink);
        }
        if (shape.glint > 0 && !outline) {
          // The glint shows where the eye looks: high in the middle when it
          // looks at the user, towards the edge it glances to.
          final Offset toward = Offset(
            (glanceAt.dx / (s * _gazeReach)).clamp(-1, 1),
            (glanceAt.dy / (s * _gazeReach)).clamp(-1, 1),
          );
          void drawGlint(Offset rest, double radius, double follow) {
            final double a = shape.width / 2 - radius;
            final double b = height / 2 - radius;
            // The glint rests high, so looking down it travels the whole
            // way to the bottom edge, not just as far as it moves up.
            final double dy = toward.dy > 0
                ? (b - rest.dy) * toward.dy * follow
                : toward.dy * b * follow * .7;
            final Offset? inside = _withinEye(
              rest + Offset(toward.dx * a * follow, dy),
              a,
              b,
            );
            if (inside != null) canvas.drawCircle(eye + inside, radius, glint);
          }

          drawGlint(Offset(0, -height * .2), shape.glint, .9);
          if (look.eyes == CharacterEyes.sparkle ||
              look.eyes == CharacterEyes.big) {
            drawGlint(Offset(0, height * .24), shape.glint * .45, .45);
          }
        }
      }
      if (happy > .05) {
        canvas.drawArc(
          Rect.fromCenter(
            center: eye.translate(0, s * .015),
            width: shape.width + s * .025,
            height: s * .075,
          ),
          math.pi,
          math.pi,
          false,
          arc,
        );
      }
    }
  }

  /// [offset] from an eye's centre pulled back inside the ellipse of
  /// half-axes [a] and [b], where a glint of that margin fits whole; null
  /// when none fits (a blink).
  static Offset? _withinEye(Offset offset, double a, double b) {
    if (a <= 0 || b <= 0) return null;
    final double reach = math.sqrt(
      math.pow(offset.dx / a, 2) + math.pow(offset.dy / b, 2),
    );
    return reach <= 1 ? offset : offset / reach;
  }

  void _paintMouth(Canvas canvas, double s, double y, double happy) {
    final Paint ink = Paint()..color = _ink;
    final Paint line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .03
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (speaking) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, y + s * .01),
          width: s * .07,
          height: s * .018 + s * .06 * talk.value,
        ),
        ink,
      );
      return;
    }
    switch (look.mouth) {
      case CharacterMouth.simple:
        canvas.drawPath(
          Path()
            ..moveTo(-s * .045, y)
            ..quadraticBezierTo(0, y + s * .075 * happy, s * .045, y),
          line,
        );
      case CharacterMouth.cat:
        final double dip = s * (.035 + .02 * happy);
        canvas.drawPath(
          Path()
            ..moveTo(-s * .065, y - s * .005)
            ..quadraticBezierTo(-s * .033, y + dip, 0, y)
            ..quadraticBezierTo(s * .033, y + dip, s * .065, y - s * .005),
          line,
        );
      case CharacterMouth.open:
        final double width = s * (.05 + .06 * happy);
        final double depth = s * (.05 + .035 * happy);
        canvas.drawPath(
          Path()
            ..moveTo(-width / 2, y)
            ..quadraticBezierTo(0, y - depth * (1 - happy) * .9, width / 2, y)
            ..quadraticBezierTo(0, y + depth * 1.6, -width / 2, y)
            ..close(),
          ink,
        );
      case CharacterMouth.tiny:
        if (happy < .4) {
          canvas.drawCircle(Offset(0, y + s * .01), s * .014, ink);
        } else {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(0, y),
              width: s * .05,
              height: s * .04,
            ),
            .1 * math.pi,
            .8 * math.pi,
            false,
            line,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_CharacterPainter oldDelegate) =>
      look != oldDelegate.look ||
      speaking != oldDelegate.speaking ||
      outline != oldDelegate.outline ||
      bare != oldDelegate.bare;
}
