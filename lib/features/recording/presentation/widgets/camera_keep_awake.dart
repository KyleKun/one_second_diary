import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';

/// Keeps the screen awake while the camera shows: one hold from the first
/// frame to the page going away, through the app's reference-counted
/// [wakelock] (`SharedWakelock`), so closing the camera never lets the
/// phone sleep while a movie is being made.
class CameraKeepAwake extends StatefulWidget {
  const CameraKeepAwake({
    super.key,
    required this.wakelock,
    required this.child,
  });

  final WakelockGateway wakelock;

  final Widget child;

  @override
  State<CameraKeepAwake> createState() => _CameraKeepAwakeState();
}

class _CameraKeepAwakeState extends State<CameraKeepAwake> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.wakelock.enable());
  }

  @override
  void dispose() {
    unawaited(widget.wakelock.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
