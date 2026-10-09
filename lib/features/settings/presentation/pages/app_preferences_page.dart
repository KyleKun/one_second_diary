import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/imports/import_labels.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_state.dart';
import 'package:one_second_diary/features/settings/presentation/settings_labels.dart';
import 'package:one_second_diary/shared/widgets/buttons/destructive_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// Preferences: three sections (Recording, Gallery, Accessibility &
/// support), each a card of switch rows. The whole row toggles and
/// stores the change at once. Under "Keep original recordings" the row
/// says about how much one recording adds; after the Recording card, the
/// "Original videos" group says what the Originals folder holds (kept
/// recordings and processed imports' originals, "3 videos · 850 MB"),
/// what the folder is, and offers "Delete originals" (a warning first)
/// while the switch is on or the folder holds anything.
///
/// "Filter by date" needs the in-app picker, so while that is off it shows
/// off, dims and takes no taps. Below Android 10, "Force native camera"
/// shows on and locked, and says why. A setting the phone refuses to store
/// goes back, with a snackbar.
class AppPreferencesPage extends StatelessWidget {
  const AppPreferencesPage({super.key});

  static const Key listKey = Key('appPreferencesPage.list');

  static Key rowKey(AppPreference preference) =>
      ValueKey<String>('appPreferencesPage.row.${preference.name}');

  /// The "Original videos" group's summary row ("3 videos · 850 MB").
  static const Key originalVideosKey = Key('appPreferencesPage.originalVideos');

  /// The "Delete originals" button of the "Original videos" group.
  static const Key deleteOriginalsKey = Key(
    'appPreferencesPage.deleteOriginals',
  );

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(title: SettingsLabels.preferences),
      body: OsdSnackbarHost(
        child: BlocListener<PreferencesCubit, PreferencesState>(
          listenWhen: (PreferencesState previous, PreferencesState current) =>
              previous.status != current.status &&
              current.status == PreferencesStatus.saveFailed,
          listener: (BuildContext context, _) => OsdSnackbar.show(
            context,
            kind: OsdSnackKind.error,
            title: Strings.preferencesSaveFailed,
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OsdSizes.contentMaxWidth,
                ),
                child: ListView(
                  key: listKey,
                  padding: const EdgeInsets.only(bottom: OsdSpace.s24),
                  children: <Widget>[
                    SectionLabel.icon(
                      label: Strings.preferencesSectionRecording,
                      icon: OsdIcons.videocam,
                      iconColor: colors.co,
                    ),
                    const _PreferencesCard(
                      preferences: <AppPreference>[
                        AppPreference.forceNativeCamera,
                        AppPreference.legacyStampFont,
                        AppPreference.clipDeviceInfo,
                        AppPreference.keepOriginals,
                      ],
                    ),
                    const _OriginalVideosGroup(),
                    SectionLabel.icon(
                      label: Strings.preferencesSectionGallery,
                      icon: OsdIcons.photoLibrary,
                      iconColor: colors.purple,
                    ),
                    const _PreferencesCard(
                      preferences: <AppPreference>[
                        AppPreference.experimentalPicker,
                        AppPreference.filterByDate,
                      ],
                    ),
                    SectionLabel.icon(
                      label: Strings.preferencesSectionAccessibility,
                      icon: OsdIcons.accessibilityNew,
                      iconColor: colors.greenInk,
                    ),
                    const _PreferencesCard(
                      preferences: <AppPreference>[
                        AppPreference.alternativeCalendarColors,
                        AppPreference.verboseLogging,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({required this.preferences});

  final List<AppPreference> preferences;

  @override
  Widget build(BuildContext context) => OsdCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < preferences.length; i++) ...<Widget>[
          if (i > 0) const OsdDivider(),
          _PreferenceRow(preference: preferences[i]),
        ],
      ],
    ),
  );
}

/// "Original videos": what the Originals folder holds ("3 videos ·
/// 850 MB", or that it holds nothing yet), one line on what the folder
/// is, and "Delete originals", which warns first (Edit again goes with
/// them, a processed import's original is gone for good, the clips stay)
/// and then empties the folder through the cubit. Shown while "Keep
/// original recordings" is on or the folder holds anything; gone
/// otherwise.
class _OriginalVideosGroup extends StatelessWidget {
  const _OriginalVideosGroup();

  Future<void> _ask(BuildContext context, int count, int bytes) async {
    final PreferencesCubit cubit = context.read<PreferencesCubit>();
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.deleteOriginalsTitle,
      body: Strings.deleteOriginalsWarning(
        count,
        size: ImportLabels.size(context, bytes),
        format: ImportLabels.numberFormat(context),
      ),
      cancelLabel: CommonLabels.of(context).cancel,
      confirmLabel: Strings.deleteOriginals,
      destructive: true,
      badgeIcon: OsdIcons.delete,
    );
    if (confirmed) await cubit.deleteOriginals();
  }

  @override
  Widget build(BuildContext context) {
    final (
      bool shows,
      int count,
      int bytes,
      bool canDelete,
      bool deleting,
    ) = context.select(
      (PreferencesCubit cubit) => (
        cubit.state.showsOriginals,
        cubit.state.originalsCount ?? 0,
        cubit.state.originalsBytes ?? 0,
        cubit.state.canDeleteOriginals,
        cubit.state.deletingOriginals,
      ),
    );
    if (!shows) return const SizedBox.shrink();
    final OsdColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel.icon(
          label: Strings.originalVideosSection,
          icon: OsdIcons.videoLibrary,
          iconColor: colors.co,
        ),
        OsdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              OsdListRow(
                key: AppPreferencesPage.originalVideosKey,
                title: count > 0
                    ? Strings.originalVideosCount(
                        count,
                        size: ImportLabels.size(context, bytes),
                        format: ImportLabels.numberFormat(context),
                      )
                    : Strings.originalVideosNone,
                subtitle: Strings.originalVideosDescription,
                icon: OsdIcons.videoLibrary,
                iconColor: colors.co,
              ),
              const OsdDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OsdSpace.s16,
                  OsdSpace.s12,
                  OsdSpace.s16,
                  OsdSpace.s16,
                ),
                child: DestructiveButton(
                  key: AppPreferencesPage.deleteOriginalsKey,
                  label: Strings.deleteOriginals,
                  icon: OsdIcons.delete,
                  loading: deleting,
                  onPressed: canDelete
                      ? () => unawaited(_ask(context, count, bytes))
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One switch row: the switch is visual only; the row owns the gesture and
/// the `toggled` semantics. It rebuilds only when its own switch changes.
class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.preference});

