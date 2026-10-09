import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/about_hero.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// About: the hero (logo, name, version, copyright), then a card of three
/// pages: Changelog, Special thanks and Licenses. On iOS a line under them
/// says that deleting the app deletes the videos.
///
/// It opens from memory: the version fades in once read, without a spinner.
/// The page scrolls when the text is large.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.platform});

  static const Key listKey = Key('aboutPage.list');
  static const Key changelogRowKey = Key('aboutPage.changelog');
  static const Key thanksRowKey = Key('aboutPage.thanks');
  static const Key licensesRowKey = Key('aboutPage.licenses');

  /// The iOS line about backing up before uninstalling.
  static const Key backupWarningKey = Key('aboutPage.backupWarning');

  final SettingsPlatform platform;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(title: Strings.about),
      body: OsdSnackbarHost(
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
                  const AboutHero(),
                  OsdCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        OsdListRow(
                          key: changelogRowKey,
                          title: Strings.aboutChangelog,
                          icon: OsdIcons.history,
                          iconColor: colors.greenInk,
                          trailing: const OsdRowTrailing.chevron(),
                          onTap: () => AppRoute.changelog.push<void>(context),
                        ),
                        const OsdDivider(),
                        OsdListRow(
                          key: thanksRowKey,
                          title: Strings.thanksTo,
                          icon: OsdIcons.favorite,
                          iconFill: 1,
                          iconColor: colors.co,
                          trailing: const OsdRowTrailing.chevron(),
                          onTap: () => AppRoute.thanks.push<void>(context),
                        ),
                        const OsdDivider(),
                        OsdListRow(
                          key: licensesRowKey,
                          title: Strings.licenses,
                          icon: OsdIcons.gavel,
                          trailing: const OsdRowTrailing.chevron(),
                          onTap: () => AppRoute.licenses.push<void>(context),
                        ),
                      ],
                    ),
                  ),
                  if (platform.showsBackupWarning)
                    const _BackupWarning(key: backupWarningKey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The iOS footnote under the card: as many lines as the text needs (it
/// must never be cut at large text). Tapping it opens the Backup & restore
/// sheet.
class _BackupWarning extends StatelessWidget {
  const _BackupWarning({super.key});

  static const double _glyph = 18;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return OsdPressable(
      onTap: () => unawaited(BackupSheet.show(context)),
      child: _warning(context, colors),
    );
  }

  Widget _warning(BuildContext context, OsdColors colors) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        OsdSpace.textInset,
        OsdSpace.s12,
        OsdSpace.textInset,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OsdSpace.iconLabelGap,
        children: <Widget>[
          OsdIcon(OsdIcons.warning, size: _glyph, color: colors.yellowInk),
          Expanded(
            child: Text(
              Strings.iosBackupWarning,
              style: context.typography.footnote.copyWith(color: colors.d2),
            ),
          ),
        ],
      ),
    );
  }
}
