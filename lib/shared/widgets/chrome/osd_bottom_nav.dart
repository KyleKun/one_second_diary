import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_animated_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A tab of [OsdBottomNav].
@immutable
class OsdNavDestination {
  const OsdNavDestination({required this.icon, required this.label});

  /// The glyph (outlined when inactive, filled when active).
  final IconData icon;

  final String label;
}

/// The shell's bottom navigation: a floating capsule of equal tabs. One
/// highlight slides behind the active tab's filled icon, which rises to make
/// room for its label; the other tabs are outlined icons without one.
///
/// Nothing re-lays out while it animates: the highlight, the icons and the
/// label only move or fade.
///
/// Items are buttons with `selected` and a "Tab i of n" hint; every label is
/// in the semantics, shown or not. The nav is the snackbar anchor of the
/// shell.
class OsdBottomNav extends StatelessWidget {
  const OsdBottomNav({
    super.key,
    required this.destinations,
    required this.index,
    required this.onSelect,
    this.onReselect,
  });

  /// The capsule.
  static const Key barKey = Key('osdBottomNav.bar');

  /// The sliding highlight.
  static const Key pillKey = Key('osdBottomNav.pill');

  /// The keyboard focus ring.
  static const Key focusRingKey = Key('osdBottomNav.focusRing');

  static Key itemKey(int index) => ValueKey<String>('osdBottomNav.item.$index');

  static const double _capsuleHeight = 76;
  static const double _sideMargin = 16;
  static const double _padding = 6;

  /// The highlight, centred on the active icon.
  static const Size _pillSize = Size(64, 36);
  static const double _pillTop = 10;

  /// How far the active icon rises from the middle.
  static const double _rise = 10;

  static const double _iconSize = 26;

  static const Duration _slide = Duration(milliseconds: 320);

  final List<OsdNavDestination> destinations;

  /// The active tab.
  final int index;

  /// Called with the tapped tab when it is not the active one.
  final ValueChanged<int> onSelect;

  /// Called when the active tab is tapped again (scroll to top).
  final VoidCallback? onReselect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final count = destinations.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Nothing above the capsule; below it, a margin and the system inset.
    const below = OsdSizes.navContentHeight - _capsuleHeight;
    final floor = below + math.max(OsdSizes.navMinBottomPadding, bottom);
    final radius = BorderRadius.circular(_capsuleHeight / 2);
    return SnackbarAnchor(
      gap: OsdSpace.snackbarAboveNav,
      // Around the capsule the tab shows through.
      child: Padding(
        padding: EdgeInsets.fromLTRB(_sideMargin, 0, _sideMargin, floor),
        child: DecoratedBox(
          key: barKey,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: radius,
            border: Border.all(color: colors.ln),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.sh,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: _capsuleHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _padding),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: FractionallySizedBox(
                          widthFactor: 1 / count,
                          // A translation in slot widths: paint only.
                          child: AnimatedSlide(
                            offset: Offset(
                              (rtl ? -index : index).toDouble(),
                              0,
                            ),
                            duration: OsdMotion.d(context, _slide),
                            curve: OsdMotion.curve(
                              context,
                              Curves.easeOutCubic,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: _pillTop),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: DecoratedBox(
                                  key: pillKey,
                                  decoration: BoxDecoration(
                                    color: colors.pill,
                                    borderRadius: BorderRadius.circular(
                                      _pillSize.height / 2,
                                    ),
                                  ),
                                  child: SizedBox.fromSize(size: _pillSize),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (var i = 0; i < count; i++)
                        Expanded(
                          child: _NavItem(
                            key: itemKey(i),
                            destination: destinations[i],
                            position: i,
                            count: count,
                            selected: i == index,
                            onTap: () {
                              if (i == index) {
                                onReselect?.call();
                              } else {
                                unawaited(OsdHaptic.selection.play());
                                onSelect(i);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.destination,
    required this.position,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final OsdNavDestination destination;
  final int position;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OsdPressable(
    onTap: onTap,
    pressScale: null,
    overlay: OsdPressOverlay.none,
    focusStyle: OsdFocusStyle.custom,
    selected: selected,
    semanticsLabel: destination.label,
    semanticsHint: MaterialLocalizations.of(
      context,
    ).tabLabel(tabIndex: position + 1, tabCount: count),
    excludeChildSemantics: true,
    child: _ItemContent(destination: destination, selected: selected),
  );
}

class _ItemContent extends StatelessWidget {
  const _ItemContent({required this.destination, required this.selected});

  final OsdNavDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    const pill = OsdBottomNav._pillSize;
    const pillTop = OsdBottomNav._pillTop;
    const iconTop = (OsdBottomNav._capsuleHeight - OsdBottomNav._iconSize) / 2;
    final focused = OsdPressable.isFocused(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: OsdMotion.d(context, OsdBottomNav._slide),
      curve: OsdMotion.curve(context, Curves.easeOutCubic),
      builder: (context, t, _) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          if (focused)
            Positioned(
              top: pillTop - 2,
              child: DecoratedBox(
                key: OsdBottomNav.focusRingKey,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pill.height / 2 + 2),
                  border: Border.all(color: colors.tx, width: 2),
                ),
                child: SizedBox(width: pill.width + 4, height: pill.height + 4),
              ),
            ),
          Positioned(
            top: iconTop,
            child: Transform.translate(
              offset: Offset(0, -OsdBottomNav._rise * t),
              child: AnimatedScale(
                scale: OsdPressable.isPressed(context)
                    ? OsdMotion.pressScale(context, OsdPressScale.icon)
                    : 1,
                duration: OsdMotion.d(context, OsdMotion.pressIn),
                child: OsdAnimatedIcon(
                  destination.icon,
                  size: OsdBottomNav._iconSize,
                  fill: selected ? 1 : 0,
                  color: Color.lerp(colors.mu, colors.tx, t),
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            right: 2,
            top: pillTop + pill.height + 3,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 4 * (1 - t)),
                // The slot is fixed: a long label ("Configurações",
                // "Einstellungen") scales down rather than lose its end.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    textScaler: OsdTextScale.scalerFor(
                      context,
                      OsdTextScaleRole.navLabel,
                    ),
                    style: typography.navLabelActive.copyWith(
                      color: colors.tx,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
