import 'package:equatable/equatable.dart';

/// One change in a [ChangelogRelease]: a `- ` bullet, with the indented
/// bullets under it as [details] ("New features:" and its list).
final class ChangelogItem extends Equatable {
  const ChangelogItem(this.text, [this.details = const <String>[]]);

  final String text;

  final List<String> details;

  @override
  List<Object?> get props => <Object?>[text, details];
}

/// One `## ` section of the changelog.
final class ChangelogRelease extends Equatable {
  const ChangelogRelease({
    required this.title,
    required this.version,
    required this.month,
    required this.items,
  });

  /// The heading as written, after `## ` (`v<version> - MM/YYYY`).
  final String title;

  /// The version the heading names ("1.7.1"), or null when it names none.
  final String? version;

  /// The first day of the release month, or null when the heading has none.
  final DateTime? month;

  final List<ChangelogItem> items;

  @override
  List<Object?> get props => <Object?>[title, version, month, items];
}

/// The app's `CHANGELOG.md`, which the Changelog page shows.
///
/// Its headings are a contract with `release.yml`: `## v<version> - MM/YYYY`,
/// newest first. Items are `- ` bullets; bullets indented under an item are
/// its details.
abstract final class Changelog {
  static final RegExp _heading = RegExp(
    r'^v?(\d[\w.+-]*)(?:\s+-\s+(\d{1,2})/(\d{4}))?$',
  );

  /// The releases in [markdown], in file order. Text before the first
  /// heading is not part of any release.
  static List<ChangelogRelease> parse(String markdown) {
    final List<ChangelogRelease> releases = <ChangelogRelease>[];
    String? title;
    List<_OpenItem> items = <_OpenItem>[];

    void close() {
      final String? heading = title;
      if (heading == null) return;
      final RegExpMatch? match = _heading.firstMatch(heading);
      releases.add(
        ChangelogRelease(
          title: heading,
          version: match?.group(1),
          month: _month(match?.group(2), match?.group(3)),
          items: <ChangelogItem>[for (final _OpenItem item in items) item.done],
        ),
      );
    }

    for (final String raw in markdown.split('\n')) {
      final String line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (line.startsWith('## ')) {
        close();
        title = line.substring(3).trim();
        items = <_OpenItem>[];
        continue;
      }
      if (title == null) continue;
      final bool indented = line.startsWith(' ') || line.startsWith('\t');
      final String text = _bulletText(line.trim());
      if (indented && items.isNotEmpty) {
        items.last.details.add(text);
      } else {
        items.add(_OpenItem(text));
      }
    }
    close();
    return releases;
  }

  static String _bulletText(String line) =>
      line.startsWith('- ') || line.startsWith('* ')
      ? line.substring(2).trim()
      : line;

  static DateTime? _month(String? month, String? year) {
    if (month == null || year == null) return null;
    final int m = int.parse(month);
    if (m < 1 || m > 12) return null;
    return DateTime(int.parse(year), m);
  }
}

/// An item while its details are still being read.
final class _OpenItem {
  _OpenItem(this.text);

  final String text;
  final List<String> details = <String>[];

  ChangelogItem get done =>
      ChangelogItem(text, List<String>.unmodifiable(details));
}
