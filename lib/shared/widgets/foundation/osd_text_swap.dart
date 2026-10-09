import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// One line of text that changes letter by letter: the old text's letters
/// lift, blur and fade away one after the other, then the new one's come
/// up from below, sharpening as they land (the staggered blur, fade and
/// slide of text animation packages, drawn here from the laid-out
/// paragraph, so the letters keep their kerning and land exactly where the
/// text rests).
///
/// The two never show sharp at once, unlike a crossfade. At rest it is a
/// plain `Text` ([textKey], selectable by tests and read by screen
/// readers, which get the new text at once). Under reduced motion the old
/// text fades out, then the new one fades in.
class OsdTextSwap extends StatefulWidget {
  const OsdTextSwap(
    this.text, {
    super.key,
    required this.style,
    this.textKey,
    this.textScaler,
    this.overflow,
  });

  final String text;

  final TextStyle style;

  /// The key of the `Text`.
  final Key? textKey;

  final TextScaler? textScaler;

  /// What a text too wide for its box does; an ellipsis is drawn while it
  /// changes too.
  final TextOverflow? overflow;

  /// The whole change.
  static const Duration duration = Duration(milliseconds: 460);

  @override
  State<OsdTextSwap> createState() => _OsdTextSwapState();
}

class _OsdTextSwapState extends State<OsdTextSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: OsdTextSwap.duration,
  )..addStatusListener(_onStatus);

  /// The text leaving; null at rest.
  String? _leaving;

  @override
  void didUpdateWidget(OsdTextSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text) return;
    _leaving = oldWidget.text;
    _swap
      ..duration = OsdMotion.d(context, OsdTextSwap.duration)
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _leaving != null) {
      setState(() => _leaving = null);
    }
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? leaving = _leaving;
    final TextScaler scaler =
        widget.textScaler ?? MediaQuery.textScalerOf(context);
    return CustomPaint(
      foregroundPainter: leaving == null
          ? null
          : _SwapPainter(
              progress: _swap,
              from: leaving,
              to: widget.text,
              style: widget.style,
              textScaler: scaler,
              textDirection: Directionality.of(context),
              locale: Localizations.maybeLocaleOf(context),
              ellipsis: widget.overflow == TextOverflow.ellipsis,
              reduced: OsdMotion.reduced(context),
            ),
      // The text itself keeps its place (and its size) meanwhile.
      child: Opacity(
        opacity: leaving == null ? 1 : 0,
        child: Text(
          widget.text,
          key: widget.textKey,
          maxLines: 1,
          softWrap: false,
          overflow: widget.overflow,
          textScaler: scaler,
          style: widget.style,
        ),
      ),
    );
  }
}

/// The two texts mid-change, one letter at a time.
class _SwapPainter extends CustomPainter {
  _SwapPainter({
    required this.progress,
    required this.from,
    required this.to,
    required this.style,
    required this.textScaler,
    required this.textDirection,
    required this.locale,
    required this.ellipsis,
    required this.reduced,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final String from;
  final String to;
  final TextStyle style;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Locale? locale;
  final bool ellipsis;
  final bool reduced;

  static final double _total = OsdTextSwap.duration.inMilliseconds.toDouble();

  /// A letter takes this long to leave, and the next one starts
  /// [_outStagger] after it (sooner in a long text: the last one starts
  /// within [_outSpread]).
  static final double _outLength = 150 / _total;
  static final double _outStagger = 12 / _total;
  static final double _outSpread = 90 / _total;

  /// The new letters start at [_inStart], each landing over [_inLength].
  static final double _inStart = 130 / _total;
  static final double _inLength = 240 / _total;
  static final double _inStagger = 22 / _total;
  static final double _inSpread = 90 / _total;

  /// How far a letter travels, as a share of the font size.
  static const double _rise = .28;

  /// The blur of a letter out of place, as a share of the font size.
  static const double _blur = .14;

  TextPainter? _fromPainter;
  TextPainter? _toPainter;
  double? _laidOutFor;

  TextPainter _layOut(String text, double width) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: 1,
    ellipsis: ellipsis ? '…' : null,
  )..layout(maxWidth: ellipsis ? width : double.infinity);

  @override
  void paint(Canvas canvas, Size size) {
    if (_laidOutFor != size.width) {
      _fromPainter?.dispose();
      _toPainter?.dispose();
      _fromPainter = _layOut(from, size.width);
      _toPainter = _layOut(to, size.width);
      _laidOutFor = size.width;
    }
    final double t = progress.value;
    _paint(canvas, size, _fromPainter!, from, t, entering: false);
    _paint(canvas, size, _toPainter!, to, t, entering: true);
  }

  void _paint(
    Canvas canvas,
    Size size,
    TextPainter painter,
    String text,
    double t, {
    required bool entering,
  }) {
    final Offset origin = Offset(
      textDirection == TextDirection.rtl ? size.width - painter.width : 0,
      (size.height - painter.height) / 2,
    );
    if (reduced) {
      // Out over the first half, in over the second.
      final double alpha = entering
          ? ((t - .5) * 2).clamp(0, 1)
          : (1 - t * 2).clamp(0, 1);
      if (alpha <= 0) return;
      canvas.saveLayer(
        origin & painter.size,
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      painter.paint(canvas, origin);
      canvas.restore();
      return;
    }
    final double fontSize = textScaler.scale(style.fontSize ?? 14);
    final double rise = fontSize * _rise;
    final double blur = fontSize * _blur;
    final List<String> letters = text.characters.toList();
    final int gaps = math.max(1, letters.length - 1);
    final double stagger = entering
        ? math.min(_inStagger, _inSpread / gaps)
        : math.min(_outStagger, _outSpread / gaps);
    int offset = 0;
    for (int i = 0; i < letters.length; i++) {
      final int start = offset;
      offset += letters[i].length;
      final double begin = (entering ? _inStart : 0) + i * stagger;
      final double length = entering ? _inLength : _outLength;
      final double p = ((t - begin) / length).clamp(0, 1);
      // 0 in place, 1 out of place.
      final double away = entering
          ? 1 - Curves.easeOutCubic.transform(p)
          : Curves.easeInCubic.transform(p);
      if (away >= 1) continue;
      final List<TextBox> boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: offset),
      );
      if (boxes.isEmpty) continue;
      Rect letter = boxes.first.toRect();
      for (final TextBox box in boxes.skip(1)) {
        letter = letter.expandToInclude(box.toRect());
      }
      letter = letter.shift(origin);
      final double dy = (entering ? rise : -rise) * away;
      final double sigma = blur * away;
      final Paint layer = Paint()..color = Color.fromRGBO(0, 0, 0, 1 - away);
      if (sigma > .05) {
        layer.imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        );
      }
      canvas
        ..saveLayer(letter.translate(0, dy).inflate(sigma * 3 + 2), layer)
        ..translate(0, dy)
        ..clipRect(letter)
        ..save();
      painter.paint(canvas, origin);
      canvas
        ..restore()
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_SwapPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.style != style ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.locale != locale ||
      oldDelegate.ellipsis != ellipsis ||
      oldDelegate.reduced != reduced;
}
