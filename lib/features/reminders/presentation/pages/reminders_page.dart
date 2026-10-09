import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_state.dart';
import 'package:one_second_diary/features/reminders/presentation/reminder_time_label.dart';
import 'package:one_second_diary/features/reminders/presentation/sheets/reminder_time_sheet.dart';
import 'package:one_second_diary/features/reminders/presentation/widgets/notification_preview_tile.dart';
import 'package:one_second_diary/features/reminders/presentation/widgets/reminder_time_card.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Notifications page.
///
/// - "Daily reminder": the whole row toggles it. Turning it on asks for the
///   notification permission; a refusal turns the switch back off and the
///   blocked banner explains it. The page checks again when the app returns.
/// - The time card: the big time and "Change time", which opens the time sheet.
/// - "Persistent notification" (Android only).
/// - "Preview": the real notification's title and body.
///
/// With the reminder off, everything below the switch dims and takes no taps.
/// Every change is stored at once; back just pops.
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key, required this.platform});

  static const Key blockedBannerKey = Key('remindersPage.blocked');

  static const Key reminderRowKey = Key('remindersPage.reminder');

  /// Everything the switch dims.
  static const Key dependentsKey = Key('remindersPage.dependents');

  static const Key changeTimeKey = Key('remindersPage.changeTime');

  static const Key persistentRowKey = Key('remindersPage.persistent');

  static const Key previewKey = Key('remindersPage.preview');

  /// What this platform offers (no persistent reminder on iOS).
  final SettingsPlatform platform;

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  /// Back from the phone's settings, the reminder may be allowed now.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          unawaited(context.read<ReminderSettingsCubit>().checkAccess()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _changeTime(ReminderTime current) async {
    final ReminderSettingsCubit cubit = context.read<ReminderSettingsCubit>();
    final ReminderTime? picked = await ReminderTimeSheet.show(
      context,
      initial: current,
    );
    if (picked != null && picked != current) await cubit.setTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: OsdAppBar(title: Strings.notifications),
      body: OsdSnackbarHost(
        child: BlocListener<ReminderSettingsCubit, ReminderSettingsState>(
          listenWhen:
              (ReminderSettingsState previous, ReminderSettingsState current) =>
                  previous.status != current.status &&
                  current.status == ReminderSettingsStatus.saveFailed,
          listener: (BuildContext context, _) => OsdSnackbar.show(
            context,
            kind: OsdSnackKind.error,
            title: Strings.preferencesSaveFailed,
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OsdSizes.contentMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: OsdSpace.s24),
                  children: <Widget>[
                    const _BlockedBanner(),
                    const Padding(
                      padding: EdgeInsets.only(top: OsdSpace.s8),
                      child: OsdCard(child: _ReminderSwitchRow()),
                    ),
                    _Dependents(
                      showsPersistent: widget.platform.showsPersistentReminder,
                      onChangeTime: _changeTime,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Notifications are blocked", with "Open settings": shown while the
/// phone won't post the reminder the user wants. It grows in with a fade.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner();

  @override
  Widget build(BuildContext context) {
    final bool blocked = context.select(
      (ReminderSettingsCubit cubit) => cubit.state.blocked,
    );
    final bool reduced = OsdMotion.reduced(context);
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.standard),
      switchInCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
      switchOutCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Widget faded = FadeTransition(opacity: animation, child: child);
        return reduced
            ? faded
            : SizeTransition(
                sizeFactor: animation,
                alignment: AlignmentDirectional.topCenter,
                child: faded,
              );
      },
      child: blocked
          ? Padding(
              key: RemindersPage.blockedBannerKey,
              padding: const EdgeInsetsDirectional.fromSTEB(
                OsdSpace.pageGutter,
                OsdSpace.s8,
                OsdSpace.pageGutter,
                0,
              ),
              child: OsdCallout.banner(
                title: Strings.notificationsBlockedTitle,
                text: Strings.notificationsBlockedBody,
                actionLabel: Strings.openSettings,
                onAction: () => unawaited(
                  context.read<ReminderSettingsCubit>().openSystemSettings(),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// "Daily reminder": the whole row toggles it with a selection click; the
/// switch shows on while the permission is asked.
class _ReminderSwitchRow extends StatelessWidget {
  const _ReminderSwitchRow();

  @override
  Widget build(BuildContext context) {
    final (bool on, bool asking) = context.select(
      (ReminderSettingsCubit cubit) => (
        cubit.state.switchOn,
        cubit.state.status == ReminderSettingsStatus.requesting,
      ),
    );
    return OsdListRow(
      key: RemindersPage.reminderRowKey,
      title: Strings.enableNotifications,
      titleStyle: context.typography.rowTitleStrong,
      trailing: OsdRowTrailing.custom(OsdSwitch(value: on, interactive: false)),
      toggled: on,
      haptic: OsdHaptic.selection,
      onTap: () {
        if (asking) return;
        unawaited(context.read<ReminderSettingsCubit>().setEnabled(!on));
      },
    );
  }
}

/// What the switch dims: the time card, "Persistent notification" and the
/// preview. With the reminder off they dim, take no taps and read as
/// disabled; their values stay.
class _Dependents extends StatelessWidget {
  const _Dependents({
    required this.showsPersistent,
    required this.onChangeTime,
  });

  final bool showsPersistent;
  final ValueChanged<ReminderTime> onChangeTime;

  static const Duration _dim = Duration(milliseconds: 200);

  static const double _dimmed = .4;

  @override
  Widget build(BuildContext context) {
    final (bool enabled, bool persistent, ReminderTime time) = context.select(
      (ReminderSettingsCubit cubit) =>
          (cubit.state.enabled, cubit.state.persistent, cubit.state.time),
    );
    final ReminderTimeLabel label = ReminderTimeLabel.of(
      time,
      localizations: MaterialLocalizations.of(context),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return IgnorePointer(
      key: RemindersPage.dependentsKey,
      ignoring: !enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedOpacity(
            opacity: enabled ? 1 : _dimmed,
            duration: OsdMotion.d(context, _dim),
            curve: OsdMotion.curve(context, Curves.easeOut),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: OsdSpace.cardGap),
                  child: _DependentNode(
                    enabled: enabled,
                    child: ReminderTimeCard(
                      label: label,
                      changeKey: RemindersPage.changeTimeKey,
                      onChange: () => onChangeTime(time),
                    ),
                  ),
                ),
                if (showsPersistent)
                  Padding(
                    padding: const EdgeInsets.only(top: OsdSpace.cardGap),
                    child: OsdCard(
                      child: OsdListRow(
                        key: RemindersPage.persistentRowKey,
                        title: Strings.usePersistentNotifications,
                        subtitle: Strings.notificationsPersistentSubtitle,
                        trailing: OsdRowTrailing.custom(
                          OsdSwitch(value: persistent, interactive: false),
                        ),
                        toggled: persistent,
                        haptic: OsdHaptic.selection,
                        onTap: () => unawaited(
                          context.read<ReminderSettingsCubit>().setPersistent(
                            !persistent,
                          ),
                        ),
                      ),
                    ),
                  ),
                _DependentNode(
                  enabled: enabled,
                  // The label is a heading node of its own: the state joins
                  // it there.
                  merge: true,
                  child: SectionLabel.soft(
                    label: Strings.notificationsPreview,
                    sub: true,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      22,
                      20,
                      8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _DependentNode(
            enabled: enabled,
            child: _DeliveredPreview(
              key: RemindersPage.previewKey,
              enabled: enabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the dependents as a semantics node of its own (the time card,
/// "Preview", the notification), read as disabled while the reminder is
/// off. "Preview" is a `SectionLabel`, already a heading node of its own
/// ([merge]): the disabled state is merged into it.
class _DependentNode extends StatelessWidget {
  const _DependentNode({
    required this.enabled,
    required this.child,
    this.merge = false,
  });

  final bool enabled;
  final Widget child;
  final bool merge;

  @override
  Widget build(BuildContext context) => merge
      ? MergeSemantics(
          child: Semantics(enabled: enabled ? null : false, child: child),
        )
      : Semantics(
          container: true,
          enabled: enabled ? null : false,
          child: child,
        );
}

/// The preview tile, dimmed while the reminder is off. Turning it on
/// "delivers" it: shortly after the switch it slides down while it
/// brightens, then a light haptic. Turning it off dims it with the rest.
/// Under reduced motion it only fades.
class _DeliveredPreview extends StatefulWidget {
  const _DeliveredPreview({super.key, required this.enabled});

  final bool enabled;

  @override
  State<_DeliveredPreview> createState() => _DeliveredPreviewState();
}

class _DeliveredPreviewState extends State<_DeliveredPreview>
    with SingleTickerProviderStateMixin {
  static const Duration _delay = Duration(milliseconds: 80);
  static const Duration _deliver = Duration(milliseconds: 280);
  static const double _drop = 8;
  static const double _dimmed = .4;

  late final AnimationController _shown = AnimationController(
    vsync: this,
    value: widget.enabled ? 1 : 0,
  );
  Curve _curve = Curves.easeOut;
  bool _drops = false;

  @override
  void didUpdateWidget(_DeliveredPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    final bool reduced = OsdMotion.reduced(context);
    if (widget.enabled) {
      final Duration delay = reduced ? Duration.zero : _delay;
      final Duration total = delay + OsdMotion.d(context, _deliver);
      _drops = !reduced;
      _curve = Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: OsdMotion.curve(context, Curves.easeOutCubic),
      );
      _shown.duration = total;
      unawaited(
        _shown.forward(from: 0).then((_) {
          if (mounted) unawaited(OsdHaptic.light.play());
        }),
      );
    } else {
      _drops = false;
      _curve = OsdMotion.curve(context, Curves.easeOut);
      _shown.duration = OsdMotion.d(context, _Dependents._dim);
      unawaited(_shown.reverse());
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _shown,
    builder: (BuildContext context, Widget? child) {
      final double t = _curve.transform(_shown.value);
      return Opacity(
        opacity: _dimmed + (1 - _dimmed) * t,
        child: Transform.translate(
          offset: Offset(0, _drops ? -_drop * (1 - t) : 0),
          child: child,
        ),
      );
    },
    child: const NotificationPreviewTile(),
  );
}
