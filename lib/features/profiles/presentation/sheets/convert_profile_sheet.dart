import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_state.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/quality_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_name_field.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/quality_row.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/field_label.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Makes the cubit of one "Convert into a new profile" sheet, for the
/// profile it converts. Provided at the app root (composed in
/// `profiles_injection.dart`), read by [ConvertProfileSheet.show].
typedef ConvertProfileFactory = ConvertProfileCubit Function(ProfileKey source);

/// The "Convert into a new profile" sheet: name (default `<name> 4K`),
/// quality, the estimate card and "Convert". While it runs it shows progress
/// and cannot be dismissed; Stop ends the run after the clip in flight.
///
/// Open it with [show]; it needs a `ConvertProfileFactory` above.
class ConvertProfileSheet extends StatelessWidget {
  const ConvertProfileSheet({super.key});

  static const Key sheetKey = Key('convertProfileSheet');
  static const Key nameKey = Key('convertProfileSheet.name');
  static const Key startKey = Key('convertProfileSheet.start');
  static const Key estimateKey = Key('convertProfileSheet.estimate');
  static const Key progressKey = Key('convertProfileSheet.progress');
  static const Key cancelKey = Key('convertProfileSheet.cancel');
  static const Key doneKey = Key('convertProfileSheet.done');

  /// Opens the sheet for [source]. Completes when it closes.
  static Future<void> show(BuildContext context, {required ProfileKey source}) {
    final ConvertProfileFactory forms = context.read<ConvertProfileFactory>();
    return showOsdSheet<void>(
      context,
      title: Strings.convertProfileTitle,
      subtitle: Strings.qualityFixed,
      looseSubtitle: true,
      child: BlocProvider<ConvertProfileCubit>(
        create: (_) => forms(source),
        child: const ConvertProfileSheet(key: sheetKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OsdSnackbarHost(
    child: BlocListener<ConvertProfileCubit, ConvertProfileState>(
      listenWhen: (ConvertProfileState before, ConvertProfileState now) =>
          before.status != now.status,
      listener: (BuildContext context, ConvertProfileState state) {
        OsdSheetRoute.setBusy(context, busy: state.isBusy);
        switch (state.status) {
          case ConvertProfileStatus.startFailed:
            OsdSnackbar.show(
              context,
              kind: OsdSnackKind.error,
              title: Strings.profileSaveFailed,
            );
          case ConvertProfileStatus.editing ||
              ConvertProfileStatus.estimating ||
              ConvertProfileStatus.starting ||
              ConvertProfileStatus.running ||
              ConvertProfileStatus.done ||
              ConvertProfileStatus.cancelled:
            break;
        }
      },
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: OsdSpace.sheetGap,
        children: <Widget>[
          _NameField(),
          _TargetRow(),
          _EstimateCard(),
          _ProgressCard(),
          _BottomButton(),
        ],
      ),
    ),
  );
}

/// The new profile's name, pre-filled, checked like any new name.
class _NameField extends StatefulWidget {
  const _NameField();

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<ConvertProfileCubit>().state.name,
  );

  static final RegExp _controls = RegExp(
    r'[\p{Cc}\p{Zl}\p{Zp}]',
    unicode: true,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (String name, ProfileNameError? error, bool busy) = context.select(
      (ConvertProfileCubit cubit) =>
          (cubit.state.name, cubit.state.shownNameError, cubit.state.isBusy),
    );
    // The pre-fill follows the target until the user types.
    if (_name.text != name && !_name.selection.isValid) _name.text = name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        FieldLabel(label: Strings.convertProfileName),
        OsdTextField(
          key: ConvertProfileSheet.nameKey,
          controller: _name,
          hint: Strings.enterProfileName,
          leadingIcon: OsdIcons.badge,
          errorText: switch (error) {
            null => null,
            ProfileNameError.empty => Strings.profileNameCannotBeEmpty,
            ProfileNameError.duplicate => Strings.profileNameAlreadyExists,
            ProfileNameError.reserved => Strings.reservedProfileName,
            ProfileNameError.invalidCharacters =>
              Strings.profileNameCannotContainSpecialChars,
          },
          maxLength: ProfileNameField.maxLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.deny(_controls),
          ],
          enabled: !busy,
          onChanged: context.read<ConvertProfileCubit>().nameChanged,
        ),
      ],
    );
  }
}

/// The target quality row, opening the quality sheet.
class _TargetRow extends StatelessWidget {
  const _TargetRow();

