import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/changelog_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/changelog_state.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/document_scaffold.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Changelog: the bundled `CHANGELOG.md`, newest release first. Each
/// release is a section label over a card of its changes, one row each,
/// with the indented details under their change.
///
/// The list is lazy: a release is built when it scrolls into view.
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  static const Key listKey = Key('changelogPage.list');

  /// The section of the release titled [title], the heading as written.
  static Key releaseKey(String title) =>
      ValueKey<String>('changelogPage.release.$title');

  @override
  Widget build(BuildContext context) {
    final ChangelogState state = context.watch<ChangelogCubit>().state;
    return DocumentScaffold(
      title: Strings.aboutChangelog,
      status: state.status,
      unavailableIcon: OsdIcons.history,
      child: state.status != DocumentStatus.ready
          ? null
          : ListView.builder(
              key: listKey,
              padding: const EdgeInsets.only(bottom: OsdSpace.s24),
              itemCount: state.releases.length,
              itemBuilder: (BuildContext context, int index) {
                final ChangelogRelease release = state.releases[index];
                return _ReleaseSection(
                  key: releaseKey(release.title),
                  release: release,
                );
              },
            ),
    );
  }
}

class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection({super.key, required this.release});

  final ChangelogRelease release;

  @override
  Widget build(BuildContext context) {
    final List<ChangelogItem> items = release.items;
    // Each label and each change is a semantics node of its own: the
    // label's heading flag would otherwise take in the changes' text.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          container: true,
          child: SectionLabel.soft(
            label: _ReleaseTitle.of(context, release),
            sub: true,
            padding: const EdgeInsetsDirectional.fromSTEB(
              OsdSpace.textInset,
              OsdSpace.s22,
              OsdSpace.textInset,
              OsdSpace.s8,
            ),
          ),
        ),
        OsdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                if (i > 0) const OsdDivider(),
                Semantics(container: true, child: _ChangeRow(item: items[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.item});

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: OsdSpace.rowPadH,
    vertical: OsdSpace.s12,
  );

  final ChangelogItem item;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final TextStyle text = context.typography.body15Loose;
    return Padding(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OsdSpace.s6,
        children: <Widget>[
          Text(item.text, style: text.copyWith(color: colors.tx)),
          for (final String detail in item.details)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: OsdSpace.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: OsdSpace.s8,
                children: <Widget>[
                  ExcludeSemantics(
                    child: Text('•', style: text.copyWith(color: colors.mu)),
                  ),
                  Expanded(
                    child: Text(detail, style: text.copyWith(color: colors.mu)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Version 1.7.1 · September 2026": the translated version label and the
/// release month in the app language, or the heading as written when it
/// names no version.
abstract final class _ReleaseTitle {
  static String of(BuildContext context, ChangelogRelease release) {
    final String? version = release.version;
    if (version == null) return release.title;
    final String label = Strings.appVersion(version: version);
    final DateTime? month = release.month;
    if (month == null) return label;
    return Strings.changelogReleaseTitle(
      version: label,
      date: LocaleFormats.of(context).date('yMMMM').format(month),
    );
  }
}
