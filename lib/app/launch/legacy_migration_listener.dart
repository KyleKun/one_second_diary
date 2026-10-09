import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/app/launch/legacy_migration_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';

/// Opens the [LegacyMigrationDialog] on the root navigator ([navigatorKey])
/// when the launch starts moving the pre-2023 Android folders, or when that
/// ends at once with an error. Sits in `MaterialApp.builder`, above the
/// navigator, so it follows the launch whatever route shows.
///
/// The launch may be further along when this is mounted (the app's first
/// frame is empty while the translations load): if the dialog should
/// already show, it opens after the frame that mounts this, on what the
/// launch shows by then. Later changes come through its `BlocListener`,
/// which only hears what changes after it subscribes.
class LegacyMigrationListener extends StatefulWidget {
  const LegacyMigrationListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<LegacyMigrationListener> createState() =>
      _LegacyMigrationListenerState();
}

class _LegacyMigrationListenerState extends State<LegacyMigrationListener> {
  @override
  void initState() {
    super.initState();
    // The BlocListener below starts from this same state, so it never opens
    // the dialog for it a second time.
    if (context.read<LaunchCubit>().state.showsMigration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open();
      });
    }
  }

  void _open() {
    final BuildContext? navigator = widget.navigatorKey.currentContext;
    if (navigator == null) return;
    unawaited(
      showOsdDialog<void>(
        navigator,
        dismissible: false,
        builder: (BuildContext context) => const LegacyMigrationDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LaunchCubit, LaunchState>(
      listenWhen: (LaunchState previous, LaunchState current) =>
          !previous.showsMigration && current.showsMigration,
      listener: (BuildContext context, LaunchState state) => _open(),
      child: widget.child,
    );
  }
}
