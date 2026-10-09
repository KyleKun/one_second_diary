import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/app_shell.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';
import 'package:one_second_diary/features/settings/presentation/dialogs/contact_dialog.dart';
import 'package:one_second_diary/features/settings/presentation/pages/about_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/app_preferences_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/changelog_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/places_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/support_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/tags_page.dart';
import 'package:one_second_diary/features/settings/presentation/pages/thanks_page.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/edit_tag_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/language_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/your_name_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/about_hero.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_bottom_nav.dart';
import 'package:one_second_diary/shared/widgets/controls/language_row.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/identity/flag_image.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The Settings tab, the language sheet and the name sheet, as the user
/// drives them.
class SettingsRobot {
  SettingsRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  BuildContext get _app => tester.element(find.byType(Navigator).first);

  Finder get _page => find.byKey(const ValueKey<AppRoute>(AppRoute.settings));

  /// Shows the Settings tab (its nav item), unless it shows already.
  Future<void> open() async {
    if (_page.hitTestable().evaluate().isNotEmpty) return;
    final Finder item = _navItem;
    expect(
      item.hitTestable(),
      findsOneWidget,
      reason: 'the Settings tab is reachable (no page covers the nav)',
    );
    await tester.tap(item);
    await settle(tester);
  }

  Finder get _navItem => find.byKey(
    OsdBottomNav.itemKey(AppShell.tabs.indexOf(AppRoute.settings)),
  );

  /// The row [row] (a `SettingsTabPage` key) exists.
  void expectRow(Key row, {bool shown = true}) =>
      expect(find.byKey(row), shown ? findsOneWidget : findsNothing);

  /// The value [row] shows ("English", "20:00", "Off"), or null.
  String? valueOf(Key row) => _rowOf(row).value;

