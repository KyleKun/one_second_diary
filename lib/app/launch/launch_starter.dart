import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';

/// Starts the post-frame launch (`LaunchCubit.start`) after the frame that
/// first shows the app's pages.
///
/// It sits in `MaterialApp.builder`, below the folder migration listener,
/// so everything that follows the launch is mounted before its first event:
/// the app's first frame is empty while the translations load, and a
/// launch started after that frame could move files before anything shows
/// the migration dialog. Starting it again does nothing.
class LaunchStarter extends StatefulWidget {
  const LaunchStarter({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchStarter> createState() => _LaunchStarterState();
}

class _LaunchStarterState extends State<LaunchStarter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<LaunchCubit>().start());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
