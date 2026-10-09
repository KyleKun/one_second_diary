// The changelog and the credits are the repository's CHANGELOG.md and
// CONTRIBUTORS.md, bundled with the app (pubspec.yaml), read offline.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/data/bundled_documents.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(rootBundle.clear);

  test(
    'the changelog and the credits come from the files the app bundles',
    () async {
      final BundledDocuments documents = BundledDocuments(bundle: rootBundle);

      final List<ChangelogRelease> releases = await documents.changelog();
      final List<CreditsSection> credits = await documents.credits();

      expect(releases.first.version, isNotNull);
      expect(
        credits.map((CreditsSection s) => s.kind),
        containsAll(<CreditsKind>[
          CreditsKind.contributors,
          CreditsKind.translators,
        ]),
      );
    },
  );
}