  Future<void> _open(BuildContext context) async {
    final ConvertProfileCubit cubit = context.read<ConvertProfileCubit>();
    final ClipFormat? picked = await QualitySheet.show(
      context,
      orientation: cubit.state.source.orientation,
      recommendation: cubit.state.recommendation,
      selected: cubit.state.target,
    );
    if (picked != null) await cubit.targetPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final (ClipFormat? target, bool busy, bool same) = context.select(
      (ConvertProfileCubit cubit) =>
          (cubit.state.target, cubit.state.isBusy, cubit.state.sameQuality),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        QualityRow(
          format: target,
          enabled: !busy,
          onTap: () => unawaited(_open(context)),
        ),
        if (same)
          Text(
            Strings.convertProfileSameQuality,
            style: context.typography.caption.copyWith(
              color: context.colors.red,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}

/// "12 clips · 24 s · about 3 minutes on this phone · 1.2 GB needed", and
/// the shortfall when it does not fit.
class _EstimateCard extends StatelessWidget {
  const _EstimateCard();

  @override
  Widget build(BuildContext context) {
    final (ConversionEstimate? estimate, bool estimating) = context.select(
      (ConvertProfileCubit cubit) => (
        cubit.state.estimate,
        cubit.state.status == ConvertProfileStatus.estimating,
      ),
    );
    if (estimate == null) {
      return OsdCallout.neutral(
        key: ConvertProfileSheet.estimateKey,
        text: estimating
            ? Strings.convertProfileEstimating
            : Strings.qualityNotChecked,
      );
    }
    final LocaleFormats formats = LocaleFormats.of(context);
    final StorageVerdict verdict = estimate.verdict;
    final String line = Strings.convertProfileEstimate(
      clips: Strings.clipCount(estimate.clipCount, format: formats.numbers),
      length: ProfileLabels.duration((estimate.totalDurationMs / 1000).round()),
      time: ProfileLabels.duration(estimate.estimatedTime.inSeconds),
      space: ProfileLabels.bytes(estimate.neededBytes, format: formats.numbers),
    );
    final OsdTypography typography = context.typography;
    final OsdColors colors = context.colors;
    return Column(
      key: ConvertProfileSheet.estimateKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        OsdCallout.neutral(text: line),
        if (verdict case StorageShort(:final int shortfallBytes))
          Text(
            Strings.storageShort(
              amount: ProfileLabels.bytes(
                shortfallBytes,
                format: formats.numbers,
              ),
            ),
            style: typography.caption.copyWith(color: colors.red, height: 1.4),
          ),
      ],
    );
  }
}

/// The run: "n of N · about 12 min left" over a bar and "keep the app
/// open" while it goes on; "Converted into {name}" or "Stopped: {name}
/// keeps what was converted" once it ended, with "The new profile has no
/// original recordings" under it when a kept original could not be copied.
/// Nothing before it starts.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  static const Key noSourcesKey = Key('convertProfileSheet.noSources');

  @override
  Widget build(BuildContext context) {
    final (
      ConvertProfileStatus status,
      ConversionProgress? progress,
      Profile? created,
      ConversionReport? report,
    ) = context.select(
      (ConvertProfileCubit cubit) => (
        cubit.state.status,
        cubit.state.progress,
        cubit.state.created,
        cubit.state.report,
      ),
    );
    final String? name = created?.displayName;
    switch (status) {
      case ConvertProfileStatus.editing ||
          ConvertProfileStatus.estimating ||
          ConvertProfileStatus.starting ||
          ConvertProfileStatus.startFailed:
        return const SizedBox.shrink();
      case ConvertProfileStatus.done:
        return _Ended(
          text: Strings.convertProfileDone(name: name ?? ''),
          noSources: (report?.sourcesSkipped ?? 0) > 0,
        );
      case ConvertProfileStatus.cancelled:
        return _Ended(
          text: Strings.convertProfileCancelled(name: name ?? ''),
          noSources: (report?.sourcesSkipped ?? 0) > 0,
        );
      case ConvertProfileStatus.running:
        final LocaleFormats formats = LocaleFormats.of(context);
        final int total = progress?.total ?? 0;
        final int done = progress?.done ?? 0;
        return Column(
          key: ConvertProfileSheet.progressKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: OsdSpace.s8,
          children: <Widget>[
            OsdProgressBar(
              value: total == 0
                  ? 0
                  : (done + (progress?.fraction ?? 0)) / total,
            ),
            Text(
              Strings.convertProfileProgress(
                done: formats.numbers.format(done),
                total: formats.numbers.format(total),
                remaining: ProfileLabels.duration(
                  progress?.remaining.inSeconds ?? 0,
                ),
              ),
              style: context.typography.caption.copyWith(height: 1.4),
            ),
            Text(
              Strings.convertProfileKeepOpen,
              style: context.typography.caption.copyWith(
                color: context.colors.mu,
                height: 1.4,
              ),
            ),
          ],
        );
    }
  }
}

/// The ended run's callout, and the no-sources note when some kept
/// original was not copied into the new profile.
class _Ended extends StatelessWidget {
  const _Ended({required this.text, required this.noSources});

  final String text;
  final bool noSources;

  @override
  Widget build(BuildContext context) => Column(
    key: ConvertProfileSheet.progressKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s8,
    children: <Widget>[
      OsdCallout.neutral(text: text),
      if (noSources)
        Text(
          Strings.convertProfileNoSources,
          key: _ProgressCard.noSourcesKey,
          style: context.typography.caption.copyWith(
            color: context.colors.mu,
            height: 1.4,
          ),
        ),
    ],
  );
}

/// "Convert" (on with a valid name, another quality and room) before the
/// run, Stop while it goes on, Done once it ended.
class _BottomButton extends StatelessWidget {
  const _BottomButton();

  @override
  Widget build(BuildContext context) {
    final (bool canStart, ConvertProfileStatus status) = context.select(
      (ConvertProfileCubit cubit) => (cubit.state.canStart, cubit.state.status),
    );
    final ConvertProfileCubit cubit = context.read<ConvertProfileCubit>();
    return SnackbarAnchor(
      gap: OsdSpace.snackbarAboveCta,
      child: switch (status) {
        ConvertProfileStatus.running => NeutralButton(
          key: ConvertProfileSheet.cancelKey,
          label: Strings.processImportsStop,
          onPressed: cubit.cancel,
        ),
        ConvertProfileStatus.done ||
        ConvertProfileStatus.cancelled => PrimaryButton(
          key: ConvertProfileSheet.doneKey,
          label: Strings.done,
          haptic: OsdHaptic.light,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ConvertProfileStatus.editing ||
        ConvertProfileStatus.estimating ||
        ConvertProfileStatus.starting ||
        ConvertProfileStatus.startFailed => PrimaryButton(
          key: ConvertProfileSheet.startKey,
          label: Strings.convertProfileStart,
          haptic: OsdHaptic.medium,
          loading: status == ConvertProfileStatus.starting,
          onPressed: canStart ? () => unawaited(cubit.start()) : null,
        ),
      },
    );
  }
}
