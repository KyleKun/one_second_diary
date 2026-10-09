import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "can't play" state of a media box: a `broken_image` glyph, a title
/// and a body, filling the box. The caller hides play, expand and volume
/// controls.
class PlayerErrorBlock extends StatelessWidget {
  const PlayerErrorBlock({super.key, required this.title, this.body});

  static const Key surfaceKey = Key('playerErrorBlock.surface');

  final String title;

  final String? body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final body = this.body;
    return ColoredBox(
      key: surfaceKey,
      color: colors.c2,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              OsdIcon(OsdIcons.brokenImage, size: 30, color: colors.fa),
              Text(
                title,
                textAlign: TextAlign.center,
                style: typography.buttonNeutral.copyWith(color: colors.tx),
              ),
              if (body != null)
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: typography.caption13.copyWith(color: colors.mu),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