  /// The colour [row]'s value is drawn in.
  Color? valueColorOf(Key row) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(row),
          matching: find.byKey(OsdListRow.valueKey),
        ),
      )
      .style
      ?.color;

  /// Taps [row] on the tab and waits for what it opens. A row the list has
  /// scrolled past is brought back into view; one it hasn't built yet is
  /// scrolled to.
  Future<void> tapRow(Key row) async {
    await open();
    final Finder target = find.byKey(row);
    if (target.evaluate().isEmpty) {
      // Tapping the Settings tab again takes the list back to its top.
      await tester.tap(_navItem);
      await settle(tester);
      await tester.scrollUntilVisible(
        target,
        100,
        scrollable: find.descendant(
          of: find.byKey(SettingsTabPage.listKey),
          matching: find.byType(Scrollable),
        ),
      );
    }
    await tester.ensureVisible(target);
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
  }

  /// The theme switch: taps the Dark mode row (on the Settings tab) when
  /// the theme is not [darkMode] yet.
  Future<void> setDarkMode(bool darkMode) async {
    await open();
    if (darkModeSwitchOn == darkMode) return;
    await tapRow(SettingsTabPage.darkModeRowKey);
  }

  /// Whether the Dark mode switch is drawn on.
  bool get darkModeSwitchOn => tester
      .widget<OsdSwitch>(
        find.descendant(
          of: find.byKey(SettingsTabPage.darkModeRowKey),
          matching: find.byType(OsdSwitch),
        ),
      )
      .value;

  OsdListRow _rowOf(Key row) => tester.widget<OsdListRow>(
    find.descendant(of: find.byKey(row), matching: find.byType(OsdListRow)),
  );

  /// Opens Profiles from its row; `app.profiles` drives it.
  Future<void> openProfiles() async {
    await tapRow(SettingsTabPage.profilesRowKey);
    expect(
      find.byKey(const ValueKey<AppRoute>(AppRoute.profiles)),
      findsOneWidget,
      reason: 'S4 shows',
    );
  }

  Finder get _tags => find.byKey(const ValueKey<AppRoute>(AppRoute.tags));

  /// Opens Settings › Tags from its row.
  Future<void> openTags() async {
    await tapRow(SettingsTabPage.tagsRowKey);
    expect(_tags, findsOneWidget, reason: 'Tags shows');
  }

  /// Tags lists [name] with "[count] videos".
  void expectTag(String name, {required int count}) {
    final Finder row = find.byKey(TagsPage.rowKey(name));
    expect(row, findsOneWidget, reason: '"$name" is listed');
    final OsdListRow listRow = tester.widget<OsdListRow>(
      find.descendant(of: row, matching: find.byType(OsdListRow)),
    );
    expect(listRow.title, name);
    expect(listRow.value, startsWith('$count '));
  }

  /// Taps [name]'s row, which opens its Edit tag sheet.
  Future<void> openTag(String name) async {
    final Finder row = find.byKey(TagsPage.rowKey(name));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await settle(tester);
    expect(find.byKey(EditTagSheet.bodyKey), findsOneWidget);
  }

  Finder get _places => find.byKey(const ValueKey<AppRoute>(AppRoute.places));

  /// Opens Settings › Places from its row.
  Future<void> openPlaces() async {
    await tapRow(SettingsTabPage.placesRowKey);
    expect(_places, findsOneWidget, reason: 'Places shows');
  }

  /// Places lists [name].
  void expectPlace(String name) {
    final Finder row = find.byKey(PlacesPage.rowKey(name));
    expect(row, findsOneWidget, reason: '"$name" is listed');
    final OsdListRow listRow = tester.widget<OsdListRow>(
      find.descendant(of: row, matching: find.byType(OsdListRow)),
    );
    expect(listRow.title, name);
  }

  Finder get _preferences =>
      find.byKey(const ValueKey<AppRoute>(AppRoute.preferences));

  Future<void> openPreferences() async {
    await tapRow(SettingsTabPage.preferencesRowKey);
    expect(_preferences, findsOneWidget, reason: 'S3 shows');
  }

  /// Whether [preference]'s switch is drawn on.
  bool preferenceOn(AppPreference preference) => tester
      .widget<OsdSwitch>(
        find.descendant(
          of: find.byKey(AppPreferencesPage.rowKey(preference)),
          matching: find.byType(OsdSwitch),
        ),
      )
      .value;

  /// Taps [preference]'s row (scrolling to it first) and waits for the
  /// switch.
  Future<void> togglePreference(AppPreference preference) async {
    final Finder row = find.byKey(AppPreferencesPage.rowKey(preference));
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find.descendant(
        of: _preferences,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(row);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);
  }

  /// Opens the language sheet: from the Language row when the tab shows,
  /// otherwise as that row does, over the page on top (a language change
  /// then shows on the pushed page as it is).
  Future<void> openLanguageSheet() async {
    final Finder row = find.byKey(SettingsTabPage.languageRowKey);
    if (row.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(row);
    } else {
      LanguageSheet.show(
        tester.element(
          find.byKey(
            const ValueKey<AppRoute>(AppRoute.settings),
            skipOffstage: false,
          ),
        ),
      ).ignore();
    }
    await settle(tester);
    expectLanguageSheetOpen();
  }

  void expectLanguageSheetOpen({bool open = true}) => expect(
    find.byKey(LanguageSheet.listKey),
    open ? findsOneWidget : findsNothing,
  );

  /// The sheet's rows, top to bottom, as "endonym flag" ("Català AD").
  List<String> get languageRows => <String>[
    for (final AppLanguage language in AppLanguage.values)
      if (find.byKey(LanguageSheet.rowKey(language)).evaluate().isNotEmpty)
        '${_languageRow(language).endonym} '
            '${_languageRow(language).countryCode}',
  ];

  /// The language the sheet shows checked.
  AppLanguage get checkedLanguage => AppLanguage.values.singleWhere(
    (AppLanguage language) =>
        find.byKey(LanguageSheet.rowKey(language)).evaluate().isNotEmpty &&
        _languageRow(language).selected,
  );

  LanguageRow _languageRow(AppLanguage language) =>
      tester.widget<LanguageRow>(find.byKey(LanguageSheet.rowKey(language)));

  /// The flag drawn in [language]'s row.
  String flagOf(AppLanguage language) => tester
      .widget<FlagImage>(
        find.descendant(
          of: find.byKey(LanguageSheet.rowKey(language)),
          matching: find.byType(FlagImage),
        ),
      )
      .countryCode;

  /// Picks [language] in the sheet (opening it first), and waits until the
  /// sheet has closed and the pages show the language.
  Future<void> pickLanguage(AppLanguage language) async {
    if (find.byKey(LanguageSheet.listKey).evaluate().isEmpty) {
      await openLanguageSheet();
    }
    final Finder row = find.byKey(LanguageSheet.rowKey(language));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await harness.settleUntil(
      () =>
          Localizations.localeOf(_app) == OsdLocalization.localeOf(language) &&
          find.byKey(LanguageSheet.listKey).evaluate().isEmpty,
      reason: 'the app shows ${language.code} and the sheet has closed',
    );
  }

  Future<void> openAbout() async {
    await tapRow(SettingsTabPage.aboutRowKey);
    expect(
      find.byKey(const ValueKey<AppRoute>(AppRoute.about)),
      findsOneWidget,
      reason: 'S8 shows',
    );
  }

  /// Opens About's page [route] (the changelog, special thanks, the
  /// licences) from its row, opening About first when it isn't shown.
  Future<void> openAboutPage(AppRoute route) async {
    if (find
        .byKey(const ValueKey<AppRoute>(AppRoute.about))
        .hitTestable()
        .evaluate()
        .isEmpty) {
      await openAbout();
    }
    await tester.tap(
      find.byKey(switch (route) {
        AppRoute.changelog => AboutPage.changelogRowKey,
        AppRoute.thanks => AboutPage.thanksRowKey,
        AppRoute.licenses => AboutPage.licensesRowKey,
        _ => throw ArgumentError.value(route, 'route', 'not a page of About'),
      }),
    );
    await settle(tester);
    expect(
      find.byKey(ValueKey<AppRoute>(route)),
      findsOneWidget,
      reason: '${route.name} shows',
    );
  }

  /// About shows the app's [version] ("Version 2.0.0") and its copyright.
  void expectAbout({required String version}) {
    expect(find.text(version), findsOneWidget);
    expect(find.byKey(AboutHero.copyrightKey), findsOneWidget);
  }

  /// The changelog shows [release] with its first change.
  void expectChangelogShows(ChangelogRelease release) {
    expect(find.byKey(ChangelogPage.releaseKey(release.title)), findsOneWidget);
    expect(find.text(release.items.first.text), findsOneWidget);
  }

  /// Special thanks: taps [name], whose profile opens in the browser.
  Future<void> tapThanked(String name) async {
    await tester.tap(find.byKey(ThanksPage.personKey(name)));
    await settle(tester);
  }

  /// The licences (Flutter's own page) show.
  void expectLicences() => expect(find.byType(LicensePage), findsOneWidget);

  /// The section labels of the page of [route], top to bottom, among those
  /// built.
  List<String> sectionLabelsOf(AppRoute route) => <String>[
    for (final SectionLabel label in tester.widgetList<SectionLabel>(
      find.descendant(
        of: find.byKey(ValueKey<AppRoute>(route)),
        matching: find.byType(SectionLabel),
      ),
    ))
      label.label,
  ];

  Future<void> openSupport() async {
    await tapRow(SettingsTabPage.supportRowKey);
    expect(
      find.byKey(const ValueKey<AppRoute>(AppRoute.support)),
      findsOneWidget,
      reason: 'S9 shows',
    );
  }

  Future<void> tapBuyMeACoffee() async {
    await tester.tap(find.byKey(SupportPage.coffeeKey));
    await settle(tester);
  }

  Future<void> tapGitHubSponsors() async {
    await tester.tap(find.byKey(SupportPage.sponsorKey));
    await settle(tester);
  }

  /// Closes Support with its app bar's close button.
  Future<void> closeSupport() async {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<AppRoute>(AppRoute.support)),
        matching: find.byKey(OsdAppBar.leadingKey),
      ),
    );
    await settle(tester);
  }

  Future<void> openContact() async {
    await tapRow(SettingsTabPage.contactRowKey);
    expectContactOpen();
  }

  void expectContactOpen({bool open = true}) => expect(
    find.byKey(ContactDialog.problemKey),
    open ? findsOneWidget : findsNothing,
  );

  /// Taps "Something isn't working" ([ContactDialog.problemKey]) or "I have
  /// an idea" ([ContactDialog.ideaKey]), and waits until the dialog has
  /// closed (the mail app opened, or none could).
  Future<void> contact(Key option) async {
    await tester.tap(find.byKey(option));
    await harness.settleUntil(
      () => find.byKey(ContactDialog.problemKey).evaluate().isEmpty,
      reason: 'the Contact dialog closes once the mail is on its way',
    );
  }

  /// Opens the name sheet, types [name] and saves it.
  Future<void> setName(String name) async {
    await tapRow(SettingsTabPage.yourNameRowKey);
    await tester.enterText(find.byKey(YourNameSheet.fieldKey), name);
    await tester.tap(find.byKey(YourNameSheet.saveKey));
    await settle(tester);
  }
}
