// Only the composition files read the service locator. Widgets use
// context.read / watch / select, and services take every dependency through
// their constructor, so everything else stays testable with plain fakes.
//
// A file reads the locator when it imports get_it or the container
// (`core/di/injection_container.dart`, which holds `sl`).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files outside the features that may read the locator.
const Set<String> coreReaders = <String>{
  'lib/core/di/injection_container.dart',
  'lib/app/osd_app.dart',
  // Bootstrap: calls `registerDependencies`, never reads `sl`.
  'lib/app/launch/launch_app.dart',
};

/// Whether [path] may read the locator: [coreReaders], and each feature's
/// own composition files, `lib/features/<f>/<f>_injection.dart` (its
/// registrations) and `lib/features/<f>/<f>_routes.dart` (its route
/// builders, which provide its cubits).
bool mayReadServiceLocator(String path) {
  if (coreReaders.contains(path)) return true;
  final RegExpMatch? feature = RegExp(
    r'^lib/features/([a-z_]+)/([a-z_]+)_(injection|routes)\.dart$',
  ).firstMatch(path);
  return feature != null && feature.group(1) == feature.group(2);
}

bool readsServiceLocator(String source) => RegExp(
  r'''^\s*import\s+['"](package:get_it/|package:one_second_diary/core/di/injection_container\.dart)''',
  multiLine: true,
).hasMatch(source);

/// Whether [source] imports a feature's injection file: what it calls
/// there reads the locator on its behalf.
bool importsInjectionFile(String source) => RegExp(
  r'''^\s*import\s+['"]package:one_second_diary/features/[a-z_/]+_injection\.dart['"]''',
  multiLine: true,
).hasMatch(source);

/// The app's source files, AppleDouble files aside.
List<File> appSources() => <File>[
  for (final FileSystemEntity entity in Directory(
    'lib',
  ).listSync(recursive: true))
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.split('/').last.startsWith('._'))
      entity,
];

void main() {
  test('the checker sees an import of get_it, of the container or of an '
      "injection file, and allows a feature's own composition files "
      'only', () {
    expect(
      readsServiceLocator("import 'package:get_it/get_it.dart';\n"),
      isTrue,
    );
    expect(
      readsServiceLocator(
        "import 'package:one_second_diary/core/di/injection_container.dart';",
      ),
      isTrue,
    );
    expect(
      readsServiceLocator(
        "import 'package:one_second_diary/core/di/launch_core.dart';\n"
        '// sl<GoRouter>() in a comment',
      ),
      isFalse,
    );
    expect(
      importsInjectionFile(
        "import 'package:one_second_diary/features/profiles/"
        "profiles_injection.dart';",
      ),
      isTrue,
    );
    expect(
      importsInjectionFile(
        "import 'package:one_second_diary/features/profiles/presentation/"
        "cubit/profile_form_cubit.dart';\n"
        '// profiles_injection.dart in a comment',
      ),
      isFalse,
    );

    expect(
      <String, bool>{
        for (final String path in <String>[
          'lib/features/today/today_injection.dart',
          'lib/features/clip_editor/clip_editor_routes.dart',
          'lib/features/today/diary_routes.dart',
          'lib/features/today/presentation/today_injection.dart',
          'lib/features/today/presentation/pages/today_page.dart',
          'lib/core/router/app_shell.dart',
        ])
          path: mayReadServiceLocator(path),
      },
      <String, bool>{
        'lib/features/today/today_injection.dart': true,
        'lib/features/clip_editor/clip_editor_routes.dart': true,
        'lib/features/today/diary_routes.dart': false,
        'lib/features/today/presentation/today_injection.dart': false,
        'lib/features/today/presentation/pages/today_page.dart': false,
        'lib/core/router/app_shell.dart': false,
      },
    );
  });

  // An injection file may expose helpers that read the locator; a widget
  // or a service calling one reads it too.
  test('only the composition files read the service locator or import an '
      'injection file', () {
    final List<(String, String)> sources = <(String, String)>[
      for (final File file in appSources())
        (file.path, file.readAsStringSync()),
    ];
    final List<String> readers = <String>[
      for (final (String path, String source) in sources)
        if (readsServiceLocator(source)) path,
    ];
    final List<String> importers = <String>[
      for (final (String path, String source) in sources)
        if (importsInjectionFile(source)) path,
    ];

    expect(readers, isNotEmpty, reason: 'the checker found no reader at all');
    expect(
      importers,
      contains('lib/core/di/injection_container.dart'),
      reason: 'the checker found no importer at all',
    );
    expect(
      <String>{
        ...readers,
        ...importers,
      }.where((String path) => !mayReadServiceLocator(path)),
      isEmpty,
      reason:
          'Read dependencies with context.read / watch / select in widgets '
          'and through constructors in services; only the DI and route '
          'files compose them.',
    );
  });
}
