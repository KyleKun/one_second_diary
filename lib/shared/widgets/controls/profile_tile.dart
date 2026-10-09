import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/shared/widgets/controls/active_badge.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pop_switcher.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A profile on the Profiles page: avatar, name over the orientation glyph
/// and [subtitle], and an [ActiveBadge] when active.
///
/// Tap activates the profile; a long press opens the edit sheet, and so does
/// the custom semantics action [editActionLabel]. Held, it goes on shrinking
/// until the long press fires (a progress cue), then springs back. While a
/// switch to this profile takes a while to store ([busy]), a spinner stands
/// where the badge goes. One button node, `selected` when active, in a
/// mutually exclusive group (one profile is active at a time).
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.name,
    this.photo,
    required this.orientation,
    required this.subtitle,
    required this.active,
    this.busy = false,
    required this.activeLabel,
    required this.onTap,
    required this.onLongPress,
    required this.editActionLabel,
    this.semanticsLabel,
    this.semanticsHint,
  });

  static const Key surfaceKey = Key('profileTile.surface');

  /// The spinner shown while a switch to this profile is stored.
  static const Key busyKey = Key('profileTile.busy');

  static const Duration _change = Duration(milliseconds: 200);

  final String name;

  final ImageProvider? photo;

  final VideoOrientation orientation;

  /// "Landscape · 914 videos".
  final String subtitle;

  final bool active;

  /// Whether a switch to this profile is being stored.
  final bool busy;

  /// The badge text.
  final String activeLabel;

  /// Activates the profile.
  final VoidCallback? onTap;

  /// Opens the edit sheet.
  final VoidCallback? onLongPress;

  /// The custom semantics action that also opens the edit sheet.
  final String editActionLabel;

  /// Overrides the "name, subtitle" label.
  final String? semanticsLabel;

  final String? semanticsHint;

  void _edit() {
    unawaited(OsdHaptic.medium.play());
    onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(OsdRadius.r20);
    final canEdit = onLongPress != null;
    return OsdPressable(
      onTap: onTap,
      onLongPress: canEdit ? _edit : null,
      pressScale: OsdPressScale.row.scale,
      borderRadius: radius,
      selected: active,
      // One profile is active at a time: the tiles are a radio group.
      inMutuallyExclusiveGroup: true,
      semanticsLabel: semanticsLabel ?? '$name, $subtitle',
      semanticsHint: semanticsHint,
      excludeChildSemantics: true,
      customSemanticsActions: canEdit
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: editActionLabel): onLongPress!,
            }
          : null,
      child: _LongPressCue(
        enabled: canEdit,
        child: LightHairline(
          radius: BorderRadius.circular(18.5),
          inset: 1.5,
          visible: !active,
          child: AnimatedContainer(
            key: surfaceKey,
            duration: OsdMotion.d(context, _change),
            curve: OsdMotion.curve(context, OsdMotion.fastCurve),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: active ? colors.sel : colors.card,
              border: Border.all(
                color: active ? colors.tx : colors.tx.withValues(alpha: 0),
                width: 1.5,
              ),
              borderRadius: radius,
            ),
            child: Row(
              spacing: 14,
              children: <Widget>[
                OsdAvatar(name: name, photo: photo, size: 44),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: <Widget>[
                      Text(
                        name,
                        maxLines: OsdTextScale.nameLines(context),
                        overflow: TextOverflow.ellipsis,
                        style: typography.button.copyWith(color: colors.tx),
                      ),
                      Row(
                        spacing: 4,
                        children: <Widget>[
                          OsdIcon(
                            orientation == VideoOrientation.landscape
                                ? OsdIcons.stayCurrentLandscape
                                : OsdIcons.stayCurrentPortrait,
                            size: 15,
                            color: colors.mu,
                          ),
                          Flexible(
                            child: Text(
                              subtitle,
                              // The app's words, never cut: a narrow phone or
                              // a large text size wraps them.
                              style: typography.caption13.copyWith(
                                color: colors.mu,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OsdLoadingDelay(
                  loading: busy,
                  builder: (context, spinning) => OsdPopSwitcher(
                    fromScale: .8,
                    child: spinning
                        ? OsdSpinner(key: busyKey, size: 16, color: colors.tx)
                        : active
                        ? ActiveBadge(
                            key: const ValueKey<bool>(true),
                            label: activeLabel,
                          )
                        : null,
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

/// The long-press cue: after a short hold, [child] shrinks over the rest of
/// the long-press timeout, then springs back as the long press fires. A
/// finger that lifts or moves away first lets it go back. Nothing under
/// reduced motion.
class _LongPressCue extends StatefulWidget {
  const _LongPressCue({required this.enabled, required this.child});

  /// Whether the tile has a long press.
  final bool enabled;

  final Widget child;

  @override
  State<_LongPressCue> createState() => _LongPressCueState();
}

class _LongPressCueState extends State<_LongPressCue>
    with SingleTickerProviderStateMixin {
  static const Duration _delay = Duration(milliseconds: 120);

  /// With the press's .98, the tile reaches .97.
  static const double _scale = .97 / .98;

  static const SpringDescription _springBack = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 20,
  );

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: kLongPressTimeout - _delay,
  );
  Timer? _cue;
  Offset? _down;

  @override
  void dispose() {
    _cue?.cancel();
    _hold.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent event) {
    if (!widget.enabled || OsdMotion.reduced(context)) return;
    _down = event.position;
    _cue?.cancel();
    _cue = Timer(_delay, () {
      if (!mounted) return;
      unawaited(
        _hold.animateTo(1, curve: Curves.easeOut).then((_) {
          // The long press fired: spring back.
          if (mounted && _down != null) {
            _down = null;
            unawaited(
              _hold.animateWith(SpringSimulation(_springBack, 1, 0, 0)),
            );
          }
        }),
      );
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    final Offset? down = _down;
    if (down != null && (event.position - down).distance > kTouchSlop) {
      _release();
    }
  }

  /// The finger lifted before the long press, or the list scrolled.
  void _release() {
    _down = null;
    _cue?.cancel();
    if (_hold.value > 0) unawaited(_hold.animateBack(0));
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _pointerDown,
    onPointerMove: _pointerMove,
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: AnimatedBuilder(
      animation: _hold,
      builder: (context, child) =>
          Transform.scale(scale: 1 - (1 - _scale) * _hold.value, child: child),
      child: widget.child,
    ),
  );
}
