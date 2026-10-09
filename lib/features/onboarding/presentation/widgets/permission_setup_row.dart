import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/shared/widgets/buttons/outlined_pill_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_animated_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// One row of the permissions step: a tinted circle with the permission's
/// glyph, its name and what it is for, and the control that says where it
/// stands: "Allow" (a spinner while the prompt is up), "Allowed" once
/// granted, "Allow" again with "Not allowed yet" after a refusal, or "Open
/// settings" once only the system Settings can grant it.
///
/// The control sits at the end of the row, and under the text when the row
/// is narrow or the text is large. Control changes crossfade.
class PermissionSetupRow extends StatelessWidget {
  const PermissionSetupRow({
    super.key,
    required this.permission,
    required this.status,
    required this.onAllow,
    required this.onOpenSettings,
  });

  static Key rowKey(OnboardingPermission permission) =>
      ValueKey<(String, OnboardingPermission)>((
        'permissionSetupRow',
        permission,
      ));

  /// The row's button: "Allow", or "Open settings" when blocked.
  static Key buttonKey(OnboardingPermission permission) =>
      ValueKey<(String, OnboardingPermission)>((
        'permissionSetupRow.button',
        permission,
      ));

  /// Below this width the control goes under the text.
  static const double stackBelowWidth = 340;

  static const double _circle = 40;

  final OnboardingPermission permission;
  final PermissionRowStatus status;

  /// "Allow" tapped.
  final VoidCallback onAllow;

  /// "Open settings" tapped (the row is blocked).
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final _RowLook look = _RowLook.of(context, permission);
    final Widget leading = SizedBox.square(
      dimension: _circle,
      child: DecoratedBox(
        decoration: BoxDecoration(color: look.tint, shape: BoxShape.circle),
        child: Center(child: OsdIcon(look.icon, color: look.ink)),
      ),
    );
    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: OsdSpace.s8,
          runSpacing: OsdSpace.s4,
          children: <Widget>[
            Text(
              look.title,
              style: typography.rowTitleStrong.copyWith(color: colors.tx),
            ),
            if (permission.isOptional) const _OptionalBadge(),
          ],
        ),
        const SizedBox(height: OsdSpace.s2),
        Text(
          look.description,
          style: typography.rowSubtitle.copyWith(color: colors.mu),
        ),
        if (status == PermissionRowStatus.denied)
          Padding(
            padding: const EdgeInsets.only(top: OsdSpace.s4),
            child: Text(
              Strings.onboardingPermissionDeniedHint,
              style: typography.caption13.copyWith(color: colors.red),
            ),
          ),
      ],
    );
    final Widget control = _Control(
      permission: permission,
      status: status,
      onAllow: onAllow,
      onOpenSettings: onOpenSettings,
    );
    return MergeSemantics(
      child: Padding(
        key: rowKey(permission),
        padding: const EdgeInsets.symmetric(
          horizontal: OsdSpace.rowPadH,
          vertical: OsdSpace.s14,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked =
                constraints.maxWidth < stackBelowWidth ||
                OsdTextScale.factorOf(context) >=
                    OsdTextScale.stackButtonRowsAbove;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      leading,
                      const SizedBox(width: OsdSpace.rowGap),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: OsdSpace.s10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: control,
                  ),
                ],
              );
            }
            return Row(
              children: <Widget>[
                leading,
                const SizedBox(width: OsdSpace.rowGap),
                Expanded(child: text),
                const SizedBox(width: OsdSpace.s12),
                control,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The glyph, tint and copy of a row.
class _RowLook {
  const _RowLook({
    required this.icon,
    required this.ink,
    required this.tint,
    required this.title,
    required this.description,
  });

  factory _RowLook.of(BuildContext context, OnboardingPermission permission) {
    final OsdColors colors = context.colors;
    return switch (permission) {
      OnboardingPermission.gallery => _RowLook(
        icon: OsdIcons.photoLibrary,
        ink: colors.greenInk,
        tint: OsdTints.greenTint14,
        title: Strings.onboardingPermissionGallery,
        description: Strings.onboardingPermissionGalleryDesc,
      ),
      OnboardingPermission.camera => _RowLook(
        icon: OsdIcons.photoCamera,
        ink: colors.coInk,
        tint: OsdTints.coTint14,
        title: Strings.onboardingPermissionCamera,
        description: Strings.onboardingPermissionCameraDesc,
      ),
      OnboardingPermission.microphone => _RowLook(
        icon: OsdIcons.mic,
        ink: colors.purple,
        tint: OsdTints.purpleTint16,
        title: Strings.onboardingPermissionMicrophone,
        description: Strings.onboardingPermissionMicrophoneDesc,
      ),
      OnboardingPermission.notifications => _RowLook(
        icon: OsdIcons.notifications,
        ink: colors.yellowInk,
        tint: OsdTints.yellowTint12,
        title: Strings.onboardingPermissionNotifications,
        description: Strings.onboardingPermissionNotificationsDesc,
      ),
      OnboardingPermission.location => _RowLook(
        icon: OsdIcons.place,
        ink: colors.greenInk,
        tint: OsdTints.greenTint20,
        title: Strings.onboardingPermissionLocation,
        description: Strings.onboardingPermissionLocationDesc,
      ),
    };
  }

  final IconData icon;
  final Color ink;
  final Color tint;
  final String title;
  final String description;
}

/// "Optional", beside the title of a row the user can leave alone.
class _OptionalBadge extends StatelessWidget {
  const _OptionalBadge();

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.c2,
        borderRadius: BorderRadius.circular(OsdRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OsdSpace.s8,
          vertical: OsdSpace.s2,
        ),
        child: Text(
          Strings.onboardingPermissionOptional,
          style: context.typography.badge12.copyWith(color: colors.mu),
        ),
      ),
    );
  }
}

