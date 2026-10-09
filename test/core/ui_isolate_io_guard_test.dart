// Guards the "no *Sync file IO on the UI isolate" rule: listing folders or
// reading files synchronously on the UI isolate costs frames.
//
// A `.xSync(` call in app code is allowed only where it can run on a
// background isolate:
// - inside the argument list of an `Isolate.run(...)` call, or
// - inside the body of a function named in [isolateOnly] for its file, which
//   in turn is called only inside `Isolate.run(...)` in that file.
//
// Comments and string contents are ignored, and so are the `*Sync` methods
// in [notFileIo]. Tests may use sync IO.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Functions that run only through `Isolate.run`, by file. Keep it short:
/// prefer the sync calls inside the `Isolate.run` closure itself.
const Map<String, Set<String>> isolateOnly = <String, Set<String>>{
  'lib/features/clips/data/clip_scanner.dart': <String>{'_scanSync'},
};

/// `*Sync` methods that are not file IO: `toImageSync` is a GPU snapshot of
/// a layer (the theme reveal), and must run on the UI isolate.
const Set<String> notFileIo = <String>{'toImageSync'};

void main() {
  test('the checker finds a sync call on the UI isolate, allows those inside '
      'Isolate.run or in an isolate-only function only called there, and '
      'ignores comments, strings and sync calls that are not file IO', () {
    const String onUiIsolate = '''
Future<String> read(String path) async {
  return File(path).readAsStringSync();
}
''';
    const String inIsolates = r'''
// File(path).readAsStringSync() in a comment.
/// Doc: `listSync()`.
const String text = 'File(p).existsSync()';
Future<String> read(String path) => Isolate.run(
  () => File(path).readAsStringSync(),
  debugName: 'read',
);
Future<void> write(String path) => Isolate.run<void>(() {
  File('$path.tmp')..writeAsStringSync('x')..renameSync(path);
});
ui.Image snapshot(OffsetLayer layer) => layer.toImageSync(Offset.zero & size);
''';
    const String isolateOnlyInIsolate = '''
Future<int> count(String root) => Isolate.run(() => _countSync(root));
int _countSync(String root) => Directory(root).listSync().length;
''';
    const String isolateOnlyOnUiIsolate = '''
Future<int> count(String root) async => _countSync(root);
int _countSync(String root) {
  return Directory(root).listSync().length;
}
''';

    expect(syncCallsOutsideIsolates(onUiIsolate), <String>['readAsStringSync']);
    expect(syncCallsOutsideIsolates(inIsolates), isEmpty);
    expect(
      syncCallsOutsideIsolates(
        isolateOnlyInIsolate,
        isolateOnly: <String>{'_countSync'},
      ),
      isEmpty,
    );
    expect(
      syncCallsOutsideIsolates(
        isolateOnlyOnUiIsolate,
        isolateOnly: <String>{'_countSync'},
      ),
      <String>['_countSync called outside Isolate.run'],
    );
  });

  test('the app does sync file IO only on background isolates, and every '
      'isolate-only function still exists', () {
    final List<String> offenders = <String>[
      for (final (String path, String source) in dartFiles('lib'))
        for (final String call in syncCallsOutsideIsolates(
          source,
          isolateOnly: isolateOnly[path] ?? const <String>{},
        ))
          '$path: $call',
    ];
    expect(offenders, isEmpty);

    for (final MapEntry<String, Set<String>> entry in isolateOnly.entries) {
      final String source = File(entry.key).readAsStringSync();
      for (final String function in entry.value) {
        expect(source, contains('$function('), reason: entry.key);
      }
    }
  });
}

/// Every Dart file under [folder], as (path relative to the repo, source).
Iterable<(String, String)> dartFiles(String folder) sync* {
  final Directory directory = Directory(folder);
  if (!directory.existsSync()) return;
  for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
    final String name = entity.uri.pathSegments.last;
    if (entity is File && name.endsWith('.dart') && !name.startsWith('._')) {
      yield (entity.path, entity.readAsStringSync());
    }
  }
}

