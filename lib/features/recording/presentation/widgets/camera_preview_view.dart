import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/upright_rotation.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The live preview of the open lens, filling its box and cropped to it;
/// black while no lens is open, and never the preview of a released camera.
/// Both cameras' one picture is shown whole instead, black beside it.
///
/// On Android the plugin turns the picture by the orientation the capture is
/// locked to; the layout stays portrait, so the picture is turned back. It
/// rebuilds only when the lens or that orientation changes.
class CameraPreviewView extends StatelessWidget {
  const CameraPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final (CameraSession? session, DeviceOrientation capture) = context.select(
      (RecordingBloc bloc) =>
          (bloc.state.session, bloc.state.captureOrientation),
    );
    final bool android = defaultTargetPlatform == TargetPlatform.android;
    final int turns = android ? UprightRotation.quarterTurnsOf(capture) : 0;
    return RepaintBoundary(
      child: ColoredBox(
        color: OsdCamera.black,
        child: session == null
            ? const SizedBox.expand()
            // A new lens fades in; a released one is gone at once.
            : TweenAnimationBuilder<double>(
                key: ObjectKey(session),
                tween: Tween<double>(begin: 0, end: 1),
                duration: OsdMotion.d(context, OsdMotion.fast),
                curve: OsdMotion.fastCurve,
                builder:
                    (BuildContext context, double opacity, Widget? child) =>
                        Opacity(opacity: opacity, child: child),
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: session is DualCameraSession
                        ? BoxFit.contain
                        : BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: RotatedBox(
                      quarterTurns: turns,
                      // The UI stays portrait: the sensor's width over
                      // height shows as height over width.
                      child: SizedBox(
                        width: turns.isOdd ? session.aspectRatio : 1,
                        height: turns.isOdd ? 1 : session.aspectRatio,
                        child: session.preview(),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