/// The row's control for its [status]; a change crossfades.
class _Control extends StatelessWidget {
  const _Control({
    required this.permission,
    required this.status,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final OnboardingPermission permission;
  final PermissionRowStatus status;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final Key button = PermissionSetupRow.buttonKey(permission);
    final Widget child = switch (status) {
      PermissionRowStatus.notAsked ||
      PermissionRowStatus.requesting ||
      PermissionRowStatus.denied => KeyedSubtree(
        key: const ValueKey<String>('allow'),
        child: _AllowPill(
          key: button,
          requesting: status == PermissionRowStatus.requesting,
          onPressed: onAllow,
        ),
      ),
      PermissionRowStatus.granted => const KeyedSubtree(
        key: ValueKey<String>('granted'),
        child: _GrantedPill(),
      ),
      PermissionRowStatus.blocked => KeyedSubtree(
        key: const ValueKey<String>('blocked'),
        child: OutlinedPillButton(
          key: button,
          label: Strings.openSettings,
          onPressed: onOpenSettings,
        ),
      ),
    };
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.standard),
      switchInCurve: OsdMotion.standardCurve,
      switchOutCurve: OsdMotion.standardCurve,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: <Widget>[...previous, ?current],
      ),
      child: child,
    );
  }
}

/// The coral "Allow" pill; a spinner in place of the label while
/// [requesting], when taps are ignored.
class _AllowPill extends StatelessWidget {
  const _AllowPill({
    super.key,
    required this.requesting,
    required this.onPressed,
  });

  final bool requesting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return OsdButtonFrame(
      label: Strings.onboardingPermissionAllow,
      labelStyle: context.typography.label14Strong,
      foreground: colors.coInk,
      fill: OsdTints.coTint14,
      minHeight: 36,
      radius: OsdRadius.full,
      hug: true,
      horizontalPadding: OsdSpace.s16,
      verticalPadding: OsdSpace.s6,
      loading: requesting,
      spinnerSize: 16,
      overlay: OsdPressOverlay.none,
      pressScale: OsdPressScale.button.scale,
      haptic: OsdHaptic.light,
      onPressed: onPressed,
    );
  }
}

/// The green "Allowed" pill: its check fills in as it appears. Not a
/// button; a checked state for screen readers.
class _GrantedPill extends StatefulWidget {
  const _GrantedPill();

  @override
  State<_GrantedPill> createState() => _GrantedPillState();
}

class _GrantedPillState extends State<_GrantedPill> {
  double _fill = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _fill = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Semantics(
      checked: true,
      label: Strings.onboardingPermissionAllowed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: OsdTints.greenTint14,
            borderRadius: BorderRadius.circular(OsdRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OsdSpace.s14,
              vertical: OsdSpace.s6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: OsdSpace.chipIconGap,
              children: <Widget>[
                OsdAnimatedIcon(
                  OsdIcons.checkCircle,
                  fill: _fill,
                  size: 18,
                  color: colors.greenInk,
                  duration: OsdMotion.standard,
                ),
                Text(
                  Strings.onboardingPermissionAllowed,
                  style: context.typography.label14Strong.copyWith(
                    color: colors.greenInk,
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
