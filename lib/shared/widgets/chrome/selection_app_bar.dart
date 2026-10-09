import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The selection-mode app bar: a close button, a title ("{n} selected", which
/// ticks up and fades on change) and the [actions] (`OsdIconButton`s; a
/// disabled action uses `fadeWhenDisabled` and keeps its tooltip). In the
/// light theme a line marks the bottom edge.
///
/// Crossfade it with the normal bar at the call site.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    super.key,
    required this.title,
    required this.onClose,
    this.closeTooltip,
    this.actions = const <Widget>[],
  });

  static const Key surfaceKey = Key('selectionAppBar.surface');

  static const Key lineKey = Key('selectionAppBar.line');

  final String title;

  /// Leaves selection mode.
  final VoidCallback onClose;

  /// The close tooltip; the localised "Close" by default.
  final String? closeTooltip;

  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(OsdSizes.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    return ColoredBox(
      key: surfaceKey,
      color: colors.card,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: OsdSizes.appBarHeight,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  spacing: 4,
                  children: <Widget>[
                    OsdIconButton(
                      icon: OsdIcons.close,
                      tooltip:
                          closeTooltip ??
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: onClose,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: OsdMotion.d(context, OsdMotion.countTick),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: <Widget>[...previous, ?current],
                        ),
                        transitionBuilder: (child, animation) {
                          final reduced = OsdMotion.reduced(context);
                          return FadeTransition(
                            opacity: animation,
                            child: reduced
                                ? child
                                : SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, .25),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                          );
                        },
                        child: Semantics(
                          key: ValueKey<String>(title),
                          header: true,
                          liveRegion: true,
                          // A title too wide for the fixed bar scales down
                          // rather than lose its end.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: context.typography.title18Strong.copyWith(
                                color: colors.tx,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              if (light)
                PositionedDirectional(
                  key: lineKey,
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: colors.ln),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
