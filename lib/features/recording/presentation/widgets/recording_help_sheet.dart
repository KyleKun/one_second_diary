import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_help_item.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// "Camera guide", from the help button of the recording settings sheet and
/// stacked over it, dark like it: what each gesture and each setting does,
/// and a Close button at its end (the sheet is long). It lists everything the
/// camera can do, also what this phone lacks, whose lines say so. The volume
/// buttons are Android's only.
class RecordingHelpSheet extends StatelessWidget {
  const RecordingHelpSheet({super.key});

  static const Key bodyKey = Key('recordingHelpSheet.body');

  static const Key closeKey = Key('recordingHelpSheet.close');

  /// Opens the guide over the recording settings sheet of [context].
  static Future<void> show(BuildContext context) => showOsdSheet<void>(
    context,
    title: Strings.recordingHelpTitle,
    barrierColor: OsdCamera.scrim,
    child: const RecordingHelpSheet(key: bodyKey),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s16,
    children: <Widget>[
      SectionLabel.soft(label: Strings.recordingHelpGestures),
      OsdHelpItem(
        icon: OsdIcons.touchApp,
        title: Strings.recordingHelpTapTitle,
        body: Strings.recordingHelpTapBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.lock,
        title: Strings.recordingHelpHoldTitle,
        body: Strings.recordingHelpHoldBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.openInFull,
        title: Strings.recordingHelpPinchTitle,
        body: Strings.recordingHelpPinchBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.cameraswitch,
        title: Strings.recordingHelpSwipeTitle,
        body: Strings.recordingHelpSwipeBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.radioButtonChecked,
        title: Strings.record,
        body: Strings.recordingHelpRecordBody,
      ),
      if (defaultTargetPlatform == TargetPlatform.android)
        OsdHelpItem(
          icon: OsdIcons.volumeUp,
          title: Strings.recordingHelpVolumeTitle,
          body: Strings.recordingHelpVolumeBody,
        ),
      SectionLabel.soft(label: Strings.recordingHelpOptions),
      OsdHelpItem(
        icon: OsdIcons.schedule,
        title: Strings.clipLength,
        body: Strings.recordingHelpClipLengthBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.photoCamera,
        title: Strings.cameraLens,
        body: Strings.recordingHelpLensBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.timer,
        title: Strings.countdown,
        body: Strings.recordingHelpCountdownBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.lightbulb,
        title: Strings.recordingSettingsFlash,
        body: Strings.recordingHelpFlashBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.videocam,
        title: Strings.recordingSettingsDual,
        body: Strings.recordingHelpDualBody,
      ),
      OsdHelpItem(
        icon: OsdIcons.screenLockPortrait,
        title: Strings.recordingSettingsLockOrientation,
        body: Strings.recordingHelpLockBody,
      ),
      NeutralButton(
        key: closeKey,
        label: CommonLabels.of(context).close,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
