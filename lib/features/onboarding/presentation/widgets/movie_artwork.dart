import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_artwork.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_shadows.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The second intro slide's artwork: a tilted strip of film across the
/// card, the coral play badge on it, and the paper pill "365 days → 12 min
/// movie".
///
/// The pill says what a year of clips makes: 365 clips of the default
/// length ([PrefKeys.recordingSeconds]), in minutes. Screen readers hear
/// it as one label ("365 days, 12 min movie"); the film and the badge are
/// decorative.
///
/// Entrance: the film slides in along itself, the badge pops, the pill
/// rises and counts its days up from 0, then its movie length comes in.
/// While [running], the film runs through like film in a projector: only
/// while the slide rests on screen (not while dragged, never behind
/// another page, which turns tickers off, nor under reduced motion).
class MovieArtwork extends StatelessWidget {
  const MovieArtwork({
    super.key,
    required this.entrance,
    required this.running,
    required this.textDirection,
  });

  static const Key pillKey = Key('movieArtwork.pill');

  static const Key daysKey = Key('movieArtwork.days');

  /// How long the artwork takes to come in.
  static const Duration entranceLength = Duration(milliseconds: 1400);

  /// A year of clips.
  static const int days = 365;

  /// 0 → 1 over [entranceLength].
  final Animation<double> entrance;

  final bool running;

  /// The reading direction around the artwork: the pill follows it.
  final TextDirection textDirection;

  /// How far the part of the entrance from [start], [length] long, has
  /// come at [value], eased by [curve].
  static double _at(
    double value,
    Duration start,
    Duration length, [
    Curve curve = Curves.linear,
  ]) => OnboardingMotion.span(
    start,
    length,
    entranceLength,
    curve: curve,
  ).transform(value);