  final AppPreference preference;

  /// The opacity of a row that can't be changed.
  static const double _dimmed = .4;

  @override
  Widget build(BuildContext context) {
    final (bool on, bool enabled, bool required, int? perRecording) = context
        .select(
          (PreferencesCubit cubit) => (
            cubit.state.isOn(preference),
            cubit.state.isEnabled(preference),
            preference == AppPreference.forceNativeCamera &&
                cubit.state.nativeCameraRequired,
            preference == AppPreference.keepOriginals
                ? cubit.state.perRecordingBytes
                : null,
          ),
        );
    final (String title, String subtitle) = switch (preference) {
      AppPreference.forceNativeCamera => (
        Strings.forceNativeCamera,
        required
            ? Strings.preferencesRequiredOnThisAndroid
            : Strings.forceNativeCameraDescription,
      ),
      AppPreference.legacyStampFont => (
        Strings.legacyStampFont,
        Strings.legacyStampFontDescription,
      ),
      AppPreference.clipDeviceInfo => (
        Strings.clipDeviceInfo,
        Strings.clipDeviceInfoDescription,
      ),
      AppPreference.keepOriginals => (
        Strings.keepOriginals,
        perRecording == null
            ? Strings.keepOriginalsDescription
            : '${Strings.keepOriginalsDescription}\n'
                  '${Strings.keepOriginalsPerRecording(size: ImportLabels.size(context, perRecording))}',
      ),
      AppPreference.experimentalPicker => (
        Strings.useExperimentalPicker,
        Strings.useExperimentalPickerDescription,
      ),
      AppPreference.filterByDate => (
        Strings.useFilterInExperimentalPicker,
        Strings.preferencesFilterByDateSubtitle,
      ),
      AppPreference.alternativeCalendarColors => (
        Strings.useAlternativeCalendarColors,
        Strings.preferencesAltCalendarColorsSubtitle,
      ),
      AppPreference.verboseLogging => (
        Strings.verboseLogging,
        Strings.verboseLoggingDescription,
      ),
    };
    return AnimatedOpacity(
      opacity: enabled ? 1 : _dimmed,
      duration: OsdMotion.d(context, OsdMotion.selection),
      curve: OsdMotion.curve(context, OsdMotion.selectionCurve),
      child: OsdListRow(
        key: AppPreferencesPage.rowKey(preference),
        title: title,
        subtitle: subtitle,
        trailing: OsdRowTrailing.custom(
          OsdSwitch(value: on, interactive: false),
        ),
        toggled: on,
        haptic: OsdHaptic.selection,
        onTap: enabled
            ? () => unawaited(
                context.read<PreferencesCubit>().set(preference, !on),
              )
            : null,
      ),
    );
  }
}
