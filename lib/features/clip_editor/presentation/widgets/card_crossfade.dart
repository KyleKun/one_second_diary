import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A clip editor card that crossfades when it shows something else: the
/// card for the new [id] fades in over the old one, which stays whole
/// underneath until it is covered, so what both cards show (the surface,
/// the label) never dims.
///
/// The old card sits under the new one, so taps reach the new one only.
class CardCrossfade extends StatelessWidget {
  const CardCrossfade({super.key, required this.id, required this.child});

  /// What the card shows; another one crossfades.
  final Object id;

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: OsdMotion.d(context, OsdMotion.selection),
    switchInCurve: OsdMotion.curve(context, OsdMotion.selectionCurve),
    switchOutCurve: OsdMotion.curve(context, OsdMotion.selectionCurve),
    transitionBuilder: (Widget child, Animation<double> animation) =>
        _FadeIn(animation: animation, child: child),
    child: KeyedSubtree(key: ValueKey<Object>(id), child: child),
  );
}

/// Fades a card in; one on its way out stays whole.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _Whole(animation), child: child);
}

/// [parent] while it runs forward, 1 while it runs back.
class _Whole extends Animation<double> with AnimationWithParentMixin<double> {
  _Whole(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value =>
      parent.status == AnimationStatus.reverse ? 1 : parent.value;
}
