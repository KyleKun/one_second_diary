import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_state.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/contact_option_tile.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The Contact dialog: "Something isn't working" (the logs are attached)
/// and "I have an idea", and Cancel.
///
/// A tap prepares the mail through the [ContactCubit] the opener passes
/// ([show]); the tapped tile spins meanwhile, and nothing can be tapped or
/// dismissed. The dialog closes as soon as the mail app opens, or when
/// none could (the opener then says so).
class ContactDialog extends StatelessWidget {
  const ContactDialog({super.key});

  static const Key problemKey = Key('contactDialog.problem');

  static const Key ideaKey = Key('contactDialog.idea');

  static const Key cancelKey = Key('contactDialog.cancel');

  /// Opens the dialog over the whole app with the opener's [ContactCubit].
  static Future<void> show(BuildContext context) {
    final ContactCubit cubit = context.read<ContactCubit>();
    return showOsdDialog<void>(
      context,
      builder: (_) => BlocProvider<ContactCubit>.value(
        value: cubit,
        child: const ContactDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final ContactState state = context.watch<ContactCubit>().state;
    final ContactCubit cubit = context.read<ContactCubit>();
    final bool busy = state.isBusy;
    return BlocListener<ContactCubit, ContactState>(
      listenWhen: (ContactState previous, ContactState current) =>
          previous.status != current.status,
      listener: (BuildContext context, ContactState state) {
        switch (state.status) {
          case ContactStatus.mailOpened || ContactStatus.noMailApp:
            Navigator.of(context).pop();
          case ContactStatus.preparing when state.topic == ContactTopic.problem:
            unawaited(
              SemanticsService.sendAnnouncement(
                View.of(context),
                Strings.contactPreparingLogs,
                Directionality.of(context),
              ),
            );
          case ContactStatus.preparing || ContactStatus.ready:
            break;
        }
      },
      child: PopScope(
        canPop: !busy,
        child: OsdDialog(
          title: Strings.contactTitle,
          body: Strings.contactSubtitle,
          content: Padding(
            padding: const EdgeInsets.only(top: OsdSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: OsdSpace.s8,
              children: <Widget>[
                _StaggeredIn(
                  index: 0,
                  child: ContactOptionTile(
                    key: problemKey,
                    icon: OsdIcons.bugReport,
                    accent: colors.red,
                    tint: OsdTints.redTint16,
                    title: Strings.contactBugTitle,
                    subtitle: Strings.contactBugSubtitle,
                    busy: busy && state.topic == ContactTopic.problem,
                    onTap: busy
                        ? null
                        : () => unawaited(
                            cubit.reportProblem(body: Strings.errorMailBody),
                          ),
                  ),
                ),
                _StaggeredIn(
                  index: 1,
                  child: ContactOptionTile(
                    key: ideaKey,
                    icon: OsdIcons.lightbulb,
                    accent: colors.yellow,
                    tint: OsdTints.yellowTint16,
                    title: Strings.contactIdeaTitle,
                    subtitle: Strings.contactIdeaSubtitle,
                    busy: busy && state.topic == ContactTopic.idea,
                    onTap: busy ? null : () => unawaited(cubit.shareIdea()),
                  ),
                ),
              ],
            ),
          ),
          actions: OsdTextButton(
            key: cancelKey,
            label: CommonLabels.of(context).cancel,
            tone: OsdTextButtonTone.muted,
            height: 44,
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

/// An option coming in with the dialog, staggered by [index]: it fades in
/// over the rest of the dialog's entrance. It leaves with the dialog. Under
/// reduced motion the options show with the dialog's crossfade.
class _StaggeredIn extends StatefulWidget {
  const _StaggeredIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredIn> createState() => _StaggeredInState();
}

class _StaggeredInState extends State<_StaggeredIn> {
  static const Duration _stagger = Duration(milliseconds: 50);

  /// The option's share of the dialog's entrance; made once, disposed with
  /// the option.
  CurvedAnimation? _opacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? route = ModalRoute.of(context)?.animation;
    if (_opacity != null || route == null || widget.index == 0) return;
    final double start =
        (_stagger * widget.index).inMicroseconds /
        OsdMotion.dialogIn.inMicroseconds;
    _opacity = CurvedAnimation(
      parent: route,
      curve: Interval(math.min(start, 1), 1, curve: OsdMotion.dialogInCurve),
      reverseCurve: const Threshold(0),
    );
  }

  @override
  void dispose() {
    _opacity?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation? opacity = _opacity;
    if (opacity == null || OsdMotion.reduced(context)) return widget.child;
    return FadeTransition(opacity: opacity, child: widget.child);
  }
}
