import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/tab_reselect_listener.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:one_second_diary/features/settings/domain/app_links.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/dialogs/contact_dialog.dart';
import 'package:one_second_diary/features/settings/presentation/settings_labels.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/about_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/active_profile_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/dark_mode_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/language_setting_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/link_failure_listener.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/places_setting_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/reminder_setting_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/settings_feedback_listener.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/tags_setting_row.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/your_name_row.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_display_title.dart';
import 'package:one_second_diary/shared/widgets/identity/github_mark.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The Settings tab: the display title, then three cards of rows.
///
/// Every value comes from memory: the app-scoped cubits, the reminder
/// settings and the version the tab read once. Each row watches only what
/// it shows. A failed change or link shows a snackbar above the nav.
/// Tapping the Settings tab again scrolls back to the top.
class SettingsTabPage extends StatefulWidget {
  const SettingsTabPage({super.key, required this.platform});

  static const Key listKey = Key('settingsTab.list');

  static const Key darkModeRowKey = Key('settingsTab.darkMode');
  static const Key languageRowKey = Key('settingsTab.language');
  static const Key notificationsRowKey = Key('settingsTab.notifications');
  static const Key yourNameRowKey = Key('settingsTab.yourName');
  static const Key profilesRowKey = Key('settingsTab.profiles');
  static const Key tagsRowKey = Key('settingsTab.tags');
  static const Key placesRowKey = Key('settingsTab.places');
  static const Key preferencesRowKey = Key('settingsTab.preferences');
  static const Key phoneCheckRowKey = Key('settingsTab.phoneCheck');
  static const Key backupRowKey = Key('settingsTab.backup');
  static const Key supportRowKey = Key('settingsTab.support');
  static const Key shareRowKey = Key('settingsTab.share');
  static const Key contactRowKey = Key('settingsTab.contact');
  static const Key websiteRowKey = Key('settingsTab.website');

  static const Key sourceCodeRowKey = Key('settingsTab.sourceCode');
  static const Key aboutRowKey = Key('settingsTab.about');

  final SettingsPlatform platform;

  @override
  State<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends State<SettingsTabPage> {
  final ScrollController _scroll = ScrollController();

  /// Checks the reminder's permission on resume: the user may have allowed
  /// it in the phone's settings.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          unawaited(context.read<ReminderSettingsCubit>().checkAccess()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsPlatform platform = widget.platform;
    return SettingsFeedbackListener(
      child: LinkFailureListener(
        child: ColoredBox(
          color: context.colors.bg,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OsdSizes.contentMaxWidth,
                ),
                child: TabReselectListener(
                  tab: AppRoute.settings,
                  scrollController: _scroll,
                  child: CustomScrollView(
                    key: SettingsTabPage.listKey,
                    controller: _scroll,
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: OsdDisplayTitle(
                          title: Strings.settings,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            20,
                            14,
                            20,
                            2,
                          ),
                        ),
                      ),
                      const _SettingsCard(
                        rows: <Widget>[
                          DarkModeRow(key: SettingsTabPage.darkModeRowKey),
                          LanguageSettingRow(
                            key: SettingsTabPage.languageRowKey,
                          ),
                          ReminderSettingRow(
                            key: SettingsTabPage.notificationsRowKey,
                          ),
                        ],
                      ),
                      _SettingsCard(
                        rows: <Widget>[
                          const YourNameRow(
                            key: SettingsTabPage.yourNameRowKey,
                          ),
                          const ActiveProfileRow(
                            key: SettingsTabPage.profilesRowKey,
                          ),
                          const TagsSettingRow(key: SettingsTabPage.tagsRowKey),
                          const PlacesSettingRow(
                            key: SettingsTabPage.placesRowKey,
                          ),
                          OsdListRow(
                            key: SettingsTabPage.preferencesRowKey,
                            title: SettingsLabels.preferences,
                            icon: OsdIcons.tune,
                            trailing: const OsdRowTrailing.chevron(),
                            onTap: () =>
                                AppRoute.preferences.push<void>(context),
                          ),
                          OsdListRow(
                            key: SettingsTabPage.phoneCheckRowKey,
                            title: Strings.phoneCheckBenchmark,
                            icon: OsdIcons.speed,
                            trailing: const OsdRowTrailing.chevron(),
                            onTap: () =>
                                AppRoute.phoneCheck.push<void>(context),
                          ),
                          if (platform.showsBackupSheet)
                            OsdListRow(
                              key: SettingsTabPage.backupRowKey,
                              title: Strings.backupRestore,
                              icon: OsdIcons.backup,
                              trailing: const OsdRowTrailing.chevron(),
                              onTap: () => unawaited(BackupSheet.show(context)),
                            ),
                        ],
                      ),
                      _SettingsCard(
                        rows: <Widget>[
                          if (platform.showsDonationLinks)
                            OsdListRow(
                              key: SettingsTabPage.supportRowKey,
                              title: Strings.donationPageTitle,
                              icon: OsdIcons.localCafe,
                              iconColor: context.colors.yellow,
                              trailing: const OsdRowTrailing.chevron(),
                              onTap: () => AppRoute.support.push<void>(context),
                            ),
                          const _ShareRow(),
                          OsdListRow(
                            key: SettingsTabPage.contactRowKey,
                            title: Strings.contact,
                            icon: OsdIcons.mail,
                            onTap: () => ContactDialog.show(context),
                          ),
                          OsdListRow(
                            key: SettingsTabPage.websiteRowKey,
                            title: Strings.website,
                            icon: OsdIcons.language,
                            trailing: const OsdRowTrailing.external(),
                            semanticsHint: Strings.opensInBrowserHint,
                            onTap: () => _open(AppLinks.website),
                          ),
                          OsdListRow(
                            key: SettingsTabPage.sourceCodeRowKey,
                            title: Strings.sourceCode,
                            leading: const GithubMark(),
                            trailing: const OsdRowTrailing.external(),
                            semanticsHint: Strings.opensInBrowserHint,
                            onTap: () => _open(AppLinks.repository),
                          ),
                          const AboutRow(key: SettingsTabPage.aboutRowKey),
                        ],
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              OsdSpace.s24 +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(Uri link) => unawaited(context.read<LinkCubit>().open(link));
}

/// A settings card of [rows] with dividers between them.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.only(top: OsdSpace.cardGap),
    sliver: SliverToBoxAdapter(
      child: OsdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const OsdDivider(),
              rows[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// "Share with a friend": the app's share message in the system share
/// sheet, anchored on the row (iPad).
class _ShareRow extends StatelessWidget {
  const _ShareRow();

  @override
  Widget build(BuildContext context) => OsdListRow(
    key: SettingsTabPage.shareRowKey,
    title: Strings.settingsShareWithFriend,
    icon: OsdIcons.share,
    onTap: () {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      unawaited(
        context.read<SettingsCubit>().shareApp(
          text: Strings.shareAppMessage(url: AppLinks.share.toString()),
          origin: box == null || !box.hasSize
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    },
  );
}
