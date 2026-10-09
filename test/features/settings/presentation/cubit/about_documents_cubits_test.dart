// The Changelog and Special thanks pages: the bundled CHANGELOG.md and
// CONTRIBUTORS.md, read when the page opens.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/data/bundled_documents.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/changelog_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/thanks_cubit.dart';

import '../../../../support/support.dart';
import '../../data/memory_asset_bundle.dart';

void main() {
  test('each document loads when its page opens; one that cannot be read '
      'fails, and the log says why', () async {
    final MemoryLogSink log = MemoryLogSink();
    final BundledDocuments readable = BundledDocuments(
      bundle: MemoryAssetBundle(<String, String>{
        BundledDocuments.changelogAsset: '## v2.0.0 - 10/2026\n- v3',
        BundledDocuments.creditsAsset: '## Code Contributions\n- Ada (@ada)',
      }),
    );
    final BundledDocuments missing = BundledDocuments(
      bundle: MemoryAssetBundle(const <String, String>{}),
    );

    final ChangelogCubit changelog = ChangelogCubit(
      documents: readable,
      logger: memoryLogger(log),
    );
    final ThanksCubit thanks = ThanksCubit(
      documents: readable,
      logger: memoryLogger(log),
    );
    addTearDown(changelog.close);
    addTearDown(thanks.close);
    expect(changelog.state.status, DocumentStatus.loading);
    expect(thanks.state.status, DocumentStatus.loading);

    await changelog.load();
    await thanks.load();

    expect(changelog.state.status, DocumentStatus.ready);
    expect(changelog.state.releases.single.version, '2.0.0');
    expect(thanks.state.status, DocumentStatus.ready);
    expect(
      thanks.state.sections.single.people.single,
      const CreditsPerson(name: 'Ada', handle: 'ada'),
    );
    expect(log.lines, isEmpty);

    final ChangelogCubit noChangelog = ChangelogCubit(
      documents: missing,
      logger: memoryLogger(log),
    );
    final ThanksCubit noThanks = ThanksCubit(
      documents: missing,
      logger: memoryLogger(log),
    );
    addTearDown(noChangelog.close);
    addTearDown(noThanks.close);

    await noChangelog.load();
    await noThanks.load();

    expect(noChangelog.state.status, DocumentStatus.failed);
    expect(noThanks.state.status, DocumentStatus.failed);
    expect(log.lines, <Matcher>[
      contains('[SETTINGS] Could not read CHANGELOG.md'),
      contains('[SETTINGS] Could not read CONTRIBUTORS.md'),
    ]);
  });
}
