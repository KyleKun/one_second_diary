import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// What a [CreditsSection] thanks people for.
enum CreditsKind {
  /// "Code Contributions": the page titles it `thanksContributors`.
  contributors,

  /// "Localization": the page titles it `thanksTranslators`, and each
  /// person's language shows as its endonym and flag.
  translators,

  /// Any other section: its heading shows as written in the file.
  other,
}

/// Someone the app thanks.
final class CreditsPerson extends Equatable {
  const CreditsPerson({
    required this.name,
    this.handle,
    this.language,
    this.note,
  });

  final String name;

  /// Their GitHub handle, without the `@`.
  final String? handle;

  /// The language they translated, when the app ships it.
  final AppLanguage? language;

  /// What the file says after the name when it is no language the app
  /// ships ("Klingon").
  final String? note;

  /// Their GitHub profile, when the file gives a handle.
  Uri? get link {
    final String? handle = this.handle;
    return handle == null ? null : Uri.https('github.com', '/$handle');
  }

  @override
  List<Object?> get props => <Object?>[name, handle, language, note];
}

/// One `## ` section of the credits.
final class CreditsSection extends Equatable {
  const CreditsSection({
    required this.title,
    required this.kind,
    required this.people,
  });

  /// The heading as written ("Testing & Feedback").
  final String title;

  final CreditsKind kind;

  final List<CreditsPerson> people;

  @override
  List<Object?> get props => <Object?>[title, kind, people];
}

/// The app's `CONTRIBUTORS.md`, which the Special thanks page shows:
/// `## ` headings over `- ` bullets, a person per bullet, as
/// `Name (@handle)` or `Name - Language` (the language in English).
abstract final class Credits {
  static final RegExp _handle = RegExp(r'^(.*?)\s*\(@([\w-]+)\)$');

  static const Map<String, CreditsKind> _kinds = <String, CreditsKind>{
    'code contributions': CreditsKind.contributors,
    'localization': CreditsKind.translators,
  };

  /// The English names CONTRIBUTORS.md gives the languages.
  static const Map<String, AppLanguage> _languages = <String, AppLanguage>{
    'belarusian': AppLanguage.be,
    'catalan': AppLanguage.ca,
    'chinese': AppLanguage.zh,
    'czech': AppLanguage.cs,
    'english': AppLanguage.en,
    'french': AppLanguage.fr,
    'german': AppLanguage.de,
    'hungarian': AppLanguage.hu,
    'indonesian': AppLanguage.id,
    'portuguese': AppLanguage.pt,
    'russian': AppLanguage.ru,
    'spanish': AppLanguage.es,
  };

  /// The sections of [markdown], in file order.
  static List<CreditsSection> parse(String markdown) {
    final List<CreditsSection> sections = <CreditsSection>[];
    String? title;
    List<CreditsPerson> people = <CreditsPerson>[];

    void close() {
      final String? heading = title;
      if (heading == null) return;
      sections.add(
        CreditsSection(
          title: heading,
          kind: _kinds[heading.toLowerCase()] ?? CreditsKind.other,
          people: List<CreditsPerson>.unmodifiable(people),
        ),
      );
    }

    for (final String raw in markdown.split('\n')) {
      final String line = raw.trim();
      if (line.startsWith('## ')) {
        close();
        title = line.substring(3).trim();
        people = <CreditsPerson>[];
      } else if (title != null && line.startsWith('- ')) {
        people.add(_person(line.substring(2).trim()));
      }
    }
    close();
    return sections;
  }

  static CreditsPerson _person(String text) {
    final RegExpMatch? handle = _handle.firstMatch(text);
    if (handle != null) {
      return CreditsPerson(name: handle.group(1)!, handle: handle.group(2));
    }
    final int dash = text.lastIndexOf(' - ');
    if (dash < 0) return CreditsPerson(name: text);
    final String name = text.substring(0, dash).trim();
    final String rest = text.substring(dash + 3).trim();
    final AppLanguage? language = _languages[rest.toLowerCase()];
    return language == null
        ? CreditsPerson(name: name, note: rest)
        : CreditsPerson(name: name, language: language);
  }
}
