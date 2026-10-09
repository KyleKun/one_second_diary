import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/policy/stamp_filter.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A stamp's text in the clip editor: the burned stamp's [style] in [color]
/// with the contrast outline, never scaled with the text size, decorative.
///
/// A [burned] stamp's outline is the export's: the RGB inverse of the
/// colour, [outlineWidth] wide when given (the export's `borderw` at the
/// preview's scale, which does not change with the text size), else
/// `StampFilter.outlineWidthPx` for every `StampFilter.fontSizePx` of
/// type, so at the preview's scale as thin as it is in the saved clip.
/// The soft subtitle ([burned] false) keeps `OsdMedia.stampShadow`, as the
/// player shows it.
///
/// A new colour lerps and the outline fades in or out over [change], in
/// one animation. The shared `DateStamp` takes the outline as a flag,
/// which can't fade.
class AnimatedStampText extends StatelessWidget {
  const AnimatedStampText(
    this.text, {
    super.key,
    required this.style,
    required this.color,
    required this.outline,
    this.outlineWidth,
    this.burned = true,
    this.maxLines = 1,
    this.textAlign,
  });

  /// How long a new colour or outline takes.
  static const Duration change = Duration(milliseconds: 200);

  final String text;

  final TextStyle style;

  final Color color;

  /// Whether the contrast outline is on.
  final bool outline;

  /// The burned outline's width in the preview's px; null keeps it in
  /// step with the type as a medium stamp's is.
  final double? outlineWidth;

  /// Whether ffmpeg burns this text (a date, a place), so its outline is
  /// the export's; false for the soft subtitle.
  final bool burned;

  final int maxLines;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => _AnimatedStamp(
    text: text,
    style: style,
    color: color,
    outline: outline,
    outlineWidth: outlineWidth,
    burned: burned,
    maxLines: maxLines,
    textAlign: textAlign,
    duration: OsdMotion.d(context, change),
    curve: OsdMotion.curve(context, OsdMotion.fastCurve),
  );
}

class _AnimatedStamp extends ImplicitlyAnimatedWidget {
  const _AnimatedStamp({
    required this.text,
    required this.style,
    required this.color,
    required this.outline,
    required this.outlineWidth,
    required this.burned,
    required this.maxLines,
    required this.textAlign,
    required super.duration,
    required super.curve,
  });

  final String text;
  final TextStyle style;
  final Color color;
  final bool outline;
  final double? outlineWidth;
  final bool burned;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  AnimatedWidgetBaseState<_AnimatedStamp> createState() =>
      _AnimatedStampState();
}

class _AnimatedStampState extends AnimatedWidgetBaseState<_AnimatedStamp> {
  ColorTween? _color;
  Tween<double>? _outline;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _color =
        visitor(
              _color,
              widget.color,
              (value) => ColorTween(begin: value as Color),
            )
            as ColorTween?;
    _outline =
        visitor(
              _outline,
              widget.outline ? 1.0 : 0.0,
              (value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color!.evaluate(animation)!;
    final double outline = _outline!.evaluate(animation);
    return ExcludeSemantics(
      child: Text(
        widget.text,
        maxLines: widget.maxLines,
        // drawtext never cuts a burned stamp short.
        overflow: widget.burned ? TextOverflow.visible : TextOverflow.ellipsis,
        softWrap: widget.maxLines > 1,
        textAlign: widget.textAlign,
        textScaler: TextScaler.noScaling,
        style: widget.style.copyWith(
          color: color,
          shadows: _faded(
            widget.burned
                ? _burnedOutline(
                    color,
                    widget.outlineWidth ??
                        StampFilter.outlineWidthPx *
                            widget.style.fontSize! /
                            StampFilter.fontSizePx,
                  )
                : OsdMedia.stampShadow,
            outline,
          ),
        ),
      ),
    );
  }

  /// The export's outline (`StampFilter`: `borderw` 1 in the colour's RGB
  /// inverse), [width] wide: a sharp ring of eight shadows.
  static List<Shadow> _burnedOutline(Color color, double width) {
    final Color inverse = Color(
      0xFF000000 | ((color.toARGB32() & 0xFFFFFF) ^ 0xFFFFFF),
    );
    return <Shadow>[
      for (final Offset direction in _directions)
        Shadow(color: inverse, offset: direction * width),
    ];
  }

  static const double _diagonal = 0.7071067811865476;
  static const List<Offset> _directions = <Offset>[
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
    Offset(_diagonal, _diagonal),
    Offset(-_diagonal, _diagonal),
    Offset(_diagonal, -_diagonal),
    Offset(-_diagonal, -_diagonal),
  ];

  /// [shadows] at [strength] (the outline fading in or out).
  static List<Shadow>? _faded(List<Shadow> shadows, double strength) {
    if (strength <= 0) return null;
    if (strength >= 1) return shadows;
    return <Shadow>[
      for (final Shadow shadow in shadows)
        Shadow(
          color: shadow.color.withValues(alpha: shadow.color.a * strength),
          offset: shadow.offset,
          blurRadius: shadow.blurRadius,
        ),
    ];
  }
}
