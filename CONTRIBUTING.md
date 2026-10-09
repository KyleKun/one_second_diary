# Contributing

Suggestions and pull requests are welcome. For anything bigger than a small fix, open an issue first so we can agree on
the approach.

Before you write code, read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): where things live, how to add a screen, a
feature or a gateway, and the rules that keep older diaries working (ffmpeg arguments, preference keys, file names).

## Translations

The app's text lives in `assets/translations/`, one JSON file per language (`de.json`, `ru.json`, …). `en.json` is the
reference: it has every key.

**Translating**

- Translate the values and keep the keys as they are.
- Keep every `{placeholder}` exactly as written (`{count}`, `{name}`, `{version}`, …). The app fills them in. Keep
  `<b>` and `</b>` around the same words; the app shows them bold.
- You don't have to translate everything at once. A key your file doesn't have shows the English text, key by key, so
  a partly translated file is fine.
- New features add their text to `en.json` only. To see which keys each language still lacks, run
  `dart run tool/l10n/untranslated_report.dart` from the repository root. CI prints the same report and never fails
  on it.
- The English text of a key sometimes changes while a translation keeps the older wording. The key's meaning stays
  the same, so the older translation is still right; improve it if you like.

**Plurals**

A value that counts something is a JSON object of plural forms, for example:

```json
"clipCount": {
  "one": "{count} клип",
  "few": "{count} клипа",
  "many": "{count} клипов",
  "other": "{count} клипа"
}
```

Give every form your language needs, and show `{count}` in each one:

| Language | Forms |
|---|---|
| Belarusian (`be`), Russian (`ru`) | `one`, `few`, `many`, `other` |
| Czech (`cs`) | `one`, `few`, `other` |
| Chinese (`zh`), Indonesian (`id`) | `other` |
| Catalan, English, French, German, Hungarian, Portuguese, Spanish | `one`, `other` |

The forms follow the Unicode (CLDR) plural rules, not exact numbers: Russian `one` is also used for 21 and 31, and
French `one` for 0. So write each form for the whole group, never "one clip" spelled out as a word. A form you leave out
shows English or the wrong grammar, and the tests fail on it.

**iOS permission prompts**

iOS shows its own prompts before the app may use the camera, the microphone, the photo library or the location. Their
text is not in `assets/translations/`:
- The English text is in `ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
  `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription`, and any other `NS…UsageDescription` key
  there.
- Each translation is in `ios/Runner/<code>.lproj/InfoPlist.strings`, one line per key:

  ```
  "NSCameraUsageDescription" = "…";
  ```
- A key a language doesn't have there shows the English text from `Info.plist`.
- Keep the meaning exactly. The location text must say that the place name is looked up through the phone's location
  service; the privacy policy promises it.
- `CFBundleLocalizations` in `Info.plist` lists the languages the app ships, so iOS knows the app speaks them. A new
  language goes into that list too.

**Checking**

Run:

```sh
flutter test test/core/l10n test/theme/display_font_coverage_test.dart
```

It checks that every file is valid JSON, uses the same placeholders as `en.json`, has the plural forms above, and that
the titles can be drawn in the app's display font.

Add your name to `CONTRIBUTORS.md` in the same pull request.

### Adding a language

Open an issue first, so nobody else starts the same language. Then:

1. **The text.** Copy `en.json` to `assets/translations/<code>.json` (the two-letter ISO 639-1 code) and translate
   the values. The app loads files by language only: `pt.json`, never `pt-BR.json`.
2. **The language.** Add a value to `enum AppLanguage` (`lib/features/settings/domain/app_language.dart`) with its
   name in itself (`nativeName`) and the country code of the flag the language sheet shows (`flagCountryCode`).
   Keep the order the enum documents: Latin-script names alphabetically, then Cyrillic, then Han.
3. **Plurals.** Add the language's forms to `requiredPluralForms` (`test/core/l10n/plural_forms.dart`). The
   localisation tests check this table against easy_localization's rules.
4. **Fonts.** If the language uses letters the display font (Yusei Magic) lacks, the display-font test fails and
   names the key. For the date stamp burned into videos, add the code to the Noto Sans languages in
   `lib/core/media/policy/stamp_font_policy.dart`, as Russian, Belarusian and Czech are.
5. **iOS.** Add the code to `CFBundleLocalizations` in `ios/Runner/Info.plist`, and add
   `ios/Runner/<code>.lproj/InfoPlist.strings` with the permission prompts (see above). Add the new `.lproj` folder
   to the Runner target in Xcode (or in `ios/Runner.xcodeproj/project.pbxproj`) so it is copied into the app.
6. Run the checks below.

## Tests

The test suite is kept to **about 1 000 meaningful tests** (maintainer decision D17). The screens will keep changing,
so tests protect behaviour, not layout.

**Write a test for:**
- logic: cubits and blocs, rules, date maths (it must pass in any time zone);
- compatibility: preference keys and defaults, file names, folders, migrations, clips from older versions;
- ffmpeg: the argument goldens of every command (one table-driven test per command family);
- flows: a short robot journey over the real app when you add or change a user flow;
- a bug you fix: first a test that fails because of the bug, then the fix.

**Don't write a test that:**
- pins sizes, paddings, colours, fonts or the shape of the widget tree;
- renders the same page once per theme, text scale or screen size;
- only restates the code, or checks what the compiler already guarantees;
- counts calls on a collaborator. Use the fakes in `test/shared/fakes/` and `test/support/` and check the result.
  Mocking libraries (`mocktail`, `mockito`) are not used.

If your change breaks a test that only pinned a layout detail, delete that test and say so in the pull request.

## Before you open a pull request

Run, from the repository root:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/<the folders your change touches>
```

- `flutter test` without a path runs the whole suite, as CI does. It takes several minutes.
- If your change depends on the date or the time, also run its tests under other time zones, as CI does:

  ```sh
  TZ=Europe/Berlin flutter test test/<folder>
  TZ=America/New_York flutter test test/<folder>
  TZ=America/Santiago flutter test test/<folder>
  ```
- On macOS with the repository on an exFAT or FAT drive, macOS writes `._*` files next to your files, and the test
  runner crashes on `._*_test.dart`. Delete them first with `find lib test tool -name '._*' -type f -delete`, and
  never commit them.
- Don't change an ffmpeg argument, a preference key or a file name unless the pull request is about exactly that and
  explains why: people's diaries depend on them ([`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §9 and §10).
- If you use an AI coding agent: it must not run the app, an emulator or a simulator. It verifies its work with the
  commands above, and you check the result on your phone.
