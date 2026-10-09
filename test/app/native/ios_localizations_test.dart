// The permission prompts iOS shows before the app runs come from
// InfoPlist.strings, which tool/ios/info_plist_strings.dart writes from the
// app's own translations.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';

import '../../../tool/ios/info_plist_strings.dart';

void main() {
  final String project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final List<String> languages = translatedLanguages();

  test('each InfoPlist.strings is what the translations give (rerun '
      'tool/ios/info_plist_strings.dart after a translation changes); a '
      "prompt a language has not translated is left to Info.plist's "
      'English', () {
    for (final String language in languages) {
      final File file = File(infoPlistStringsPath(language));
      final String? expected = infoPlistStrings(
        language,
        readTranslations(language),
      );

      expect(
        file.existsSync() ? file.readAsStringSync() : null,
        expected,
        reason: file.path,
      );
    }

    final String? strings = infoPlistStrings('xx', <String, Object?>{
      'cameraPermissionDesc': 'Kamera "bitte"',
      'galleryPermissionBody': '  ',
    });

    expect(
      strings,
      contains(r'"NSCameraUsageDescription" = "Kamera \"bitte\"";'),
    );
    expect(strings, isNot(contains('NSMicrophoneUsageDescription')));
    expect(strings, isNot(contains('NSPhotoLibraryUsageDescription')));
    expect(infoPlistStrings('xx', <String, Object?>{}), isNull);
  });

  test('the Runner target bundles every InfoPlist.strings, and '
      'CFBundleLocalizations lists exactly the app languages', () {
    for (final String language in languages) {
      if (!File(infoPlistStringsPath(language)).existsSync()) continue;
      expect(
        project,
        contains('path = $language.lproj/InfoPlist.strings;'),
        reason: language,
      );
      expect(
        RegExp(r'knownRegions = \(([^)]*)\)').firstMatch(project)!.group(1),
        contains('\t$language,'),
        reason: language,
      );
    }
    expect(project, contains('/* InfoPlist.strings in Resources */,'));

    final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    final String array = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist)!.group(1)!;
    final Set<String> listed = <String>{
      for (final RegExpMatch match in RegExp(
        '<string>([^<]+)</string>',
      ).allMatches(array))
        match.group(1)!,
    };

    expect(listed, <String>{fallbackLanguage, ...languages});
    expect(listed, <String>{
      for (final Locale locale in OsdLocalization.supportedLocales)
        locale.languageCode,
    });
  });
}
