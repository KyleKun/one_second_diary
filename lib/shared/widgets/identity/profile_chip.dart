import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The profile pill.
///
/// - **Interactive**: avatar, name (at most [maxNameWidth] wide) and a
///   chevron. It lays out at the drawn chip while its hit area reaches past
///   it (`OsdOverflowHitArea`: give it a parent taller than the chip). While
///   the profile sheet is open ([expanded]) the chevron points up; a profile
///   change crossfades name and avatar. One button node labelled
///   [semanticsLabel] ("Profile: Default"), whose [semanticsTapHint] says
///   what a tap does ("switch profile"; the platform says the gesture).
///   While a switch runs ([pending]) a spinner takes the chevron's place,
///   after a short delay.
/// - **[ProfileChip.static]**: avatar and name. Not interactive.
/// - **[ProfileChip.inline]**: the static chip, smaller, in a line of text.
class ProfileChip extends StatelessWidget {
  const ProfileChip({
    super.key,
    required this.name,
    this.photo,
    required this.onPressed,
    required String this.semanticsLabel,
    this.semanticsTapHint,
    this.expanded = false,
    this.pending = false,
    this.maxNameWidth = 140,
  }) : _interactive = true,
       _inline = false;

  const ProfileChip.static({
    super.key,
    required this.name,
    this.photo,
    this.maxNameWidth = 220,
  }) : _interactive = false,
       _inline = false,
       onPressed = null,
       semanticsLabel = null,
       semanticsTapHint = null,
       expanded = false,
       pending = false;

  /// The static chip, smaller, to sit in a line of text (`ProfileInlineText`).
  const ProfileChip.inline({
    super.key,
    required this.name,
    this.photo,
    this.maxNameWidth = 160,
  }) : _interactive = false,
       _inline = true,
       onPressed = null,
       semanticsLabel = null,
       semanticsTapHint = null,
       expanded = false,
       pending = false;

  static const Key surfaceKey = Key('profileChip.surface');

  static const Key chevronKey = Key('profileChip.chevron');

  /// The spinner that stands in for the chevron while a switch runs.
  static const Key pendingKey = Key('profileChip.pending');

  final String name;

  final ImageProvider? photo;

  /// Opens the profile switch sheet.
  final VoidCallback? onPressed;

  final String? semanticsLabel;

  /// What a tap does, as a phrase ("switch profile").
  final String? semanticsTapHint;

  /// Whether the profile sheet is open (the chevron points up).
  final bool expanded;

  /// Whether a profile switch is running.
  final bool pending;

  /// The widest the name gets before it ellipsizes.
  final double maxNameWidth;

  final bool _interactive;
  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final interactive = _interactive;
    final identity = Row(
      key: ValueKey<(String, ImageProvider?)>((name, photo)),
      mainAxisSize: MainAxisSize.min,
      spacing: interactive || _inline ? 6 : 8,
      children: <Widget>[
        OsdAvatar(
          name: name,
          photo: photo,
          size: _inline
              ? 20
              : interactive
              ? 30
              : 28,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxNameWidth),
          child: Text(
            name,
            maxLines: _inline ? 1 : OsdTextScale.nameLines(context),
            overflow: TextOverflow.ellipsis,
            style:
                (_inline
                        ? typography.label13
                        : interactive
                        ? typography.chipLabel
                        : typography.label14Strong)
                    .copyWith(color: colors.tx),
          ),
        ),
      ],
    );
    final chip = DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: interactive ? colors.btn : colors.c2,
        borderRadius: BorderRadius.circular(OsdRadius.full),
      ),
      child: Padding(
        padding: _inline
            ? const EdgeInsetsDirectional.fromSTEB(3, 3, 10, 3)
            : interactive
            ? const EdgeInsetsDirectional.fromSTEB(4, 4, 10, 4)
            : const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            if (interactive)
              AnimatedSwitcher(
                duration: OsdMotion.d(context, OsdMotion.selection),
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: <Widget>[...previous, ?current],
                ),
                child: identity,
              )
            else
              identity,
            if (interactive)
              OsdLoadingDelay(
                loading: pending,
                builder: (context, showLoading) => showLoading
                    ? SizedBox.square(
                        key: pendingKey,
                        dimension: 18,
                        child: Center(
                          child: OsdSpinner(size: 16, color: colors.mu),
                        ),
                      )
                    : AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: OsdMotion.d(context, OsdMotion.navPill),
                        curve: OsdMotion.curve(
                          context,
                          OsdMotion.standardCurve,
                        ),
                        child: OsdIcon(
                          OsdIcons.expandMore,
                          key: chevronKey,
                          size: 18,
                          color: colors.mu,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
    if (!interactive) return chip;
    return OsdOverflowHitArea(
      child: OsdPressable(
        onTap: onPressed,
        pressScale: OsdPressScale.icon.scale,
        borderRadius: BorderRadius.circular(OsdRadius.full),
        semanticsLabel: semanticsLabel,
        semanticsTapHint: semanticsTapHint,
        excludeChildSemantics: true,
        child: chip,
      ),
    );
  }
}
