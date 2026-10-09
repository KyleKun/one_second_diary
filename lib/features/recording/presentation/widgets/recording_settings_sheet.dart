import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/recording/domain/recording_length_steps.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/camera_numbers.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/recording_help_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/option_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_slider.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The recording settings, always dark over the camera's scrim, with a help
/// button that opens the camera guide ([RecordingHelpSheet]): the clip length
/// (a non-linear slider over [RecordingLengthSteps]), the lens, Countdown,
/// Flash, Dual camera and Lock orientation. Changes apply at once. The lock
/// is remembered per profile; the flash is for this camera only: it is off on a lens without
/// a light.
class RecordingSettingsSheet extends StatefulWidget {
  const RecordingSettingsSheet({super.key});

  static const Key helpKey = Key('recordingSettingsSheet.help');
  static const Key sliderKey = Key('recordingSettingsSheet.clipLength');
  static const Key valueKey = Key('recordingSettingsSheet.value');
  static const Key lensesKey = Key('recordingSettingsSheet.lenses');
  static const Key countdownKey = Key('recordingSettingsSheet.countdown');
  static const Key flashKey = Key('recordingSettingsSheet.flash');
  static const Key dualKey = Key('recordingSettingsSheet.dual');
  static const Key dualLayoutsKey = Key('recordingSettingsSheet.dualLayouts');
  static const Key lockKey = Key('recordingSettingsSheet.lock');
  static const Key doneKey = Key('recordingSettingsSheet.done');

  /// The shortest and the longest clip, in seconds, and the marks under
  /// the slider ([RecordingLengthSteps]).
  static int get shortest => RecordingLengthSteps.values.first;
  static int get longest => RecordingLengthSteps.values.last;
  static const List<int> marks = RecordingLengthSteps.marks;

  /// The slider's value text: "7s", and "1:00" past 59 s.
  static String lengthLabel(int seconds) =>
      ClipLengthFormat.showsMinutes(seconds)
      ? ClipLengthFormat.minutes(seconds)
      : Strings.clipLengthSecondsShort(count: seconds);

  /// Opens the sheet over the camera page of [context], and completes when
  /// it has closed.
  static Future<void> show(BuildContext context) {
    final RecordingBloc bloc = context.read<RecordingBloc>();
    return showOsdSheet<void>(
      context,
      title: Strings.recordingSettings,
      // The sheet's own context: the guide stacks over it, as dark.
      titleTrailing: Builder(
        builder: (BuildContext context) => OsdIconButton(
          key: helpKey,
          icon: OsdIcons.help,
          tooltip: Strings.recordingHelpTitle,
          onPressed: () => unawaited(RecordingHelpSheet.show(context)),
        ),
      ),
      barrierColor: OsdCamera.scrim,
      child: BlocProvider<RecordingBloc>.value(
        value: bloc,
        child: const RecordingSettingsSheet(),
      ),
    );
  }

  @override
  State<RecordingSettingsSheet> createState() => _RecordingSettingsSheetState();
}

class _RecordingSettingsSheetState extends State<RecordingSettingsSheet> {
  /// The length under the finger while the slider is dragged, and once it
  /// is let go, until the saved length comes back from the bloc (the value
  /// never flicks back to the old one).
  int? _pending;

