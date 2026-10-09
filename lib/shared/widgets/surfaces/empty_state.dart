import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The one empty-state layout: a glyph in a circle, a title (a semantics
/// header), a body, and an optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  static const Key circleKey = Key('emptyState.circle');

  final IconData icon;

  final String title;

  final String? body;

  /// The CTA.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final body = this.body;
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            key: circleKey,
            dimension: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.c2,
              ),
              child: Center(child: OsdIcon(icon, size: 36, color: colors.fa)),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: typography.buttonLarge.copyWith(color: colors.tx),
            ),
          ),
          if (body != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: typography.body14.copyWith(height: 1.4, color: colors.mu),
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}
