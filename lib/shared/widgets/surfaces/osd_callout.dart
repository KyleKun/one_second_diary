import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// What a neutral [OsdCallout] is about.
enum OsdCalloutKind { info, warning, error }

/// Callouts and tip cards.
///
/// - [OsdCallout.neutral]: a glyph by `kind`, then text (3 lines max).
/// - [OsdCallout.accent]: an accent-tinted card with a filled glyph and
///   lines of text (bold runs as `TextSpan`s).
/// - [OsdCallout.banner]: a red-tinted banner with a title, a body and a
///   link pill.
///
/// Each constructor builds its own private widget, which holds only the
/// fields its variant needs.
abstract class OsdCallout extends StatelessWidget {
  const OsdCallout._({super.key});

  const factory OsdCallout.neutral({
    Key? key,
    required String text,
    OsdCalloutKind kind,
  }) = _NeutralCallout;

  /// Each of [lines] is a `TextSpan` that may hold bold runs.
  const factory OsdCallout.accent({
    Key? key,
    required IconData icon,
    required Color accent,
    required Color tint,
    required List<InlineSpan> lines,
  }) = _AccentCallout;

  const factory OsdCallout.banner({
    Key? key,
    required String title,
    required String text,
    required String actionLabel,
    VoidCallback? onAction,
    IconData icon,
  }) = _BannerCallout;

  static const Key surfaceKey = Key('osdCallout.surface');

  /// The banner's link pill.
  static const Key actionKey = Key('osdCallout.action');
}

class _NeutralCallout extends OsdCallout {
  const _NeutralCallout({
    super.key,
    required this.text,
    this.kind = OsdCalloutKind.info,
  }) : super._();

  final String text;
  final OsdCalloutKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(OsdRadius.r16);
    final (glyph, color) = switch (kind) {
      OsdCalloutKind.info => (OsdIcons.info, colors.mu),
      OsdCalloutKind.warning => (OsdIcons.warning, colors.yellowInk),
      OsdCalloutKind.error => (OsdIcons.error, colors.red),
    };
    return LightHairline(
      radius: radius,
      child: DecoratedBox(
        key: OsdCallout.surfaceKey,
        decoration: BoxDecoration(color: colors.card, borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            spacing: 12,
            children: <Widget>[
              OsdIcon(glyph, color: color),
              Expanded(
                child: Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.body14.copyWith(
                    height: 1.4,
                    color: colors.d2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentCallout extends OsdCallout {
  const _AccentCallout({
    super.key,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.lines,
  }) : super._();

  final IconData icon;
  final Color accent;
  final Color tint;
  final List<InlineSpan> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typography.body14Loose.copyWith(color: colors.tx);
    return DecoratedBox(
      key: OsdCallout.surfaceKey,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(OsdRadius.r18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            OsdIcon(icon, fill: 1, color: accent),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: <Widget>[
                  for (final line in lines)
                    Text.rich(
                      TextSpan(style: style, children: <InlineSpan>[line]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCallout extends OsdCallout {
  const _BannerCallout({
    super.key,
    required this.title,
    required this.text,
    required this.actionLabel,
    this.onAction,
    this.icon = OsdIcons.notificationsOff,
  }) : super._();

  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return DecoratedBox(
      key: OsdCallout.surfaceKey,
      decoration: BoxDecoration(
        color: OsdTints.redTint12,
        borderRadius: BorderRadius.circular(OsdRadius.r18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            OsdIcon(icon, fill: 1, color: colors.red),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: <Widget>[
                  Text(
                    title,
                    style: typography.rowTitleStrong.copyWith(color: colors.tx),
                  ),
                  Text(
                    text,
                    style: typography.rowSubtitle.copyWith(color: colors.mu),
                  ),
                  const SizedBox(height: 4),
                  OsdPressable(
                    key: OsdCallout.actionKey,
                    onTap: onAction,
                    pressScale: OsdPressScale.button.scale,
                    borderRadius: BorderRadius.circular(OsdRadius.r10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.sel,
                        borderRadius: BorderRadius.circular(OsdRadius.r10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          actionLabel,
                          style: typography.label14Strong.copyWith(
                            color: colors.tx,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
