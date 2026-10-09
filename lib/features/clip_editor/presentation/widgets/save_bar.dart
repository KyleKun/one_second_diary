import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/presentation/clip_canvas.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/stamp_texts.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';

/// The editor's Save bar, fixed under the scrolling part. While the page's
/// content goes on below it ([contentBelow]), a line shows on its top.
///
/// Save is off until the source is loaded and while a place is being
/// found. Tapped, the bar crossfades to the saving row: Cancel before
/// "Saving…", which fills with a darker sweep as the render goes. Cancel
/// is off once the clip is being filed.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, this.contentBelow = false});

  static const Key saveKey = Key('saveBar.save');

  static const Key cancelKey = Key('saveBar.cancel');

  static const Key progressKey = Key('saveBar.progress');

  /// The sweep inside "Saving…".
  static const Key fillKey = Key('saveBar.fill');

  /// The line on the bar's top.
  static const Key borderKey = Key('saveBar.border');

  /// Whether the scrolling part has more below the bar.
  final bool contentBelow;

  @override
  Widget build(BuildContext context) {
    final SaveStatus status = context.select(
      (EditClipCubit editor) => editor.state.saveStatus,
    );
    final bool saving = switch (status) {
      SaveStatus.rendering || SaveStatus.publishing || SaveStatus.saved => true,
      SaveStatus.idle || SaveStatus.cancelling || SaveStatus.failed => false,
    };
    final Duration fade = OsdMotion.d(context, OsdMotion.fast);
    return ColoredBox(
      color: context.colors.bg,
      child: Stack(
        children: <Widget>[
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                OsdSpace.pageGutter,
                OsdSpace.s10,
                OsdSpace.pageGutter,
                OsdSpace.bottomGap(context, OsdSpace.s24),
              ),
              child: AnimatedSwitcher(
                duration: fade,
                switchInCurve: OsdMotion.fastCurve,
                switchOutCurve: OsdMotion.fastCurve,
                child: saving
                    ? _SavingRow(
                        key: const ValueKey<String>('saving'),
                        cancellable: status == SaveStatus.rendering,
                      )
                    : const _SaveButton(key: ValueKey<String>('save')),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              key: SaveBar.borderKey,
              opacity: contentBelow ? 1 : 0,
              duration: fade,
              curve: OsdMotion.fastCurve,
              child: const OsdDivider.full(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    final bool canSave = context.select(
      (EditClipCubit editor) => editor.state.canSave,
    );
    return PrimaryButton(
      key: SaveBar.saveKey,
      label: Strings.save,
      icon: OsdIcons.save,
      size: OsdButtonSize.medium,
      haptic: OsdHaptic.light,
      onPressed: canSave ? () => _save(context) : null,
    );
  }

  /// Saves the clip as the preview shows it: the date in the app language
  /// with the phone's region, in the canvas of the clip's profile.
  static void _save(BuildContext context) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final EditClipState state = editor.state;
    unawaited(
      editor.save(
        ClipRenderLook(
          stampText: StampTexts.of(
            context,
            day: state.args.day,
            format: state.draft.stamp.format,
          ),
          format: ClipCanvas.formatOf(
            context.read<ProfilesCubit>().state,
            state.draft.profile,
          ),
        ),
      ),
    );
  }
}

class _SavingRow extends StatelessWidget {
  const _SavingRow({super.key, required this.cancellable});

  /// Whether the render still runs (Cancel is on).
  final bool cancellable;

  @override
  Widget build(BuildContext context) {
    final Widget cancel = NeutralButton(
      key: SaveBar.cancelKey,
      label: CommonLabels.of(context).cancel,
      size: OsdButtonSize.medium,
      onPressed: cancellable ? context.read<EditClipCubit>().cancelSave : null,
    );
    const Widget progress = _SavingProgress();
    return OsdTextScale.factorOf(context) > OsdTextScale.stackButtonRowsAbove
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: <Widget>[progress, cancel],
          )
        : Row(
            spacing: 12,
            children: <Widget>[
              Expanded(child: cancel),
              const Expanded(flex: 2, child: progress),
            ],
          );
  }
}

/// "Saving…" on coral, with the spinner in place of the icon and the
/// render's progress sweeping over it; read aloud with its percentage.
class _SavingProgress extends StatelessWidget {
  const _SavingProgress();

  /// 12 % black over the coral.
  static const Color _sweep = Color(0x1F000000);

  static String _percent(BuildContext context, double fraction) =>
      LocaleFormats.of(context).percent.format(fraction);

  @override
  Widget build(BuildContext context) {
    final double progress = context.select(
      (EditClipCubit editor) => editor.state.saveProgress,
    );
    return Semantics(
      key: SaveBar.progressKey,
      container: true,
      label: Strings.processingVideo,
      value: _percent(context, progress),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OsdButtonSize.medium.radius),
          child: Stack(
            children: <Widget>[
              PrimaryButton(
                label: Strings.processingVideo,
                icon: OsdIcons.save,
                size: OsdButtonSize.medium,
                loading: true,
                loadingLabel: Strings.processingVideo,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: OsdMotion.d(context, OsdMotion.processing),
                    curve: OsdMotion.processingCurve,
                    builder:
                        (BuildContext context, double value, Widget? child) =>
                            Transform.scale(
                              scaleX: value,
                              alignment: AlignmentDirectional.centerStart,
                              child: child,
                            ),
                    child: const ColoredBox(
                      key: SaveBar.fillKey,
                      color: _sweep,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