  @override
  Widget build(BuildContext context) {
    final Widget film = ExcludeSemantics(child: _FilmBand(running: running));
    const Widget badge = ExcludeSemantics(child: _PlayBadge());
    final Widget pill = Directionality(
      textDirection: textDirection,
      child: _PaperPill(entrance: entrance),
    );
    return AnimatedBuilder(
      animation: entrance,
      builder: (BuildContext context, _) {
        final double t = entrance.value;
        final double band = _at(
          t,
          Duration.zero,
          OnboardingMotion.bandIn,
          Curves.easeOutCubic,
        );
        final double pop = _at(
          t,
          OnboardingMotion.badgeDelay,
          OnboardingMotion.badgeIn,
          Curves.easeOutBack,
        );
        final double shown = _at(
          t,
          OnboardingMotion.badgeDelay,
          OnboardingMotion.badgeFade,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // The band overhangs the card by 30 each side; the card clips it.
            Positioned(
              left: -30,
              top: 120,
              width: 410,
              height: 116,
              child: Transform.rotate(
                angle: -7 * math.pi / 180,
                child: Opacity(
                  opacity: band.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(OnboardingMotion.bandSlide * (1 - band), 0),
                    child: film,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 139,
              top: 132,
              width: 72,
              height: 72,
              child: Opacity(
                opacity: shown,
                child: Transform.scale(
                  scale:
                      OnboardingMotion.badgeScale +
                      (1 - OnboardingMotion.badgeScale) * pop,
                  child: badge,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 44,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 318),
                  child: FittedBox(fit: BoxFit.scaleDown, child: pill),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The film: a band whose strip carries drawn sprocket holes along both
/// edges, with its shadow.
class _FilmBand extends StatefulWidget {
  const _FilmBand({required this.running});

  final bool running;

  @override
  State<_FilmBand> createState() => _FilmBandState();
}

class _FilmBandState extends State<_FilmBand>
    with SingleTickerProviderStateMixin {
  /// One hole and its gap go by in this long: the film loops by it.
  static final Duration _loop = Duration(
    microseconds:
        (_SprocketPainter.period /
                OnboardingMotion.marqueeSpeed *
                Duration.microsecondsPerSecond)
            .round(),
  );

  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: _loop,
  );

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x4D000000),
    offset: Offset(0, 18),
    blurRadius: OsdShadows.filmBandBlur,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(_FilmBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    if (widget.running && OsdMotion.loopsEnabled(context)) {
      if (!_run.isAnimating) unawaited(_run.repeat());
    } else if (_run.isAnimating) {
      _run.stop();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: OsdArtwork.film,
      boxShadow: <BoxShadow>[_shadow],
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 76,
          width: double.infinity,
          // Only the strip repaints while the film runs.
          child: RepaintBoundary(
            child: CustomPaint(painter: _SprocketPainter(run: _run)),
          ),
        ),
      ),
    ),
  );
}

/// Two rows of rounded sprocket holes, moving toward the start of the
/// strip as [run] goes round.
class _SprocketPainter extends CustomPainter {
  _SprocketPainter({required this.run}) : super(repaint: run);

  final Animation<double> run;

  /// A hole and the gap after it.
  static const double period = 22;

  static const Size _hole = Size(10, 14);
  static const double _inset = 4;

  /// Artwork: the same in both themes.
  static const Color _holeColor = Color(0xFF2A2826);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = _holeColor;
    final double shift = -run.value * period;
    for (double x = shift; x < size.width; x += period) {
      for (final double y in <double>[
        _inset,
        size.height - _inset - _hole.height,
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset(x, y) & _hole,
            const Radius.circular(OsdRadius.r2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SprocketPainter oldDelegate) => oldDelegate.run != run;
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x59000000),
    offset: Offset(0, 10),
    blurRadius: OsdShadows.polaroidBlur,
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.co,
      shape: BoxShape.circle,
      boxShadow: const <BoxShadow>[_shadow],
    ),
    child: Center(
      child: OsdIcon(
        OsdIcons.playArrow,
        size: 40,
        fill: 1,
        color: context.colors.onCo,
      ),
    ),
  );
}

/// "365 days → 12 min movie" on paper: it rises in, counts its days up
/// while keeping the final width (Yusei Magic has proportional digits),
/// then shows the movie length.
class _PaperPill extends StatefulWidget {
  const _PaperPill({required this.entrance});

  final Animation<double> entrance;

  @override
  State<_PaperPill> createState() => _PaperPillState();
}

class _PaperPillState extends State<_PaperPill> {
  late NumberFormat _numbers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The language's, made once, never in build.
    _numbers = LocaleFormats.of(context).numbers;
  }

  String _days(int count) => Strings.dayCount(count, format: _numbers);

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.typography.displayPill.copyWith(
      color: OsdArtwork.ink,
    );
    final String allDays = _days(MovieArtwork.days);
    final String length = Strings.onboardingMovieLength(
      minutes: MovieArtwork.days * PrefKeys.recordingSeconds.defaultValue ~/ 60,
    );
    final double from = Directionality.of(context) == TextDirection.rtl
        ? OnboardingMotion.lengthSlide
        : -OnboardingMotion.lengthSlide;
    final Widget lengthRun = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: <Widget>[
        const OsdIcon(OsdIcons.arrowForward, size: 18, color: OsdArtwork.ink),
        Text(length, style: style),
      ],
    );
    // The final count keeps the room, so the pill never jitters.
    final Widget room = Opacity(opacity: 0, child: Text(allDays, style: style));
    return Semantics(
      container: true,
      label: '$allDays, $length',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: widget.entrance,
          builder: (BuildContext context, _) {
            final double t = widget.entrance.value;
            final double rise = MovieArtwork._at(
              t,
              OnboardingMotion.pillDelay,
              OnboardingMotion.pillIn,
              Curves.easeOutCubic,
            );
            final double counted = MovieArtwork._at(
              t,
              OnboardingMotion.countDelay,
              OnboardingMotion.countUp,
              Curves.easeOutCubic,
            );
            final double lengthIn = MovieArtwork._at(
              t,
              OnboardingMotion.countDelay + OnboardingMotion.countUp,
              OnboardingMotion.lengthIn,
              Curves.easeOut,
            );
            return Opacity(
              opacity: rise,
              child: Transform.translate(
                offset: Offset(0, OnboardingMotion.pillRise * (1 - rise)),
                child: DecoratedBox(
                  key: MovieArtwork.pillKey,
                  decoration: const ShapeDecoration(
                    color: OsdArtwork.paper,
                    shape: StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: <Widget>[
                        Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: <Widget>[
                            room,
                            Text(
                              _days((MovieArtwork.days * counted).round()),
                              key: MovieArtwork.daysKey,
                              style: style,
                            ),
                          ],
                        ),
                        Opacity(
                          opacity: lengthIn,
                          child: Transform.translate(
                            offset: Offset(from * (1 - lengthIn), 0),
                            child: lengthRun,
                          ),
                        ),
                      ],
                    ),
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
