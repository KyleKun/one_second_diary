import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Saved" pill on a saved clip, placed by the preview: a check and the
/// [label], the same in both themes.
///
/// While [saving], a spinner replaces the check. With [animateIn] it lands
/// with a pop while the check fills (the page plays the haptic). Decorative:
/// the preview is the semantics node.
class SavedBadge extends StatefulWidget {
  const SavedBadge({
    super.key,
    required this.label,
    this.saving = false,
    this.animateIn = false,
  });

  static const Key surfaceKey = Key('savedBadge.surface');

  /// "Saved" or "Saving…".
  final String label;

  /// Whether the save is still running.
  final bool saving;

  /// Whether the badge lands when first shown (right after a save).
  final bool animateIn;

  @override
  State<SavedBadge> createState() => _SavedBadgeState();
}

class _SavedBadgeState extends State<SavedBadge>
    with SingleTickerProviderStateMixin {
  static const Duration _land = Duration(milliseconds: 280);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _land,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animateIn &&
        _controller.value == 1 &&
        !_controller.isAnimating &&
        !OsdMotion.reduced(context)) {
      _controller.value = 0;
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: ScaleTransition(
        // A CurveTween keeps no listener: nothing is left per build.
        scale: _controller.drive(
          Tween<double>(
            begin: .85,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
        ),
        child: DecoratedBox(
          key: SavedBadge.surfaceKey,
          decoration: BoxDecoration(
            color: OsdMedia.scrim55,
            borderRadius: BorderRadius.circular(OsdRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: <Widget>[
                SizedBox.square(
                  dimension: 17,
                  child: widget.saving
                      ? const Center(
                          child: OsdSpinner(size: 14, color: OsdMedia.onMedia),
                        )
                      : AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => OsdIcon(
                            OsdIcons.checkCircle,
                            size: 17,
                            fill: _controller.value,
                            color: colors.green,
                          ),
                        ),
                ),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: OsdTextScale.scalerFor(
                      context,
                      OsdTextScaleRole.mediaChrome,
                    ),
                    style: context.typography.label13.copyWith(
                      color: OsdMedia.onMedia,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
