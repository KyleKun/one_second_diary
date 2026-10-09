import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';

/// One `static String` member of the `Strings` class, as source text.
class _Member {
  const _Member(this.source);

  final String source;

  /// Every translation key the member reads: `'key'.tr(`, `'key'.plural(` or
  /// the `_plural('key', ...)` helper.
  List<({String key, bool plural})> get lookups => [
    for (final RegExpMatch match in _lookup.allMatches(source))
      if (match.group(1) != null)
        (key: match.group(1)!, plural: match.group(2) == 'plural')
      else
        (key: match.group(3)!, plural: true),
  ];

  /// The `{placeholder}` names the member fills: its `namedArgs` keys, the
  /// plural `name:`, and `count`, which the `_plural` helper always fills.
  Set<String> get filledPlaceholders => {
    for (final RegExpMatch args in _namedArgs.allMatches(source))
      for (final RegExpMatch name in _mapKey.allMatches(args.group(1)!))
        name.group(1)!,
    for (final RegExpMatch name in _pluralName.allMatches(source))
      name.group(1)!,
    if (source.contains('_plural(')) 'count',
  };
}

final RegExp _namedArgs = RegExp(r'namedArgs:\s*\{([^}]*)\}');
final RegExp _mapKey = RegExp(r"'(\w+)'\s*:");
final RegExp _pluralName = RegExp(r"\bname:\s*'(\w+)'");
final RegExp _placeholder = RegExp(r'\{(\w*)\}');

/// The `{name}` placeholders of an en.json value (every form of a plural).
Set<String> _placeholdersOf(Object? value) => switch (value) {
  final String text => {
    for (final RegExpMatch match in _placeholder.allMatches(text))
      match.group(1)!,
  },
  final Map<String, dynamic> forms => {
    for (final Object? form in forms.values) ..._placeholdersOf(form),
  },
  _ => const {},
};

final RegExp _lookup = RegExp(r"'(\w+)'\s*\.(tr|plural)\(|_plural\(\s*'(\w+)'");
final RegExp _memberStart = RegExp(r'^\s*static String\b', multiLine: true);
final RegExp _comment = RegExp(r'^\s*//.*$', multiLine: true);

/// The members of `Strings` in lib/core/l10n/strings.dart, comments removed.
List<_Member> _readMembers() {
  final String source = File(
    'lib/core/l10n/strings.dart',
  ).readAsStringSync().replaceAll(_comment, '');
  final int classStart = source.indexOf('abstract final class Strings {');
  final String body = source.substring(
    classStart,
    source.indexOf('\n}\n', classStart),
  );
  final List<int> starts = [
    for (final RegExpMatch match in _memberStart.allMatches(body)) match.start,
  ];
  return [
    for (int index = 0; index < starts.length; index++)
      _Member(
        body.substring(
          starts[index],
          index + 1 < starts.length ? starts[index + 1] : body.length,
        ),
      ),
  ];
}

void main() {
  final List<_Member> members = _readMembers();
  final List<String> usedKeys = [
    for (final _Member member in members)
      for (final lookup in member.lookups) lookup.key,
  ];
  final Map<String, dynamic> english =
      jsonDecode(File('${OsdLocalization.path}/en.json').readAsStringSync())
          as Map<String, dynamic>;

  // A key missing from en.json shows raw on screen; plural() on a plain
  // string throws, and tr() on a plural map shows the raw key.
  test('every Strings member reads exactly one en.json key, every key has '
      'one member, and plural keys are read with plural, plain keys with '
      'tr', () {
    expect(usedKeys.toSet().difference(english.keys.toSet()), isEmpty);
    expect(usedKeys.toSet(), english.keys.toSet());
    expect(usedKeys, hasLength(usedKeys.toSet().length));
    for (final _Member member in members) {
      expect(member.lookups, hasLength(1), reason: member.source);
      for (final lookup in member.lookups) {
        expect(
          lookup.plural,
          english[lookup.key] is Map,
          reason: '${lookup.key}: ${member.source}',
        );
      }
    }
  });

  // A placeholder left unfilled shows as "{name}" on screen; an argument the
  // text doesn't use is usually a misspelt placeholder.
  test('every member fills exactly the {placeholders} of its English text', () {
    for (final _Member member in members) {
      for (final lookup in member.lookups) {
        expect(
          member.filledPlaceholders,
          _placeholdersOf(english[lookup.key]),
          reason: lookup.key,
        );
      }
    }
  });
}
