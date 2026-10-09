import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Microphone off" pill: the camera records without sound, and says
/// so under the top bar.
class MicrophoneOffPill extends StatelessWidget {
  const MicrophoneOffPill({super.key});

  @override
  Widget build(BuildContext context) =>
      CameraHintPill(icon: OsdIcons.micOff, label: Strings.cameraMicOffHint);
}

/// The "Hold upright" pill: both cameras record one upright clip, and the
/// phone is held sideways.
class DualUprightPill extends StatelessWidget {
  const DualUprightPill({super.key});

  @override
  Widget build(BuildContext context) => CameraHintPill(
    icon: OsdIcons.stayCurrentPortrait,
    label: Strings.cameraDualUprightHint,
  );
}

/// The "Focus and exposure locked" pill: a long press on the preview holds
/// both until the next tap.
class FocusLockedPill extends StatelessWidget {
  const FocusLockedPill({super.key});

  @override
  Widget build(BuildContext context) =>
      CameraHintPill(icon: OsdIcons.lock, label: Strings.cameraFocusLockedHint);
}

/// A glass pill under the camera's top bar: a glyph and one line.
class CameraHintPill extends StatelessWidget {
  const CameraHintPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const double _height = 32;
  static const double _glyph = 16;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: _height),
    padding: const EdgeInsets.symmetric(horizontal: OsdSpace.s12),
    decoration: BoxDecoration(
      color: OsdCamera.glass,
      borderRadius: BorderRadius.circular(OsdRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: _gap,
      children: <Widget>[
        OsdIcon(icon, size: _glyph, color: OsdCamera.white),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: OsdTextScale.scalerFor(
              context,
              OsdTextScaleRole.mediaChrome,
            ),
            style: context.typography.label13.copyWith(color: OsdCamera.white),
          ),
        ),
      ],
    ),
  );
}