  @override
  Widget build(BuildContext context) {
    final (
      int clipSeconds,
      bool countdown,
      bool canUseFlash,
      bool flash,
      bool locked,
      bool landscape,
    ) = context.select(
      (RecordingBloc bloc) => (
        bloc.state.clipSeconds,
        bloc.state.countdownEnabled,
        bloc.state.canUseFlash,
        bloc.state.canUseFlash && bloc.state.flashOn,
        bloc.state.lockedOrientation != null,
        switch (bloc.state.lockedOrientation ?? bloc.state.orientation) {
          DeviceOrientation.landscapeLeft ||
          DeviceOrientation.landscapeRight => true,
          DeviceOrientation.portraitUp ||
          DeviceOrientation.portraitDown => false,
        },
      ),
    );
    final bool severalLenses = context.select(
      (RecordingBloc bloc) => bloc.state.lensChoices.length > 1,
    );
    final (bool dualSupported, bool dual) = context.select(
      (RecordingBloc bloc) => (bloc.state.dualSupported, bloc.state.dual),
    );
    final RecordingBloc bloc = context.read<RecordingBloc>();
    final OsdColors colors = context.colors;
    final int shown = _pending ?? clipSeconds;
    return BlocListener<RecordingBloc, RecordingState>(
      listenWhen: (RecordingState previous, RecordingState current) =>
          previous.clipSeconds != current.clipSeconds,
      listener: (BuildContext context, RecordingState state) =>
          setState(() => _pending = null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: OsdSpace.sheetGap,
        children: <Widget>[
          OsdCard(
            tone: OsdCardTone.c2,
            radius: OsdRadius.r20,
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(OsdSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: OsdSpace.s14,
              children: <Widget>[
                // The slider says both, its name and its value.
                ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          Strings.clipLength,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.buttonNeutral.copyWith(
                            color: colors.tx,
                          ),
                        ),
                      ),
                      _LengthValue(
                        key: RecordingSettingsSheet.valueKey,
                        text: RecordingSettingsSheet.lengthLabel(shown),
                      ),
                    ],
                  ),
                ),
                // The slider runs over the steps' indexes, a tick each, so
                // the track is non-linear in seconds.
                OsdSlider(
                  key: RecordingSettingsSheet.sliderKey,
                  value: RecordingLengthSteps.indexOf(shown).toDouble(),
                  min: 0,
                  max: RecordingLengthSteps.lastIndex.toDouble(),
                  divisions: RecordingLengthSteps.lastIndex,
                  marks: <OsdSliderMark>[
                    for (final int mark in RecordingSettingsSheet.marks)
                      OsdSliderMark(
                        value: RecordingLengthSteps.indexOf(mark).toDouble(),
                        label: RecordingSettingsSheet.lengthLabel(mark),
                      ),
                  ],
                  semanticsLabel: Strings.clipLength,
                  semanticsValue: (double value) =>
                      Strings.cameraClipLengthSeconds(
                        RecordingLengthSteps.at(value.round()),
                        format: CameraNumbers.of(context),
                      ),
                  onChanged: (double value) => setState(
                    () => _pending = RecordingLengthSteps.at(value.round()),
                  ),
                  onChangeEnd: (double value) {
                    final int seconds = RecordingLengthSteps.at(value.round());
                    bloc.add(RecordingClipSecondsChanged(seconds));
                    // The length the camera has: nothing will come back.
                    if (seconds == clipSeconds) setState(() => _pending = null);
                  },
                ),
              ],
            ),
          ),
          // No empty child otherwise: the column would space it.
          if (severalLenses) const _LensChoices(),
          if (dual) const _DualLayouts(),
          OsdCard(
            tone: OsdCardTone.c2,
            radius: OsdRadius.r20,
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                OsdListRow(
                  key: RecordingSettingsSheet.countdownKey,
                  title: Strings.countdown,
                  subtitle: Strings.countdownHint,
                  toggled: countdown,
                  haptic: OsdHaptic.selection,
                  trailing: OsdRowTrailing.custom(
                    OsdSwitch(value: countdown, interactive: false),
                  ),
                  onTap: () => bloc.add(const RecordingCountdownToggled()),
                ),
                const OsdDivider(),
                OsdListRow(
                  key: RecordingSettingsSheet.flashKey,
                  title: Strings.recordingSettingsFlash,
                  subtitle: canUseFlash
                      ? Strings.recordingSettingsFlashSubtitle
                      : Strings.recordingSettingsFlashSubtitleUnavailable,
                  enabled: canUseFlash,
                  toggled: flash,
                  haptic: OsdHaptic.selection,
                  trailing: OsdRowTrailing.custom(
                    OsdSwitch(value: flash, interactive: false),
                  ),
                  onTap: () => bloc.add(const RecordingFlashToggled()),
                ),
                if (dualSupported) ...<Widget>[
                  const OsdDivider(),
                  OsdListRow(
                    key: RecordingSettingsSheet.dualKey,
                    title: Strings.recordingSettingsDual,
                    subtitle: Strings.recordingSettingsDualSubtitle,
                    toggled: dual,
                    haptic: OsdHaptic.selection,
                    trailing: OsdRowTrailing.custom(
                      OsdSwitch(value: dual, interactive: false),
                    ),
                    onTap: () => bloc.add(const RecordingDualToggled()),
                  ),
                ],
                const OsdDivider(),
                OsdListRow(
                  key: RecordingSettingsSheet.lockKey,
                  title: Strings.recordingSettingsLockOrientation,
                  subtitle: landscape
                      ? Strings
                            .recordingSettingsLockOrientationSubtitleLandscape
                      : Strings
                            .recordingSettingsLockOrientationSubtitlePortrait,
                  // Both cameras record upright only.
                  enabled: !dual,
                  toggled: locked,
                  haptic: OsdHaptic.selection,
                  trailing: OsdRowTrailing.custom(
                    OsdSwitch(value: locked, interactive: false),
                  ),
                  onTap: () => bloc.add(const RecordingLockToggled()),
                ),
              ],
            ),
          ),
          NeutralButton(
            key: RecordingSettingsSheet.doneKey,
            label: Strings.done,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// The lenses of the side in use, a tile each (the sheet shows it when
/// there are several): a tap opens that lens in place of the one open, for
/// this camera only; the camera switch goes back to the side's first.
class _LensChoices extends StatelessWidget {
  const _LensChoices();

  @override
  Widget build(BuildContext context) {
    final (List<CameraLens> lenses, CameraLens? open) = context.select(
      (RecordingBloc bloc) => (bloc.state.lensChoices, bloc.state.lens),
    );
    return Column(
      key: RecordingSettingsSheet.lensesKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: OsdSpace.s8,
      children: <Widget>[
        SectionLabel.soft(label: Strings.cameraLens),
        Row(
          spacing: OsdSpace.s8,
          children: <Widget>[
            for (final (int index, CameraLens lens) in lenses.indexed)
              Expanded(
                child: OptionTile(
                  label: switch (lens.kind) {
                    CameraLensKind.wide => Strings.cameraLensWide,
                    CameraLensKind.ultraWide => Strings.cameraLensUltraWide,
                    CameraLensKind.telephoto => Strings.cameraLensTelephoto,
                    CameraLensKind.unknown => Strings.cameraLensNumbered(
                      number: index + 1,
                    ),
                  },
                  selected: lens == open,
                  onTap: () => context.read<RecordingBloc>().add(
                    RecordingLensPicked(lens),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// How both cameras' pictures share the clip, a tile each, while the page
/// records with both: a tap lays them out at once, behind the sheet too.
class _DualLayouts extends StatelessWidget {
  const _DualLayouts();

  @override
  Widget build(BuildContext context) {
    final DualCameraLayout layout = context.select(
      (RecordingBloc bloc) => bloc.state.dualLayout,
    );
    return Column(
      key: RecordingSettingsSheet.dualLayoutsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: OsdSpace.s8,
      children: <Widget>[
        SectionLabel.soft(label: Strings.cameraDualLayout),
        Row(
          spacing: OsdSpace.s8,
          children: <Widget>[
            for (final DualCameraLayout tile in DualCameraLayout.values)
              Expanded(
                child: OptionTile(
                  label: switch (tile) {
                    DualCameraLayout.inset => Strings.cameraDualLayoutInset,
                    DualCameraLayout.split => Strings.cameraDualLayoutSplit,
                  },
                  selected: tile == layout,
                  onTap: () => context.read<RecordingBloc>().add(
                    RecordingDualLayoutChanged(tile),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The clip length ("2s"): a new value slides up and fades in, the old one
/// fades out.
class _LengthValue extends StatelessWidget {
  const _LengthValue({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.countTick),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Widget faded = FadeTransition(opacity: animation, child: child);
        if (reduced) return faded;
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) => Transform.translate(
            offset: Offset(0, OsdMotion.countTickSlide * (1 - animation.value)),
            child: child,
          ),
          child: faded,
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        maxLines: 1,
        style: context.typography.displayValue.copyWith(
          color: context.colors.tx,
        ),
      ),
    );
  }
}
