import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/thanks_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/thanks_state.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/document_scaffold.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/link_failure_listener.dart';
import 'package:one_second_diary/shared/widgets/identity/flag_image.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// Special thanks: the bundled `CONTRIBUTORS.md`, a section label over a
/// card of names per section. "Code Contributions" reads as "Contributors"
/// and "Localization" as "Translators"; other sections keep the file's
/// heading.
///
/// A contributor with a GitHub handle opens their profile in the browser;
/// a translator shows the language's own name and flag.
class ThanksPage extends StatelessWidget {
  const ThanksPage({super.key});

  static const Key listKey = Key('thanksPage.list');

  static Key personKey(String name) =>
      ValueKey<String>('thanksPage.person.$name');

  @override
  Widget build(BuildContext context) {
    final ThanksState state = context.watch<ThanksCubit>().state;
    return DocumentScaffold(
      title: Strings.thanksTo,
      status: state.status,
      unavailableIcon: OsdIcons.favorite,
      // Below the page's snackbar host, where a link that can't open says so.
      child: state.status != DocumentStatus.ready
          ? null
          : LinkFailureListener(
              child: ListView.builder(
                key: listKey,
                padding: const EdgeInsets.only(bottom: OsdSpace.s24),
                itemCount: state.sections.length,
                itemBuilder: (BuildContext context, int index) =>
                    _CreditsSectionView(section: state.sections[index]),
              ),
            ),
    );
  }
}

class _CreditsSectionView extends StatelessWidget {
  const _CreditsSectionView({required this.section});

  final CreditsSection section;

  @override
  Widget build(BuildContext context) {
    final List<CreditsPerson> people = section.people;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel.soft(
          label: switch (section.kind) {
            CreditsKind.contributors => Strings.thanksContributors,
            CreditsKind.translators => Strings.thanksTranslators,
            CreditsKind.other => section.title,
          },
          sub: true,
          padding: const EdgeInsetsDirectional.fromSTEB(
            OsdSpace.textInset,
            OsdSpace.s22,
            OsdSpace.textInset,
            OsdSpace.s8,
          ),
        ),
        OsdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < people.length; i++) ...<Widget>[
                if (i > 0) const OsdDivider(),
                _PersonRow(person: people[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A name, with the language they translated, or a link to their GitHub
/// profile.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final CreditsPerson person;

  @override
  Widget build(BuildContext context) {
    final AppLanguage? language = person.language;
    final Uri? link = person.link;
    return OsdListRow(
      key: ThanksPage.personKey(person.name),
      title: person.name,
      value: language?.nativeName ?? person.note,
      valueLeading: language == null
          ? null
          : FlagImage(
              countryCode: language.flagCountryCode,
              fallbackLabel: language.code,
            ),
      trailing: link == null
          ? const OsdRowTrailing.none()
          : const OsdRowTrailing.external(),
      semanticsHint: link == null ? null : Strings.opensInBrowserHint,
      onTap: link == null
          ? null
          : () => unawaited(context.read<LinkCubit>().open(link)),
    );
  }
}
