// "Changelog": the bundled CHANGELOG.md, whose `## v<version> - MM/YYYY`
// headings are a contract with release.yml.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';

void main() {
  test('each "## v<version> - MM/YYYY" heading starts a release with its '
      'bullet items; indented bullets belong to the item above; text before '
      'the first heading, blank lines and CRLF are ignored; a heading '
      'without a version or a real month keeps its text as the title', () {
    final List<ChangelogRelease> releases = Changelog.parse(
      '# Changelog\r\n\r\n'
      '## Unreleased\r\n'
      '- Something new\r\n'
      '## v1.7.1 - 09/2026\r\n'
      '- Fixed "Permission denied" error\r\n'
      'Minor layout improvements\r\n'
      '\r\n'
      '## v1.5 - 13/2023\n'
      '- New features:\n'
      '    - Upload from gallery\n'
      '\t- Profiles\n',
    );

    expect(releases, <ChangelogRelease>[
      const ChangelogRelease(
        title: 'Unreleased',
        version: null,
        month: null,
        items: <ChangelogItem>[ChangelogItem('Something new')],
      ),
      ChangelogRelease(
        title: 'v1.7.1 - 09/2026',
        version: '1.7.1',
        month: DateTime(2026, 9),
        items: const <ChangelogItem>[
          ChangelogItem('Fixed "Permission denied" error'),
          ChangelogItem('Minor layout improvements'),
        ],
      ),
      const ChangelogRelease(
        title: 'v1.5 - 13/2023',
        version: '1.5',
        month: null,
        items: <ChangelogItem>[
          ChangelogItem('New features:', <String>[
            'Upload from gallery',
            'Profiles',
          ]),
        ],
      ),
    ]);
  });

  test("the repository's CHANGELOG.md reads as releases with a version and a "
      'month each, newest first', () {
    final List<ChangelogRelease> releases = Changelog.parse(
      File('CHANGELOG.md').readAsStringSync(),
    );

    expect(releases, isNotEmpty);
    for (final ChangelogRelease release in releases) {
      expect(release.version, isNotNull, reason: release.title);
      expect(release.month, isNotNull, reason: release.title);
      expect(release.items, isNotEmpty, reason: release.title);
    }
    final List<DateTime> months = <DateTime>[
      for (final ChangelogRelease release in releases) release.month!,
    ];
    expect(
      months,
      <DateTime>[...months]..sort((DateTime a, DateTime b) => b.compareTo(a)),
    );
  });
}
