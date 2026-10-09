import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';

/// Resumes a recording Android kept after it killed the app while the
/// system camera was open (low-memory Android 8–9 phones depend on it):
/// once the launch is done, it asks the platform once ([recover]) and
/// hands what came back to [open], which passes it to Today
/// (`RecoveredClipCubit`): Today opens the clip editor on it.
///
/// It only asks on an onboarded diary ([isOnboarded]): before that the
/// system camera never opened. Sits in `MaterialApp.builder`, like
/// `LegacyMigrationListener`, so it follows the launch whatever route
/// shows; the launch may already be done when this is mounted.
class LostPickListener extends StatefulWidget {
  const LostPickListener({
    super.key,
    required this.isOnboarded,
    required this.recover,
    required this.open,
    required this.child,
  });

  final bool Function() isOnboarded;
  final Future<RecoveredClip?> Function() recover;
  final void Function(RecoveredClip clip) open;
  final Widget child;

  @override
  State<LostPickListener> createState() => _LostPickListenerState();
}

class _LostPickListenerState extends State<LostPickListener> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    // The BlocListener below only hears later changes.
    if (context.read<LaunchCubit>().state.status == LaunchStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ask());
      });
    }
  }

  Future<void> _ask() async {
    if (_asked || !widget.isOnboarded()) return;
    _asked = true;
    final RecoveredClip? clip = await widget.recover();
    if (clip != null && mounted) widget.open(clip);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LaunchCubit, LaunchState>(
      listenWhen: (LaunchState previous, LaunchState current) =>
          previous.status != current.status &&
          current.status == LaunchStatus.ready,
      listener: (BuildContext context, LaunchState state) => unawaited(_ask()),
      child: widget.child,
    );
  }
}