/// The `.xSync(` calls of [source] that may run on the UI isolate, by
/// method name, plus one entry per call to an [isolateOnly] function made
/// outside `Isolate.run`.
List<String> syncCallsOutsideIsolates(
  String source, {
  Set<String> isolateOnly = const <String>{},
}) {
  final String code = codeOnly(source);
  final List<(int, int)> isolates = <(int, int)>[
    for (final RegExpMatch match in RegExp(
      r'\bIsolate\.run\b(<[^>]*>)?\s*\(',
    ).allMatches(code))
      (match.end - 1, closingOf(code, match.end - 1)),
  ];
  final List<(int, int)> allowed = <(int, int)>[...isolates];
  final List<String> found = <String>[];
  bool inside(List<(int, int)> ranges, int offset) =>
      ranges.any(((int, int) range) => offset > range.$1 && offset < range.$2);
  for (final String function in isolateOnly) {
    for (final RegExpMatch match in RegExp(
      '\\b${RegExp.escape(function)}\\s*\\(',
    ).allMatches(code)) {
      final int close = closingOf(code, match.end - 1);
      final (int, int)? body = bodyAfter(code, close + 1);
      if (body != null) {
        allowed.add(body);
      } else if (!inside(isolates, match.start)) {
        found.add('$function called outside Isolate.run');
      }
    }
  }
  for (final RegExpMatch match in RegExp(
    r'\.([a-z]\w*Sync)\s*\(',
  ).allMatches(code)) {
    if (!inside(allowed, match.start) && !notFileIo.contains(match.group(1))) {
      found.add(match.group(1)!);
    }
  }
  return found;
}

/// The index of the bracket closing the one at [open] in [code].
int closingOf(String code, int open) {
  const String opening = '([{';
  const String closing = ')]}';
  int depth = 0;
  for (int i = open; i < code.length; i++) {
    if (opening.contains(code[i])) depth++;
    if (closing.contains(code[i]) && --depth == 0) return i;
  }
  return code.length;
}

/// The body of a function whose parameter list ends right before [from]:
/// a `{ ... }` block or an `=> ...;` expression. Null for a call.
(int, int)? bodyAfter(String code, int from) {
  int i = from;
  while (i < code.length && code[i].trim().isEmpty) {
    i++;
  }
  for (final String modifier in <String>['async*', 'async', 'sync*']) {
    if (code.startsWith(modifier, i)) {
      i += modifier.length;
      while (i < code.length && code[i].trim().isEmpty) {
        i++;
      }
      break;
    }
  }
  if (i < code.length && code[i] == '{') return (i, closingOf(code, i));
  if (code.startsWith('=>', i)) {
    int depth = 0;
    for (int j = i + 2; j < code.length; j++) {
      if ('([{'.contains(code[j])) depth++;
      if (')]}'.contains(code[j])) depth--;
      if (code[j] == ';' && depth == 0) return (i, j);
    }
  }
  return null;
}

/// [source] with comments and string contents blanked (offsets and line
/// breaks kept), so only code is searched.
String codeOnly(String source) {
  final StringBuffer out = StringBuffer();
  String blank(String text) => text.replaceAll(RegExp(r'[^\n]'), ' ');
  bool identifierAt(int i) =>
      i >= 0 && RegExp(r'[A-Za-z0-9_$]').hasMatch(source[i]);
  int i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final int end = source.indexOf('\n', i);
      final int stop = end == -1 ? source.length : end;
      out.write(blank(source.substring(i, stop)));
      i = stop;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final int end = source.indexOf('*/', i + 2);
      final int stop = end == -1 ? source.length : end + 2;
      out.write(blank(source.substring(i, stop)));
      i = stop;
      continue;
    }
    final bool raw =
        source[i] == 'r' &&
        i + 1 < source.length &&
        (source[i + 1] == "'" || source[i + 1] == '"') &&
        !identifierAt(i - 1);
    final int q = raw ? i + 1 : i;
    if (source[q] == "'" || source[q] == '"') {
      final String quote =
          source.startsWith("'''", q) || source.startsWith('"""', q)
          ? source.substring(q, q + 3)
          : source[q];
      int j = q + quote.length;
      while (j < source.length && !source.startsWith(quote, j)) {
        if (!raw && source[j] == r'\') j++;
        j++;
      }
      final int stop = min(j + quote.length, source.length);
      out
        ..write(source.substring(i, q + quote.length))
        ..write(blank(source.substring(q + quote.length, min(j, stop))))
        ..write(source.substring(min(j, stop), stop));
      i = stop;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}
