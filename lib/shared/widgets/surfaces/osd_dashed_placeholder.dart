import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/dashed_border.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A dashed empty panel: a glyph, a title and a hint (2 lines each), then an
/// optional [action]. With [busy] the glyph rotates (static under reduced
/// motion).
class OsdDashedPlaceholder extends StatefulWidget {
  const OsdDashedPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.busy = false,
  });

  static const Key frameKey = Key('osdDashedPlaceholder.frame');

  final IconData icon;

  final String title;

  final String? hint;

  /// A CTA under the text.
  final Widget? action;

  /// Rotates the glyph (importing).
  final bool busy;

  @override
  State<OsdDashedPlaceholder> createState() => _OsdDashedPlaceholderState();
}

class _OsdDashedPlaceholderState extends State<OsdDashedPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(OsdDashedPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.busy && OsdMotion.loopsEnabled(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final hint = widget.hint;
    final action = widget.action;
    return DashedBorder(
      key: OsdDashedPlaceholder.frameKey,
      color: colors.outline,
      borderRadius: BorderRadius.circular(OsdRadius.r20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 196,
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              RotationTransition(
                turns: _spin,
                child: OsdIcon(widget.icon, size: 30, color: colors.fa),
              ),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: typography.buttonNeutral.copyWith(color: colors.tx),
              ),
              if (hint != null)
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: typography.caption13.copyWith(color: colors.mu),
                ),
              if (action != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: action),
            ],
          ),
        ),
      ),
    );
  }
}
