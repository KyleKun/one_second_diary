import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

enum PageDotsStyle {
  /// Onboarding progress: the active dot is coral.
  brand,

  /// Carousels off media: the active dot is TX.
  ink,

  /// Over media: white dots.
  onMedia,
}

/// Page indicator dots: rounded rects that follow the scroll [position]
/// continuously, the width lerping between the inactive and active sizes and
/// the colour between the inactive and active colours.
///
/// Above 7 pages the ink style shows a counter instead ("3 / 12";
/// [counterText] formats it). The dots are decorative: carousels expose their
/// own position; onboarding passes [semanticsLabel] ("Page 1 of 3"), which
/// makes one live-region node.
///
/// With [onTap] a tap on a dot reports its page. A dot's tap target is its
/// column of the indicator: the dot, half the gap on each side and the
/// [padding] above and below it.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.position,
    this.style = PageDotsStyle.ink,
    this.counterText,
    this.semanticsLabel,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  static Key dotKey(int index) =>
      ValueKey<(String, int)>(('pageDots.dot', index));

  static const int _maxDots = 7;

  /// How many pages.
  final int count;

  /// The scroll position in pages (1.5 is halfway from page 2 to page 3).
  final double position;

  final PageDotsStyle style;

  /// Formats the counter from the 1-based page and the count.
  final String Function(int index, int count)? counterText;

  /// A live-region label for the whole indicator.
  final String? semanticsLabel;

  /// A tap on the dot of page [index] (0-based); the counter takes no taps.
  final ValueChanged<int>? onTap;

  /// The space around the indicator, inside its box.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (inactive, active, size, activeWidth, gap) = switch (style) {
      PageDotsStyle.brand => (colors.off, colors.co, 8.0, 22.0, 6.0),
      PageDotsStyle.ink => (colors.off, colors.tx, 8.0, 20.0, 6.0),
      PageDotsStyle.onMedia => (
        OsdMedia.onMediaDotInactive,
        OsdMedia.onMediaDotActive,
        6.0,
        16.0,
        5.0,
      ),
    };
    final Widget indicator;
    if (style == PageDotsStyle.ink && count > _maxDots) {
      final index = position.round().clamp(0, count - 1) + 1;
      final numbers = LocaleFormats.of(context).numbers;
      // A minimum height, never a fixed one: it grows with large text.
      indicator = Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 16),
          child: Center(
            heightFactor: 1,
            widthFactor: 1,
            child: Text(
              counterText?.call(index, count) ??
                  '${numbers.format(index)} / ${numbers.format(count)}',
              maxLines: 1,
              style: context.typography.label13.copyWith(color: colors.mu),
            ),
          ),
        ),
      );
    } else {
      final tap = onTap;
      // Tappable dots take their half of the gaps, so the targets touch.
      final around = EdgeInsets.only(
        left: tap == null ? 0 : gap / 2,
        right: tap == null ? 0 : gap / 2,
        top: padding.top,
        bottom: padding.bottom,
      );
      indicator = Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: tap == null ? gap : 0,
          children: <Widget>[
            for (var i = 0; i < count; i++)
              Builder(
                builder: (context) {
                  final focus = 1 - (position - i).abs().clamp(0, 1).toDouble();
                  final dot = Padding(
                    padding: around,
                    child: SizedBox(
                      width: lerpDouble(size, activeWidth, focus),
                      height: size,
                      child: DecoratedBox(
                        key: dotKey(i),
                        decoration: BoxDecoration(
                          color: Color.lerp(inactive, active, focus),
                          borderRadius: BorderRadius.circular(size / 2),
                        ),
                      ),
                    ),
                  );
                  return tap == null
                      ? dot
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: () => tap(i),
                          child: dot,
                        );
                },
              ),
          ],
        ),
      );
    }
    final label = semanticsLabel;
    return label == null
        ? ExcludeSemantics(child: indicator)
        : Semantics(
            container: true,
            liveRegion: true,
            label: label,
            child: ExcludeSemantics(child: indicator),
          );
  }
}
