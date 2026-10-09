import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pop_switcher.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A profile in the profile switch sheet: avatar, name over the orientation
/// glyph and [subtitle], and a trailing check when [selected].
///
/// While the switch is [pending] a spinner replaces the check, after a short
/// delay. One node: `selected`, mutually exclusive, labelled "name, subtitle"
/// unless [semanticsLabel] says more.
class ProfileOptionTile extends StatelessWidget {
  const ProfileOptionTile({
    super.key,
    required this.name,
    this.photo,
    required this.orientation,
    required this.subtitle,
    required this.selected,
    this.pending = false,
    required this.onTap,
    this.onLongPress,
    this.editActionLabel,
    this.semanticsLabel,
  });

  static const Key surfaceKey = Key('profileOptionTile.surface');

  /// The orientation glyph.
  static const Key glyphKey = Key('profileOptionTile.glyph');

  static const Key checkKey = Key('profileOptionTile.check');

  static const Duration _crossfade = Duration(milliseconds: 160);

  final String name;

  final ImageProvider? photo;

  final VideoOrientation orientation;

  /// "Landscape · 914 videos".
  final String subtitle;

  /// Whether this is the profile being recorded into.
  final bool selected;

  /// Whether the switch to this profile is in progress.
  final bool pending;

  final VoidCallback? onTap;

  /// Opens the profile's edit sheet, after a medium impact.
  final VoidCallback? onLongPress;

  /// The custom semantics action that also runs [onLongPress].
  final String? editActionLabel;

  /// Overrides the "name, subtitle" label.
  final String? semanticsLabel;

  void _edit() {
    unawaited(OsdHaptic.medium.play());
    onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final radius = BorderRadius.circular(OsdRadius.r18);
    final onLongPress = this.onLongPress;
    final editActionLabel = this.editActionLabel;
    return OsdPressable(
      onTap: onTap,
      onLongPress: onLongPress == null ? null : _edit,
      customSemanticsActions: onLongPress == null || editActionLabel == null
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: editActionLabel): onLongPress,
            },
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.row.scale,
      borderRadius: radius,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      semanticsLabel: semanticsLabel ?? '$name, $subtitle',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        key: surfaceKey,
        duration: OsdMotion.d(context, _crossfade),
        curve: OsdMotion.curve(context, OsdMotion.selectionCurve),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.sel : colors.c2,
          border: Border.all(
            color: selected ? colors.tx : colors.tx.withValues(alpha: 0),
            width: 1.5,
          ),
          borderRadius: radius,
        ),
        child: Row(
          spacing: 14,
          children: <Widget>[
            OsdAvatar(name: name, photo: photo, size: 40),
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
                    style: typography.buttonNeutral.copyWith(color: colors.tx),
                  ),
                  Row(
                    spacing: 4,
                    children: <Widget>[
                      OsdIcon(
                        orientation == VideoOrientation.landscape
                            ? OsdIcons.stayCurrentLandscape
                            : OsdIcons.stayCurrentPortrait,
                        key: glyphKey,
                        size: 15,
                        color: colors.mu,
                      ),
                      Flexible(
                        child: Text(
                          subtitle,
                          // The app's words, never cut: a narrow phone or a
                          // large text size wraps them.
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
            if (pending)
              OsdLoadingDelay(
                loading: true,
                builder: (context, show) => SizedBox.square(
                  dimension: 22,
                  child: show
                      ? const Center(child: OsdSpinner(size: 16))
                      : null,
                ),
              )
            else
              OsdPopSwitcher(
                child: selected
                    ? OsdIcon(OsdIcons.check, key: checkKey, color: colors.tx)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
