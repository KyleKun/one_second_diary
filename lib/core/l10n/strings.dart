import 'package:easy_localization/easy_localization.dart';

/// Every translated string of the app, in the current app language.
///
/// Widgets read text only through this class; cubits and repositories never
/// localise. Each member looks up one key of
/// `assets/translations/<code>.json`; a key missing from the current language
/// falls back to English.
///
/// The getters read easy_localization's current translations without a
/// `BuildContext`, so they add no rebuild dependency: after a language
/// change the app root must rebuild the widget tree for the new text to
/// show.
///
/// Adding a string: add the key to `en.json` only, then one member here. If
/// an existing key already says the same thing, reuse it instead so its
/// translations apply. A parameterised string is a method with named
/// arguments that fill `{name}` placeholders.
///
/// A plural string is a JSON object of CLDR forms (`one`, `few`, `many`,
/// `other`, ...) whose every form shows `{count}`; its member takes the
/// count first and reads it through `_plural`. easy_localization picks a
/// form by category, not by exact number (ru `one` also serves 21, English 0
/// is `other`), so exact-number copy ("Delete this movie?", "No clips
/// found") has a key of its own. Counts are whole numbers, except lengths
/// in seconds (the clip editor's 1.5 s), whose form the digits shown pick.
/// A translation needs every form its language picks for whole numbers (ru
/// and be: `one`, `few`, `many`; cs: `one`, `few`), plus `other`
/// (`test/core/l10n/plural_forms.dart`, CONTRIBUTING.md).
///
/// `test/core/l10n/strings_test.dart` keeps this class and `en.json` in
/// step.
abstract final class Strings {
  static String get darkMode => 'darkMode'.tr();
  static String get language => 'language'.tr();
  static String get donationPageTitle => 'donationPageTitle'.tr();
  static String get about => 'about'.tr();

  static String appVersion({required String version}) =>
      'appVersion'.tr(namedArgs: {'version': version});

  static String get record => 'record'.tr();
  static String get createMovie => 'createMovie'.tr();
  static String get settings => 'settings'.tr();
  static String get movieErrorTitle => 'movieErrorTitle'.tr();
  static String get movieInsufficientVideos => 'movieInsufficientVideos'.tr();
  static String get movieCreatedTitle => 'movieCreatedTitle'.tr();
  static String get movieCreatedDesc => 'movieCreatedDesc'.tr();
  static String get create => 'create'.tr();
  static String get edit => 'edit'.tr();
  static String get recordingErrorTitle => 'recordingErrorTitle'.tr();
  static String get save => 'save'.tr();
  static String get saveVideoErrorTitle => 'saveVideoErrorTitle'.tr();
  static String get videoSavedTitle => 'videoSavedTitle'.tr();
  static String get saveVideo => 'saveVideo'.tr();
  static String get discardVideoTitle => 'discardVideoTitle'.tr();
  static String get introTitle1 => 'introTitle1'.tr();
  static String get introDesc1 => 'introDesc1'.tr();
  static String get introTitle2 => 'introTitle2'.tr();
  static String get introDesc2 => 'introDesc2'.tr();
  static String get done => 'done'.tr();
  static String get licenses => 'licenses'.tr();
  static String get contact => 'contact'.tr();
  static String get share => 'share'.tr();
  static String get shareMsg => 'shareMsg'.tr();
  static String get thanksTo => 'thanksTo'.tr();
  static String get notifications => 'notifications'.tr();
  static String get enableNotifications => 'enableNotifications'.tr();
  static String get scheduleTime => 'scheduleTime'.tr();
  static String get usePersistentNotifications =>
      'usePersistentNotifications'.tr();
  static String get notificationTitle => 'notificationTitle'.tr();
  static String get notificationBody => 'notificationBody'.tr();
  static String get recordingSettings => 'recordingSettings'.tr();
  static String get clipLength => 'clipLength'.tr();
  static String get countdown => 'countdown'.tr();
  static String get countdownHint => 'countdownHint'.tr();
  static String get selectColor => 'selectColor'.tr();
  static String get textOutline => 'textOutline'.tr();
  static String get textOutlineHint => 'textOutlineHint'.tr();
  static String get stampSizeLabel => 'stampSizeLabel'.tr();
  static String get stampSizeSmall => 'stampSizeSmall'.tr();
  static String get stampSizeMedium => 'stampSizeMedium'.tr();
  static String get stampSizeLarge => 'stampSizeLarge'.tr();
  static String get enableGeotagging => 'enableGeotagging'.tr();
  static String get ok => 'ok'.tr();
  static String get reset => 'reset'.tr();
  static String get enterLocation => 'enterLocation'.tr();
  static String get allTime => 'allTime'.tr();
  static String get last7Days => 'last7Days'.tr();
  static String get last30Days => 'last30Days'.tr();
  static String get thisMonth => 'thisMonth'.tr();
  static String get thisYear => 'thisYear'.tr();
  static String get lastYear => 'lastYear'.tr();
  static String get selectVideos => 'selectVideos'.tr();
  static String get editSubtitles => 'editSubtitles'.tr();
  static String get noVideoRecorded => 'noVideoRecorded'.tr();
  static String get subtitles => 'subtitles'.tr();
  static String get addVideo => 'addVideo'.tr();
  static String get addPhotoAsVideo => 'addPhotoAsVideo'.tr();
  static String get savePhoto => 'savePhoto'.tr();
  static String get calendar => 'calendar'.tr();
  static String get orientation => 'orientation'.tr();
  static String get portrait => 'portrait'.tr();
  static String get landscape => 'landscape'.tr();
  static String get profiles => 'profiles'.tr();
  static String get tapToSwitch => 'tapToSwitch'.tr();
  static String get createNewProfile => 'createNewProfile'.tr();
  static String get newProfile => 'newProfile'.tr();
  static String get deleteProfile => 'deleteProfile'.tr();
  static String get enterProfileName => 'enterProfileName'.tr();
  static String get newProfileTooltip => 'newProfileTooltip'.tr();
  static String get deleteProfileTooltip => 'deleteProfileTooltip'.tr();
  static String get profileNameCannotBeEmpty => 'profileNameCannotBeEmpty'.tr();
  static String get reservedProfileName => 'reservedProfileName'.tr();
  static String get cameraMicPermissionTitle => 'cameraMicPermissionTitle'.tr();
  static String get cameraMicPermissionDesc => 'cameraMicPermissionDesc'.tr();
  static String get cameraPermissionTitle => 'cameraPermissionTitle'.tr();
  static String get cameraPermissionDesc => 'cameraPermissionDesc'.tr();
  static String get permissionSettingsHint => 'permissionSettingsHint'.tr();
  static String get allowAccess => 'allowAccess'.tr();
  static String get openSettings => 'openSettings'.tr();
  static String get notNow => 'notNow'.tr();
  static String get onboardingOrientationDesc =>
      'onboardingOrientationDesc'.tr();
  static String get doNotCloseTheApp => 'doNotCloseTheApp'.tr();
  static String get cancelMovieCreation => 'cancelMovieCreation'.tr();
  static String get reportError => 'reportError'.tr();

  // The bug-report subject is always English, so it is no translation key:
  // BugReportService builds it.
  static String get errorMailBody => 'errorMailBody'.tr();
  static String get processingVideo => 'processingVideo'.tr();
  static String get deleteVideoWarning => 'deleteVideoWarning'.tr();
  static String get deleteVideo => 'deleteVideo'.tr();
  static String get addSubtitles => 'addSubtitles'.tr();
  static String get dateColorAndFormat => 'dateColorAndFormat'.tr();
  static String get locationServicesDisabled => 'locationServicesDisabled'.tr();
  static String get locationPermissionPermanentlyDenied =>
      'locationPermissionPermanentlyDenied'.tr();

  /// The key is `default`, a reserved word in Dart.
  static String get defaultProfile => 'default'.tr();

  static String get profileNameAlreadyExists => 'profileNameAlreadyExists'.tr();
  static String get profileNameCannotContainSpecialChars =>
      'profileNameCannotContainSpecialChars'.tr();
  static String get subtitlesSaved => 'subtitlesSaved'.tr();
  static String get error => 'error'.tr();
  static String get migrationError => 'migrationError'.tr();
  static String get success => 'success'.tr();
  static String get migrationSuccess => 'migrationSuccess'.tr();
  static String get migrationInProgress => 'migrationInProgress'.tr();
  static String get migrationFolderDeletionError =>
      'migrationFolderDeletionError'.tr();
  static String get preferences => 'preferences'.tr();
  static String get forceNativeCamera => 'forceNativeCamera'.tr();
  static String get forceNativeCameraDescription =>
      'forceNativeCameraDescription'.tr();
  static String get myMovies => 'myMovies'.tr();
  static String get noMoviesFound => 'noMoviesFound'.tr();
  static String get play => 'play'.tr();
  static String get saveVideoTabOne => 'saveVideoTabOne'.tr();
  static String get saveVideoTabTwo => 'saveVideoTabTwo'.tr();
  static String get saveVideoTabThree => 'saveVideoTabThree'.tr();
  static String get useExperimentalPicker => 'useExperimentalPicker'.tr();
  static String get useExperimentalPickerDescription =>
      'useExperimentalPickerDescription'.tr();
  static String get currentProfile => 'currentProfile'.tr();
  static String get change => 'change'.tr();
  static String get useFilterInExperimentalPicker =>
      'useFilterInExperimentalPicker'.tr();
  static String get useAlternativeCalendarColors =>
      'useAlternativeCalendarColors'.tr();
  static String get legacyStampFont => 'legacyStampFont'.tr();
  static String get legacyStampFontDescription =>
      'legacyStampFontDescription'.tr();
  static String get verboseLogging => 'verboseLogging'.tr();
  static String get verboseLoggingDescription =>
      'verboseLoggingDescription'.tr();

  // Shell and shared.

  // "Today", a tab's position and "selected" come from Flutter, which
  // translates them into every app language: CommonLabels.today,
  // MaterialLocalizations.tabLabel and the Semantics selected flag.
  static String get diary => 'diary'.tr();
  static String get journey => 'journey'.tr();
  static String get commonUndo => 'commonUndo'.tr();
  static String get commonTryAgain => 'commonTryAgain'.tr();
  static String get commonRename => 'commonRename'.tr();
  static String get commonCopied => 'commonCopied'.tr();

  /// [text] between the language's quotation marks.
  static String quotedText({required String text}) =>
      'quotedText'.tr(namedArgs: {'text': text});

  /// A range between two dates already formatted for the locale.
  static String dateRangeValue({required String start, required String end}) =>
      'dateRangeValue'.tr(namedArgs: {'start': start, 'end': end});

  /// [value] marked as an estimate (a duration until the backfill ends). A
  /// word, not "≈": the value is display text, and Yusei Magic has no ≈
  /// glyph.
  static String approximateValue({required String value}) =>
      'approximateValue'.tr(namedArgs: {'value': value});

  static String durationHoursShort({required int count}) =>
      'durationHoursShort'.tr(namedArgs: {'count': '$count'});

  static String durationMinutesShort({required int count}) =>
      'durationMinutesShort'.tr(namedArgs: {'count': '$count'});

  static String durationSecondsShort({required int count}) =>
      'durationSecondsShort'.tr(namedArgs: {'count': '$count'});

  static String clipCount(int count, {NumberFormat? format}) =>
      _plural('clipCount', count, format: format);

  static String get importFailed => 'importFailed'.tr();
  static String get notEnoughStorage => 'notEnoughStorage'.tr();
  static String get linkOpenFailed => 'linkOpenFailed'.tr();
  static String get copyLink => 'copyLink'.tr();
  static String get opensInBrowserHint => 'opensInBrowserHint'.tr();
  static String get playerOpenFullScreen => 'playerOpenFullScreen'.tr();
  static String get playerMute => 'playerMute'.tr();
  static String get playerUnmute => 'playerUnmute'.tr();
  static String get playerPause => 'playerPause'.tr();
  static String get playerErrorTitle => 'playerErrorTitle'.tr();
  static String get playerErrorBody => 'playerErrorBody'.tr();

  /// The launch error when Android reports no shared storage.
  static String get storageUnavailableTitle => 'storageUnavailableTitle'.tr();
  static String get storageUnavailableBody => 'storageUnavailableBody'.tr();

  /// Where older installs saved clips while the shared storage was missing:
  /// [path], the app's private folder.
  static String storageUnavailableOldClips({required String path}) =>
      'storageUnavailableOldClips'.tr(namedArgs: {'path': path});

  // Permissions.

  static String get galleryPermissionTitle => 'galleryPermissionTitle'.tr();
  static String get galleryPermissionBody => 'galleryPermissionBody'.tr();

  /// The iOS location prompt (`NSLocationWhenInUseUsageDescription`), which
  /// tool/ios/info_plist_strings.dart writes into each InfoPlist.strings.
  static String get locationPermissionPrompt => 'locationPermissionPrompt'.tr();

  static String get storagePermissionTitle => 'storagePermissionTitle'.tr();
  static String get storagePermissionBody => 'storagePermissionBody'.tr();
  static String get cameraMicOffHint => 'cameraMicOffHint'.tr();
  static String get cameraFocusLockedHint => 'cameraFocusLockedHint'.tr();

  // Onboarding.

  static String get onboardingNext => 'onboardingNext'.tr();

  static String onboardingPageIndicator({
    required int current,
    required int total,
  }) => 'onboardingPageIndicator'.tr(
    namedArgs: {'current': '$current', 'total': '$total'},
  );

  static String dayCount(int count, {NumberFormat? format}) =>
      _plural('dayCount', count, format: format);

  static String onboardingMovieLength({required int minutes}) =>
      'onboardingMovieLength'.tr(namedArgs: {'minutes': '$minutes'});

  static String get onboardingIntro3Title => 'onboardingIntro3Title'.tr();
  static String get onboardingIntro3Body => 'onboardingIntro3Body'.tr();
  static String get onboardingChipNoAds => 'onboardingChipNoAds'.tr();
  static String get onboardingChipNoAccount => 'onboardingChipNoAccount'.tr();
  static String get onboardingChipOffline => 'onboardingChipOffline'.tr();
  static String get onboardingChipOnDevice => 'onboardingChipOnDevice'.tr();

  static String get onboardingOrientationQuestion =>
      'onboardingOrientationQuestion'.tr();

  /// Pass [landscape]. Keep the `<b>` tags; the tip card shows that run bold.
  static String onboardingOrientationTipLandscape({
    required String landscape,
  }) => 'onboardingOrientationTipLandscape'.tr(
    namedArgs: {'landscape': landscape},
  );

  /// Pass [portrait]. Keep the `<b>` tags; the tip card shows that run bold.
  static String onboardingOrientationTipPortrait({required String portrait}) =>
      'onboardingOrientationTipPortrait'.tr(namedArgs: {'portrait': portrait});

  static String get orientationLandscapeDetail =>
      'orientationLandscapeDetail'.tr();
  static String get orientationPortraitDetail =>
      'orientationPortraitDetail'.tr();
  static String get onboardingStartDiary => 'onboardingStartDiary'.tr();
  static String get onboardingSetupError => 'onboardingSetupError'.tr();

  // Onboarding: permissions.

  static String get onboardingPermissionsTitle =>
      'onboardingPermissionsTitle'.tr();
  static String get onboardingPermissionsBody =>
      'onboardingPermissionsBody'.tr();
  static String get onboardingPermissionGallery =>
      'onboardingPermissionGallery'.tr();
  static String get onboardingPermissionGalleryDesc =>
      'onboardingPermissionGalleryDesc'.tr();
  static String get onboardingPermissionCamera =>
      'onboardingPermissionCamera'.tr();
  static String get onboardingPermissionCameraDesc =>
      'onboardingPermissionCameraDesc'.tr();
  static String get onboardingPermissionMicrophone =>
      'onboardingPermissionMicrophone'.tr();
  static String get onboardingPermissionMicrophoneDesc =>
      'onboardingPermissionMicrophoneDesc'.tr();
  static String get onboardingPermissionNotifications =>
      'onboardingPermissionNotifications'.tr();
  static String get onboardingPermissionNotificationsDesc =>
      'onboardingPermissionNotificationsDesc'.tr();
  static String get onboardingPermissionLocation =>
      'onboardingPermissionLocation'.tr();
  static String get onboardingPermissionLocationDesc =>
      'onboardingPermissionLocationDesc'.tr();
  static String get onboardingPermissionOptional =>
      'onboardingPermissionOptional'.tr();
  static String get onboardingPermissionAllow =>
      'onboardingPermissionAllow'.tr();
  static String get onboardingPermissionAllowed =>
      'onboardingPermissionAllowed'.tr();
  static String get onboardingPermissionDeniedHint =>
      'onboardingPermissionDeniedHint'.tr();
  static String onboardingPermissionsProgress({
    required int granted,
    required int total,
  }) => 'onboardingPermissionsProgress'.tr(
    namedArgs: {'granted': '$granted', 'total': '$total'},
  );
  static String get onboardingPermissionsAllDone =>
      'onboardingPermissionsAllDone'.tr();

  // Your name.

  static String get yourName => 'yourName'.tr();
  static String get yourNameOptional => 'yourNameOptional'.tr();
  static String get yourNameHint => 'yourNameHint'.tr();
  static String get yourNameHelper => 'yourNameHelper'.tr();
  static String get yourNameNotSet => 'yourNameNotSet'.tr();

  // Places (the globe).

  static String placesCountryCount(int count, {NumberFormat? format}) =>
      _plural('placesCountryCount', count, format: format);

  /// "{a} · {b}": two facts side by side.
  static String placesJoin({required String a, required String b}) =>
      'placesJoin'.tr(namedArgs: {'a': a, 'b': b});

  /// "{a}, {b}": names in a list.
  static String placesNamesJoin({required String a, required String b}) =>
      'placesNamesJoin'.tr(namedArgs: {'a': a, 'b': b});

  static String get placesSearch => 'placesSearch'.tr();
  static String get placesHome => 'placesHome'.tr();
  static String get placesReplayStart => 'placesReplayStart'.tr();
  static String placesReplayStep({
    required String step,
    required String total,
  }) => 'placesReplayStep'.tr(namedArgs: {'step': step, 'total': total});
  static String get placesReplayStop => 'placesReplayStop'.tr();
  static String get placesShowAll => 'placesShowAll'.tr();
  static String get placesFlyHome => 'placesFlyHome'.tr();
  static String placesYourYear({required String year}) =>
      'placesYourYear'.tr(namedArgs: {'year': year});
  static String placesYourCountry({required String country}) =>
      'placesYourCountry'.tr(namedArgs: {'country': country});
  static String get placesYourWorld => 'placesYourWorld'.tr();

  /// [clips] is [clipCount], [places] is [placeCount].
  static String placesClipsInPlaces({
    required String clips,
    required String places,
  }) => 'placesClipsInPlaces'.tr(namedArgs: {'clips': clips, 'places': places});
  static String get placesReplay => 'placesReplay'.tr();
  static String get placesAllTime => 'placesAllTime'.tr();
  static String get placesSelectYear => 'placesSelectYear'.tr();
  static String get placesChooseYear => 'placesChooseYear'.tr();
  static String placesAllIn({required String country}) =>
      'placesAllIn'.tr(namedArgs: {'country': country});

  /// [countries] is [placesCountryCount].
  static String placesInCountries({required String countries}) =>
      'placesInCountries'.tr(namedArgs: {'countries': countries});
  static String get placesMostFilmed => 'placesMostFilmed'.tr();
  static String placesNewIn({required String year}) =>
      'placesNewIn'.tr(namedArgs: {'year': year});
  static String get placesNoNewPlaces => 'placesNoNewPlaces'.tr();
  static String get placesWithPlace => 'placesWithPlace'.tr();

  /// "12 of 312 clips": both already formatted numbers.
  static String placesClipsOfTotal({
    required String clips,
    required String total,
  }) => 'placesClipsOfTotal'.tr(namedArgs: {'clips': clips, 'total': total});
  static String get placesClips => 'placesClips'.tr();
  static String placesWithPlaceIn({required String year}) =>
      'placesWithPlaceIn'.tr(namedArgs: {'year': year});
  static String get placesFarthest => 'placesFarthest'.tr();
  static String placesNameCountry({
    required String name,
    required String country,
  }) => 'placesNameCountry'.tr(namedArgs: {'name': name, 'country': country});
  static String get placesTopCountries => 'placesTopCountries'.tr();
  static String get placesTopPlaces => 'placesTopPlaces'.tr();
  static String get placesAllCountries => 'placesAllCountries'.tr();
  static String get placesAllPlaces => 'placesAllPlaces'.tr();

  /// [km] is the formatted number.
  static String placesKm({required String km}) =>
      'placesKm'.tr(namedArgs: {'km': km});

  /// [km] is [placesKm].
  static String placesKmFromHome({required String km}) =>
      'placesKmFromHome'.tr(namedArgs: {'km': km});
  static String get placesNotOnMap => 'placesNotOnMap'.tr();
  static String placesNotOnMapCount(int count, {NumberFormat? format}) =>
      _plural('placesNotOnMapCount', count, format: format);
  static String get placesNotOnMapBody => 'placesNotOnMapBody'.tr();
  static String placesLookUpNames(int count, {NumberFormat? format}) =>
      _plural('placesLookUpNames', count, format: format);
  static String placesFinding(int count, {NumberFormat? format}) =>
      _plural('placesFinding', count, format: format);
  static String placesLookupPartial(int count, {NumberFormat? format}) =>
      _plural('placesLookupPartial', count, format: format);
  static String get placesLookupNone => 'placesLookupNone'.tr();
  static String get placesLookupOffline => 'placesLookupOffline'.tr();

  /// [count] is the formatted number.
  static String placesNotOnMapShowAll({required String count}) =>
      'placesNotOnMapShowAll'.tr(namedArgs: {'count': count});
  static String get placesNotOnMapShowFewer => 'placesNotOnMapShowFewer'.tr();
  static String get placesPinOnMap => 'placesPinOnMap'.tr();
  static String get placesChangePin => 'placesChangePin'.tr();
  static String get placesPinWhere => 'placesPinWhere'.tr();
  static String get placesPinCurrentHint => 'placesPinCurrentHint'.tr();
  static String get placesPinSameAs => 'placesPinSameAs'.tr();
  static String get placesPinSameAsHint => 'placesPinSameAsHint'.tr();
  static String get placesPinSearch => 'placesPinSearch'.tr();
  static String get placesPinSearchHint => 'placesPinSearchHint'.tr();
  static String get placesPinOnGlobe => 'placesPinOnGlobe'.tr();
  static String get placesPinOnGlobeHint => 'placesPinOnGlobeHint'.tr();
  static String get placesPinSearchField => 'placesPinSearchField'.tr();
  static String get placesPinSearchAction => 'placesPinSearchAction'.tr();
  static String get placesPinSearching => 'placesPinSearching'.tr();
  static String get placesPinPrivacy => 'placesPinPrivacy'.tr();
  static String get placesPinFound => 'placesPinFound'.tr();
  static String get placesPinFoundUnnamed => 'placesPinFoundUnnamed'.tr();
  static String get placesPinUseThis => 'placesPinUseThis'.tr();
  static String get placesPinNotFound => 'placesPinNotFound'.tr();
  static String get placesPinOffline => 'placesPinOffline'.tr();
  static String get placesPinHere => 'placesPinHere'.tr();
  static String placesPinMove({required String place}) =>
      'placesPinMove'.tr(namedArgs: {'place': place});
  static String get placesNoneBody => 'placesNoneBody'.tr();
  static String get placesHowLocationTitle => 'placesHowLocationTitle'.tr();
  static String get placesHowLocationBody => 'placesHowLocationBody'.tr();
  static String get placesHowElsewhereTitle => 'placesHowElsewhereTitle'.tr();
  static String get placesHowElsewhereBody => 'placesHowElsewhereBody'.tr();
  static String get placesHowStaysTitle => 'placesHowStaysTitle'.tr();
  static String get placesHowStaysBody => 'placesHowStaysBody'.tr();
  static String get placesRecordToday => 'placesRecordToday'.tr();
  static String get placesNoneHint => 'placesNoneHint'.tr();
  static String get placesFilterCountries => 'placesFilterCountries'.tr();
  static String get placesFilterPlaces => 'placesFilterPlaces'.tr();
  static String get placesSortMostClips => 'placesSortMostClips'.tr();
  static String get placesSortRecent => 'placesSortRecent'.tr();
  static String get placesSortAz => 'placesSortAz'.tr();
  static String placesNothingMatches({required String query}) =>
      'placesNothingMatches'.tr(namedArgs: {'query': query});
  static String get placesPlayAll => 'placesPlayAll'.tr();
  static String get placesMakeMovie => 'placesMakeMovie'.tr();
  static String placesAndNearby({required String place}) =>
      'placesAndNearby'.tr(namedArgs: {'place': place});

  /// [clips] is [clipCount].
  static String placesMarkerSemantics({
    required String name,
    required String clips,
  }) => 'placesMarkerSemantics'.tr(namedArgs: {'name': name, 'clips': clips});

  /// [count] is the other places in the stack; [clips] is [clipCount].
  static String placesStackSemantics(
    int count, {
    required String name,
    required String clips,
    NumberFormat? format,
  }) => _plural(
    'placesStackSemantics',
    count,
    namedArgs: {'name': name, 'clips': clips},
    format: format,
  );
  static String placesStackLabel({
    required String name,
    required String count,
  }) => 'placesStackLabel'.tr(namedArgs: {'name': name, 'count': count});
  static String get placesSearchHint => 'placesSearchHint'.tr();
  static String placesNoMatch({required String query}) =>
      'placesNoMatch'.tr(namedArgs: {'query': query});
  static String get placesRecentTrips => 'placesRecentTrips'.tr();
  static String get placesCountries => 'placesCountries'.tr();

  /// "3 Mar – 12 Jun 2026": two formatted dates.
  static String placesRange({required String from, required String to}) =>
      'placesRange'.tr(namedArgs: {'from': from, 'to': to});

  // Character.

  static String get characterSheetTitle => 'characterSheetTitle'.tr();
  static String get characterPartShape => 'characterPartShape'.tr();
  static String get characterPartEyes => 'characterPartEyes'.tr();
  static String get characterPartMouth => 'characterPartMouth'.tr();
  static String get characterPartColour => 'characterPartColour'.tr();
  static String get characterShapeTriangle => 'characterShapeTriangle'.tr();
  static String get characterShapeRound => 'characterShapeRound'.tr();
  static String get characterShapeSquircle => 'characterShapeSquircle'.tr();
  static String get characterShapeDrop => 'characterShapeDrop'.tr();
  static String get characterShapeCloud => 'characterShapeCloud'.tr();
  static String get characterShapeHeart => 'characterShapeHeart'.tr();
  static String get characterShapeStar => 'characterShapeStar'.tr();
  static String get characterShapeFlower => 'characterShapeFlower'.tr();
  static String get characterShapeGhost => 'characterShapeGhost'.tr();
  static String get characterShapeMochi => 'characterShapeMochi'.tr();
  static String get characterShapeHexagon => 'characterShapeHexagon'.tr();
  static String get characterShapePebble => 'characterShapePebble'.tr();
  static String get characterEyesClassic => 'characterEyesClassic'.tr();
  static String get characterEyesDots => 'characterEyesDots'.tr();
  static String get characterEyesBig => 'characterEyesBig'.tr();
  static String get characterEyesShy => 'characterEyesShy'.tr();
  static String get characterEyesSleepy => 'characterEyesSleepy'.tr();
  static String get characterEyesSparkle => 'characterEyesSparkle'.tr();
  static String get characterMouthSimple => 'characterMouthSimple'.tr();
  static String get characterMouthCat => 'characterMouthCat'.tr();
  static String get characterMouthOpen => 'characterMouthOpen'.tr();
  static String get characterMouthTiny => 'characterMouthTiny'.tr();
  static String get characterNone => 'characterNone'.tr();
  static String get characterShuffle => 'characterShuffle'.tr();
  static String get characterA11y => 'characterA11y'.tr();
  static String get characterPokeHint => 'characterPokeHint'.tr();
  static String get characterCustomizeA11y => 'characterCustomizeA11y'.tr();
  static String get characterColourA11y => 'characterColourA11y'.tr();

  // Today.

  // The character's lines (TodayLineText picks the greeting's name or
  // no-name variant).
  static String todayGreetingAnyTime1({required String name}) =>
      'todayGreetingAnyTime1'.tr(namedArgs: {'name': name});
  static String get todayGreetingAnyTime1NoName =>
      'todayGreetingAnyTime1NoName'.tr();
  static String todayGreetingAnyTime2({required String name}) =>
      'todayGreetingAnyTime2'.tr(namedArgs: {'name': name});
  static String get todayGreetingAnyTime2NoName =>
      'todayGreetingAnyTime2NoName'.tr();
  static String todayGreetingAnyTime3({required String name}) =>
      'todayGreetingAnyTime3'.tr(namedArgs: {'name': name});
  static String get todayGreetingAnyTime3NoName =>
      'todayGreetingAnyTime3NoName'.tr();
  static String todayGreetingAnyTime4({required String name}) =>
      'todayGreetingAnyTime4'.tr(namedArgs: {'name': name});
  static String get todayGreetingAnyTime4NoName =>
      'todayGreetingAnyTime4NoName'.tr();
  static String todayGreetingMorning({required String name}) =>
      'todayGreetingMorning'.tr(namedArgs: {'name': name});
  static String get todayGreetingMorningNoName =>
      'todayGreetingMorningNoName'.tr();
  static String todayGreetingAfternoon({required String name}) =>
      'todayGreetingAfternoon'.tr(namedArgs: {'name': name});
  static String get todayGreetingAfternoonNoName =>
      'todayGreetingAfternoonNoName'.tr();
  static String todayGreetingEvening({required String name}) =>
      'todayGreetingEvening'.tr(namedArgs: {'name': name});
  static String get todayGreetingEveningNoName =>
      'todayGreetingEveningNoName'.tr();
  static String todayGreetingLateNight({required String name}) =>
      'todayGreetingLateNight'.tr(namedArgs: {'name': name});
  static String get todayGreetingLateNightNoName =>
      'todayGreetingLateNightNoName'.tr();
  static String get todayLineWelcomeBack => 'todayLineWelcomeBack'.tr();
  static String get todayLineWaiting1 => 'todayLineWaiting1'.tr();
  static String get todayLineWaiting2 => 'todayLineWaiting2'.tr();
  static String get todayLineWaiting3 => 'todayLineWaiting3'.tr();
  static String get todayLineWaiting4 => 'todayLineWaiting4'.tr();
  static String get todayLineWaiting5 => 'todayLineWaiting5'.tr();
  static String get todayLineWaiting6 => 'todayLineWaiting6'.tr();
  static String get todayLineWaiting7 => 'todayLineWaiting7'.tr();
  static String get todayLineWaiting8 => 'todayLineWaiting8'.tr();
  static String get todayLineWaiting9 => 'todayLineWaiting9'.tr();
  static String get todayLineJustSaved1 => 'todayLineJustSaved1'.tr();
  static String get todayLineJustSaved2 => 'todayLineJustSaved2'.tr();
  static String get todayLineJustSaved3 => 'todayLineJustSaved3'.tr();
  static String get todayLineJustSaved4 => 'todayLineJustSaved4'.tr();
  static String get todayLineManySeconds => 'todayLineManySeconds'.tr();
  static String get todayLineFirstClipEver => 'todayLineFirstClipEver'.tr();
  static String get todayLineMilestone7 => 'todayLineMilestone7'.tr();
  static String get todayLineMilestone30 => 'todayLineMilestone30'.tr();
  static String get todayLineMilestone100 => 'todayLineMilestone100'.tr();
  static String get todayLineMilestone365 => 'todayLineMilestone365'.tr();
  static String get todayLineKeptOne1 => 'todayLineKeptOne1'.tr();
  static String get todayLineKeptOne2 => 'todayLineKeptOne2'.tr();
  static String get todayLineKeptOne3 => 'todayLineKeptOne3'.tr();
  static String get todayLineKeptOne4 => 'todayLineKeptOne4'.tr();
  static String get todayLineKeptOne5 => 'todayLineKeptOne5'.tr();
  static String get todayLineKeptOne6 => 'todayLineKeptOne6'.tr();
  static String get todayLineKeptSeveral1 => 'todayLineKeptSeveral1'.tr();
  static String get todayLineKeptSeveral2 => 'todayLineKeptSeveral2'.tr();
  static String get todayLineKeptSeveral3 => 'todayLineKeptSeveral3'.tr();
  static String get todayLineKeptSeveral4 => 'todayLineKeptSeveral4'.tr();
  static String get todayLineDeletedEmpty1 => 'todayLineDeletedEmpty1'.tr();
  static String get todayLineDeletedEmpty2 => 'todayLineDeletedEmpty2'.tr();
  static String get todayLineDeletedEmpty3 => 'todayLineDeletedEmpty3'.tr();
  static String get todayLineDeletedEmpty4 => 'todayLineDeletedEmpty4'.tr();
  static String get todayLineDeletedKept1 => 'todayLineDeletedKept1'.tr();
  static String get todayLineDeletedKept2 => 'todayLineDeletedKept2'.tr();
  static String get todayLineDeletedKept3 => 'todayLineDeletedKept3'.tr();
  static String get todayLinePoke1 => 'todayLinePoke1'.tr();
  static String get todayLinePoke2 => 'todayLinePoke2'.tr();
  static String get todayLinePoke3 => 'todayLinePoke3'.tr();
  static String get todayLinePoke4 => 'todayLinePoke4'.tr();
  static String get todayLinePoke5 => 'todayLinePoke5'.tr();
  static String get todayLinePokeWaiting1 => 'todayLinePokeWaiting1'.tr();
  static String get todayLinePokeWaiting2 => 'todayLinePokeWaiting2'.tr();
  static String get todayLineCustomized1 => 'todayLineCustomized1'.tr();
  static String get todayLineCustomized2 => 'todayLineCustomized2'.tr();
  static String get todayLineProfileSwitched1 =>
      'todayLineProfileSwitched1'.tr();
  static String get todayLineProfileSwitched2 =>
      'todayLineProfileSwitched2'.tr();
  static String get todayLineProfileSwitched3 =>
      'todayLineProfileSwitched3'.tr();
  static String get todayImport => 'todayImport'.tr();
  static String get todayImportA11y => 'todayImportA11y'.tr();
  static String get todayRecordA11y => 'todayRecordA11y'.tr();
  static String get todaySavedBadge => 'todaySavedBadge'.tr();
  static String get todayPlayA11y => 'todayPlayA11y'.tr();
  static String get todayEditSheetTitle => 'todayEditSheetTitle'.tr();
  static String get recordAgain => 'recordAgain'.tr();
  static String get replaceFromGallery => 'replaceFromGallery'.tr();
  static String get todayAddAnother => 'todayAddAnother'.tr();
  static String get todayAddAnotherTitle => 'todayAddAnotherTitle'.tr();

  static String todayClipPositionA11y({
    required int index,
    required int count,
  }) => 'todayClipPositionA11y'.tr(
    namedArgs: {'index': '$index', 'count': '$count'},
  );

  static String todayClipCounter({required int index, required int count}) =>
      'todayClipCounter'.tr(namedArgs: {'index': '$index', 'count': '$count'});

  static String todaySnackbarSavedBody({required String name}) =>
      'todaySnackbarSavedBody'.tr(namedArgs: {'name': name});

  static String get todaySnackbarSavedBodyNoName =>
      'todaySnackbarSavedBodyNoName'.tr();

  static String todaySnackbarSavedBodyCount({required int count}) =>
      'todaySnackbarSavedBodyCount'.tr(namedArgs: {'count': '$count'});

  static String get todaySnackbarUndoFailed => 'todaySnackbarUndoFailed'.tr();
  static String get profileSheetTitle => 'profileSheetTitle'.tr();
  static String get profileSheetSubtitle => 'profileSheetSubtitle'.tr();

  /// [orientation] is [landscape] or [portrait]; 0 videos use
  /// [profileRowSubtitleEmpty].
  static String profileRowSubtitle(
    int count, {
    required String orientation,
    NumberFormat? format,
  }) => _plural(
    'profileRowSubtitle',
    count,
    namedArgs: {'orientation': orientation},
    format: format,
  );

  static String profileRowSubtitleEmpty({required String orientation}) =>
      'profileRowSubtitleEmpty'.tr(namedArgs: {'orientation': orientation});

  /// The profile chip's button label, [name] being the active profile's.
  static String todayProfileChipA11y({required String name}) =>
      'todayProfileChipA11y'.tr(namedArgs: {'name': name});

  /// What a tap on Today's profile chip does (a semantics tap hint).
  static String get todayProfileChipTapHint => 'todayProfileChipTapHint'.tr();

  // Recording.

  static String get cameraOrientationAutoRotate =>
      'cameraOrientationAutoRotate'.tr();
  static String get cameraOrientationLockedLandscape =>
      'cameraOrientationLockedLandscape'.tr();
  static String get cameraOrientationLockedPortrait =>
      'cameraOrientationLockedPortrait'.tr();

  /// Pass [cameraOrientationWordLandscape] or [cameraOrientationWordPortrait];
  /// the bubble shows that word bold.
  static String cameraOrientationLockedExplainer({
    required String orientation,
  }) => 'cameraOrientationLockedExplainer'.tr(
    namedArgs: {'orientation': orientation},
  );

  static String get cameraOrientationWordLandscape =>
      'cameraOrientationWordLandscape'.tr();
  static String get cameraOrientationWordPortrait =>
      'cameraOrientationWordPortrait'.tr();
  static String get cameraOrientationAutoExplainer =>
      'cameraOrientationAutoExplainer'.tr();

  static String cameraOrientationSemantics({required String state}) =>
      'cameraOrientationSemantics'.tr(namedArgs: {'state': state});

  static String cameraClipLengthSeconds(int count, {NumberFormat? format}) =>
      _plural('cameraClipLengthSeconds', count, format: format);

  static String cameraClipLengthSemantics({required String length}) =>
      'cameraClipLengthSemantics'.tr(namedArgs: {'length': length});

  static String clipLengthSecondsShort({required int count}) =>
      'clipLengthSecondsShort'.tr(namedArgs: {'count': '$count'});

  static String get cameraCloseSemantics => 'cameraCloseSemantics'.tr();
  static String get cameraStopSemantics => 'cameraStopSemantics'.tr();
  static String get cameraRecordingAnnouncement =>
      'cameraRecordingAnnouncement'.tr();
  static String get cameraSwitchSemantics => 'cameraSwitchSemantics'.tr();
  static String get cameraBackCamera => 'cameraBackCamera'.tr();
  static String get cameraFrontCamera => 'cameraFrontCamera'.tr();
  static String get cameraLens => 'cameraLens'.tr();
  static String get cameraLensWide => 'cameraLensWide'.tr();
  static String get cameraLensUltraWide => 'cameraLensUltraWide'.tr();
  static String get cameraLensTelephoto => 'cameraLensTelephoto'.tr();

  /// A lens the phone does not name: "Camera 2".
  static String cameraLensNumbered({required int number}) =>
      'cameraLensNumbered'.tr(namedArgs: {'number': '$number'});

  static String recordingTimerProgress({
    required String elapsed,
    required String total,
  }) => 'recordingTimerProgress'.tr(
    namedArgs: {'elapsed': elapsed, 'total': total},
  );

  static String cameraCountdownSemantics({required int count}) =>
      'cameraCountdownSemantics'.tr(namedArgs: {'count': '$count'});

  static String get recordingSettingsFlash => 'recordingSettingsFlash'.tr();
  static String get recordingSettingsFlashSubtitle =>
      'recordingSettingsFlashSubtitle'.tr();
  static String get recordingSettingsFlashSubtitleUnavailable =>
      'recordingSettingsFlashSubtitleUnavailable'.tr();
  static String get recordingHelpTitle => 'recordingHelpTitle'.tr();
  static String get recordingHelpGestures => 'recordingHelpGestures'.tr();
  static String get recordingHelpOptions => 'recordingHelpOptions'.tr();
  static String get recordingHelpTapTitle => 'recordingHelpTapTitle'.tr();
  static String get recordingHelpTapBody => 'recordingHelpTapBody'.tr();
  static String get recordingHelpHoldTitle => 'recordingHelpHoldTitle'.tr();
  static String get recordingHelpHoldBody => 'recordingHelpHoldBody'.tr();
  static String get recordingHelpPinchTitle => 'recordingHelpPinchTitle'.tr();
  static String get recordingHelpPinchBody => 'recordingHelpPinchBody'.tr();
  static String get recordingHelpRecordBody => 'recordingHelpRecordBody'.tr();
  static String get recordingHelpVolumeTitle => 'recordingHelpVolumeTitle'.tr();
  static String get recordingHelpVolumeBody => 'recordingHelpVolumeBody'.tr();
  static String get recordingHelpSwipeTitle => 'recordingHelpSwipeTitle'.tr();
  static String get recordingHelpSwipeBody => 'recordingHelpSwipeBody'.tr();
  static String get recordingHelpClipLengthBody =>
      'recordingHelpClipLengthBody'.tr();
  static String get recordingHelpLensBody => 'recordingHelpLensBody'.tr();
  static String get recordingHelpCountdownBody =>
      'recordingHelpCountdownBody'.tr();
  static String get recordingHelpFlashBody => 'recordingHelpFlashBody'.tr();
  static String get recordingHelpDualBody => 'recordingHelpDualBody'.tr();
  static String get recordingHelpLockBody => 'recordingHelpLockBody'.tr();
  static String get recordingSettingsDual => 'recordingSettingsDual'.tr();
  static String get recordingSettingsDualSubtitle =>
      'recordingSettingsDualSubtitle'.tr();
  static String get cameraDualLayout => 'cameraDualLayout'.tr();
  static String get cameraDualLayoutInset => 'cameraDualLayoutInset'.tr();
  static String get cameraDualLayoutSplit => 'cameraDualLayoutSplit'.tr();
  static String get cameraDualUprightHint => 'cameraDualUprightHint'.tr();
  static String get cameraDualFailedTitle => 'cameraDualFailedTitle'.tr();
  static String get cameraDualFailedBody => 'cameraDualFailedBody'.tr();
  static String get recordingSettingsLockOrientation =>
      'recordingSettingsLockOrientation'.tr();
  static String get recordingSettingsLockOrientationSubtitleLandscape =>
      'recordingSettingsLockOrientationSubtitleLandscape'.tr();
  static String get recordingSettingsLockOrientationSubtitlePortrait =>
      'recordingSettingsLockOrientationSubtitlePortrait'.tr();
  static String get cameraErrorTitle => 'cameraErrorTitle'.tr();
  static String get cameraErrorBody => 'cameraErrorBody'.tr();
  static String get cameraErrorUseNative => 'cameraErrorUseNative'.tr();
  static String get cameraRecordFailedBody => 'cameraRecordFailedBody'.tr();
  static String get cameraInterruptedTitle => 'cameraInterruptedTitle'.tr();
  static String get cameraInterruptedBody => 'cameraInterruptedBody'.tr();
  static String get cameraTooShortTitle => 'cameraTooShortTitle'.tr();
  static String get cameraTooShortBody => 'cameraTooShortBody'.tr();
  static String get recordingRecovered => 'recordingRecovered'.tr();

  // Clip editor.

  /// [seconds] may have a fraction (1.5): format it with [format].
  static String saveVideoClipLengthSemantics(
    num seconds, {
    NumberFormat? format,
  }) => _plural('saveVideoClipLengthSemantics', seconds, format: format);

  /// [seconds] may have a fraction (1.5): format it with [format].
  static String saveVideoQuickCutSemantics(
    num seconds, {
    NumberFormat? format,
  }) => _plural('saveVideoQuickCutSemantics', seconds, format: format);

  static String get saveVideoTrimSemantics => 'saveVideoTrimSemantics'.tr();

  static String saveVideoTrimValueSemantics({
    required String start,
    required String length,
  }) => 'saveVideoTrimValueSemantics'.tr(
    namedArgs: {'start': start, 'length': length},
  );

  /// Pass [cameraOrientationWordLandscape] or [cameraOrientationWordPortrait].
  static String saveVideoOrientationFitNote({required String orientation}) =>
      'saveVideoOrientationFitNote'.tr(namedArgs: {'orientation': orientation});

  static String get saveVideoCrop => 'saveVideoCrop'.tr();
  static String get saveVideoCropAuto => 'saveVideoCropAuto'.tr();
  static String get saveVideoCropCustom => 'saveVideoCropCustom'.tr();
  static String get saveVideoCropHint => 'saveVideoCropHint'.tr();
  static String get saveVideoCropZoomLabel => 'saveVideoCropZoomLabel'.tr();

  /// Pass the zoom as the locale writes it ("1.5", "1,5").
  static String saveVideoCropZoom({required String zoom}) =>
      'saveVideoCropZoom'.tr(namedArgs: {'zoom': zoom});

  static String get saveVideoErrorBody => 'saveVideoErrorBody'.tr();
  static String get discardVideoBody => 'discardVideoBody'.tr();
  static String get discardPhotoTitle => 'discardPhotoTitle'.tr();
  static String get savePhotoErrorTitle => 'savePhotoErrorTitle'.tr();
  static String get saveVideoTrimLonger => 'saveVideoTrimLonger'.tr();
  static String get saveVideoTrimShorter => 'saveVideoTrimShorter'.tr();
  static String get keepEditing => 'keepEditing'.tr();
  static String get discard => 'discard'.tr();
  static String get optionalLabel => 'optionalLabel'.tr();
  static String get saveVideoTypeLocation => 'saveVideoTypeLocation'.tr();
  static String get saveVideoLocationOffValue =>
      'saveVideoLocationOffValue'.tr();
  static String get saveVideoLocationFinding => 'saveVideoLocationFinding'.tr();
  static String get saveVideoLocationAllow => 'saveVideoLocationAllow'.tr();
  static String get saveVideoLocationUnavailable =>
      'saveVideoLocationUnavailable'.tr();
  static String get saveVideoTypedLocationLabel =>
      'saveVideoTypedLocationLabel'.tr();
  static String get saveVideoTypedLocationRemoved =>
      'saveVideoTypedLocationRemoved'.tr();
  static String get saveVideoLocationDisclosure =>
      'saveVideoLocationDisclosure'.tr();
  static String get locationOffDialogTitle => 'locationOffDialogTitle'.tr();
  static String get dateStampFormatLabel => 'dateStampFormatLabel'.tr();
  static String get colorWhite => 'colorWhite'.tr();
  static String get colorBlack => 'colorBlack'.tr();
  static String get colorCoral => 'colorCoral'.tr();
  static String get colorRed => 'colorRed'.tr();
  static String get colorOrange => 'colorOrange'.tr();
  static String get colorGold => 'colorGold'.tr();
  static String get colorYellow => 'colorYellow'.tr();
  static String get colorGreen => 'colorGreen'.tr();
  static String get colorTeal => 'colorTeal'.tr();
  static String get colorSkyBlue => 'colorSkyBlue'.tr();
  static String get colorIndigo => 'colorIndigo'.tr();
  static String get colorLavender => 'colorLavender'.tr();
  static String get colorPink => 'colorPink'.tr();
  static String get colorBrown => 'colorBrown'.tr();
  static String get colorGrey => 'colorGrey'.tr();
  static String get colorCustom => 'colorCustom'.tr();
  static String get customColorHexLabel => 'customColorHexLabel'.tr();
  static String get subtitlesHint => 'subtitlesHint'.tr();
  static String get subtitlesSaveError => 'subtitlesSaveError'.tr();

  // Private videos.

  static String get makePrivate => 'makePrivate'.tr();

  static String get makePublic => 'makePublic'.tr();

  /// The viewer's tile, which is on for a private video.
  static String get privateToggle => 'privateToggle'.tr();

  /// What a private video's blurred picture says to a screen reader.
  static String get privateVideo => 'privateVideo'.tr();

  /// On a private video's cover, where it would play.
  static String get privateTapToView => 'privateTapToView'.tr();

  static String get privateMarked => 'privateMarked'.tr();

  static String get privateMarkedHint => 'privateMarkedHint'.tr();

  static String get privateUnmarked => 'privateUnmarked'.tr();

  static String get privateSaveError => 'privateSaveError'.tr();

  static String get privateHelpTitle => 'privateHelpTitle'.tr();

  static String get privateHelpBody => 'privateHelpBody'.tr();

  static String get privateHelpMoviesTitle => 'privateHelpMoviesTitle'.tr();

  static String get privateHelpMoviesBody => 'privateHelpMoviesBody'.tr();

  static String get privateHelpBlurTitle => 'privateHelpBlurTitle'.tr();

  static String get privateHelpBlurBody => 'privateHelpBlurBody'.tr();

  static String get privateHelpDiaryTitle => 'privateHelpDiaryTitle'.tr();

  static String get privateHelpDiaryBody => 'privateHelpDiaryBody'.tr();

  static String get privateHelpKeptTitle => 'privateHelpKeptTitle'.tr();

  static String get privateHelpKeptBody => 'privateHelpKeptBody'.tr();

  // Device info in videos (Preferences).

  static String get clipDeviceInfo => 'clipDeviceInfo'.tr();

  static String get clipDeviceInfoDescription =>
      'clipDeviceInfoDescription'.tr();

  // Tags.

  static String get tags => 'tags'.tr();

  static String get editTags => 'editTags'.tr();

  /// The tags sheet's field hint.
  static String get addTag => 'addTag'.tr();

  static String get tagsNoneYet => 'tagsNoneYet'.tr();

  static String get tagsSuggestions => 'tagsSuggestions'.tr();

  static String get tagsSaved => 'tagsSaved'.tr();

  static String get tagsSaveError => 'tagsSaveError'.tr();

  static String get tagErrorEmpty => 'tagErrorEmpty'.tr();

  static String tagErrorTooLong({required int max}) =>
      'tagErrorTooLong'.tr(namedArgs: {'max': '$max'});

  static String get tagErrorComma => 'tagErrorComma'.tr();

  static String get tagErrorInvalid => 'tagErrorInvalid'.tr();

  static String get tagErrorDuplicate => 'tagErrorDuplicate'.tr();

  static String tagErrorTooMany({required int max}) =>
      'tagErrorTooMany'.tr(namedArgs: {'max': '$max'});

  /// "3 tags".
  static String tagCount(int count, {NumberFormat? format}) =>
      _plural('tagCount', count, format: format);

  /// "3 videos": how many videos carry a tag.
  static String tagVideoCount(int count, {NumberFormat? format}) =>
      _plural('tagVideoCount', count, format: format);

  static String get tagsHelpTitle => 'tagsHelpTitle'.tr();

  static String get tagsHelpBody => 'tagsHelpBody'.tr();

  static String get tagsHelpFilterTitle => 'tagsHelpFilterTitle'.tr();

  static String get tagsHelpFilterBody => 'tagsHelpFilterBody'.tr();

  static String get tagsHelpMoviesTitle => 'tagsHelpMoviesTitle'.tr();

  static String get tagsHelpMoviesBody => 'tagsHelpMoviesBody'.tr();

  static String get tagsHelpKeptTitle => 'tagsHelpKeptTitle'.tr();

  static String get tagsHelpKeptBody => 'tagsHelpKeptBody'.tr();

  static String get tagsHelpManageTitle => 'tagsHelpManageTitle'.tr();

  static String get tagsHelpManageBody => 'tagsHelpManageBody'.tr();

  // Diary: filter and search.

  static String get diaryFilter => 'diaryFilter'.tr();

  static String get diaryFilterTitle => 'diaryFilterTitle'.tr();

  static String get diarySearchHint => 'diarySearchHint'.tr();

  static String get diaryFilterUntagged => 'diaryFilterUntagged'.tr();

  static String get diaryFilterClear => 'diaryFilterClear'.tr();

  static String get diaryFilterNoTags => 'diaryFilterNoTags'.tr();
  static String get diaryFilterTagsHint => 'diaryFilterTagsHint'.tr();
  static String diaryFilterShow(int count, {NumberFormat? format}) =>
      _plural('diaryFilterShow', count, format: format);

  static String get diaryFilterNoMatches => 'diaryFilterNoMatches'.tr();

  /// "12 videos match".
  static String diaryFilterMatches(int count, {NumberFormat? format}) =>
      _plural('diaryFilterMatches', count, format: format);

  // Diary: filter.

  /// A recorded day the filter leaves out, for screen readers.
  static String get a11yDayFilteredOut => 'a11yDayFilteredOut'.tr();

  // Movies: tags.

  static String get movieTagsSection => 'movieTagsSection'.tr();

  static String get movieOnlyTagged => 'movieOnlyTagged'.tr();

  static String get movieWithoutTagged => 'movieWithoutTagged'.tr();

  static String get movieTagsAny => 'movieTagsAny'.tr();

  /// "Tagged trip, kids"; [tags] already joined for the locale.
  static String movieTagged({required String tags}) =>
      'movieTagged'.tr(namedArgs: {'tags': tags});

  /// "Without work"; [tags] already joined for the locale.
  static String movieWithout({required String tags}) =>
      'movieWithout'.tr(namedArgs: {'tags': tags});

  static String get movieStillReadingTitle => 'movieStillReadingTitle'.tr();

  static String get movieStillReadingBody => 'movieStillReadingBody'.tr();

  static String get movieHasTagFilter => 'movieHasTagFilter'.tr();

  // Movies: chapters.

  /// The player's chapters button and sheet.
  static String get movieChapters => 'movieChapters'.tr();

  /// "Chapter 3 of 25": what a screen reader says of the chapter playing;
  /// [current] and [total] already formatted.
  static String movieChapterOf({
    required String current,
    required String total,
  }) => 'movieChapterOf'.tr(namedArgs: {'current': current, 'total': total});

  // Settings: manage tags.

  static String get manageTagsDescription => 'manageTagsDescription'.tr();

  static String get renameTag => 'renameTag'.tr();

  static String get removeTag => 'removeTag'.tr();

  static String removeTagTitle({required String tag}) =>
      'removeTagTitle'.tr(namedArgs: {'tag': tag});

  /// "It will be removed from 3 videos."
  static String removeTagBody(int count, {NumberFormat? format}) =>
      _plural('removeTagBody', count, format: format);

  static String mergeTagTitle({required String tag}) =>
      'mergeTagTitle'.tr(namedArgs: {'tag': tag});

  /// "3 videos will get the tag "trip" instead."
  static String mergeTagBody(
    int count, {
    required String tag,
    NumberFormat? format,
  }) => _plural('mergeTagBody', count, namedArgs: {'tag': tag}, format: format);

  static String tagBatchProgress({required int done, required int total}) =>
      'tagBatchProgress'.tr(namedArgs: {'done': '$done', 'total': '$total'});

  /// "3 videos updated".
  static String tagBatchDone(int count, {NumberFormat? format}) =>
      _plural('tagBatchDone', count, format: format);

  /// "1 video couldn't be updated".
  static String tagBatchFailed(int count, {NumberFormat? format}) =>
      _plural('tagBatchFailed', count, format: format);

  static String get tagBatchStopped => 'tagBatchStopped'.tr();

  static String get tagColor => 'tagColor'.tr();

  static String get tagColorAuto => 'tagColorAuto'.tr();

  // Settings: tags.

  /// The title of the sheet of one tag (rename, colour, remove).
  static String get editTag => 'editTag'.tr();

  /// The hint of the name field of that sheet.
  static String get tagName => 'tagName'.tr();

  /// The confirm of "Merge into …?".
  static String get mergeTag => 'mergeTag'.tr();

  // Tags: editing.

  /// The × of a chip in the tags sheet, for screen readers.
  static String tagRemoveNamed({required String tag}) =>
      'tagRemoveNamed'.tr(namedArgs: {'tag': tag});

  static String get importSameClipBlocked => 'importSameClipBlocked'.tr();
  static String get importPickerLatestVideos => 'importPickerLatestVideos'.tr();
  static String get importPickerLatestPhotos => 'importPickerLatestPhotos'.tr();

  /// [date] is the day the picker starts at, formatted by the caller.
  static String importPickerFromDay({required String date}) =>
      'importPickerFromDay'.tr(namedArgs: {'date': date});

  /// The title of the profile sheet behind the clip editor's "Change".
  static String get saveVideoSavingInto => 'saveVideoSavingInto'.tr();

  // Diary and viewer.

  static String get memories => 'memories'.tr();
  static String get diaryViewCalendar => 'diaryViewCalendar'.tr();
  static String get diaryViewMemories => 'diaryViewMemories'.tr();

  /// "[recorded] of [count] days": [count] is the number of days of the month
  /// shown so far.
  static String diaryMonthProgress(
    int count, {
    required int recorded,
    NumberFormat? format,
  }) => _plural(
    'diaryMonthProgress',
    count,
    namedArgs: {'recorded': format?.format(recorded) ?? '$recorded'},
    format: format,
  );

  static String diaryDayCaption({
    required String weekday,
    required String day,
  }) => 'diaryDayCaption'.tr(namedArgs: {'weekday': weekday, 'day': day});

  static String diaryNoVideoOn({required String day}) =>
      'diaryNoVideoOn'.tr(namedArgs: {'day': day});

  static String get diaryNoVideoHint => 'diaryNoVideoHint'.tr();
  static String get viewerExitFullScreen => 'viewerExitFullScreen'.tr();
  static String get viewerPreviousDay => 'viewerPreviousDay'.tr();
  static String get viewerNextDay => 'viewerNextDay'.tr();

  static String viewerClipPosition({required int index, required int count}) =>
      'viewerClipPosition'.tr(
        namedArgs: {'index': '$index', 'count': '$count'},
      );

  /// [profile] is where the profile's chip goes in the sentence: pass
  /// `ProfileInlineText.marker` and show the text with that widget.
  static String deleteVideoBody({
    required String date,
    required String profile,
  }) => 'deleteVideoBody'.tr(namedArgs: {'date': date, 'profile': profile});

  /// As [deleteVideoBody], for a clip of a day of several.
  static String deleteClipBody({
    required String date,
    required String profile,
  }) => 'deleteClipBody'.tr(namedArgs: {'date': date, 'profile': profile});

  static String get deleteVideoFailed => 'deleteVideoFailed'.tr();
  static String get videoDeleted => 'videoDeleted'.tr();
  static String get diaryTodayEmptyTitle => 'diaryTodayEmptyTitle'.tr();
  static String get diaryTodayEmptyHint => 'diaryTodayEmptyHint'.tr();
  static String get diaryMonthEmptyTitle => 'diaryMonthEmptyTitle'.tr();
  static String get diaryMonthEmptyHint => 'diaryMonthEmptyHint'.tr();
  static String get memoriesEmptyTitle => 'memoriesEmptyTitle'.tr();
  static String get memoriesEmptyBody => 'memoriesEmptyBody'.tr();
  static String get memoriesEmptyCta => 'memoriesEmptyCta'.tr();
  static String get memoriesEnd => 'memoriesEnd'.tr();
  static String get a11yDayRecorded => 'a11yDayRecorded'.tr();
  static String get a11yDayMissed => 'a11yDayMissed'.tr();
  static String get a11yDayFuture => 'a11yDayFuture'.tr();

  /// The subtitle on a day of several clips: the clip's [place], then
  /// its [position] among them (`viewerClipPosition`).
  static String viewerPlaceAndPosition({
    required String place,
    required String position,
  }) => 'viewerPlaceAndPosition'.tr(
    namedArgs: {'place': place, 'position': position},
  );

  /// Under "Can't open your diary" (`storageUnavailableTitle`) when the
  /// diary's folder could not be read, over "Try again".
  static String get diaryUnreadableHint => 'diaryUnreadableHint'.tr();

  // Journey.

  static String get journeyDaysRecorded => 'journeyDaysRecorded'.tr();

  static String daysRecorded(int count, {NumberFormat? format}) =>
      _plural('daysRecorded', count, format: format);

  static String get journeyNoRecordingsYet => 'journeyNoRecordingsYet'.tr();
  static String get journeyStreak => 'journeyStreak'.tr();

  static String journeyThisMonthValue({
    required int recorded,
    required int total,
  }) => 'journeyThisMonthValue'.tr(
    namedArgs: {'recorded': '$recorded', 'total': '$total'},
  );

  /// "Your life so far" for screen readers: the units the tile draws short
  /// ("2 h", "15 min", "46 s") in words.
  static String journeyDurationHours(int count) =>
      _plural('journeyDurationHours', count);

  static String journeyDurationMinutes(int count) =>
      _plural('journeyDurationMinutes', count);

  static String journeyDurationSeconds(int count) =>
      _plural('journeyDurationSeconds', count);

  /// A duration's [larger] unit, then its [smaller] one ("15 minutes 14
  /// seconds").
  static String journeyDurationPair({
    required String larger,
    required String smaller,
  }) => 'journeyDurationPair'.tr(
    namedArgs: {'larger': larger, 'smaller': smaller},
  );

  static String get journeyCreateMovie => 'journeyCreateMovie'.tr();

  /// "312 clips available": [clips] is [clipCount].
  static String journeyClipsAvailable({required String clips}) =>
      'journeyClipsAvailable'.tr(namedArgs: {'clips': clips});

  static String get journeyStart => 'journeyStart'.tr();

  static String journeyMovieCount(int count, {NumberFormat? format}) =>
      _plural('journeyMovieCount', count, format: format);

  static String get journeyStats => 'journeyStats'.tr();
  static String get journeyGroupHabit => 'journeyGroupHabit'.tr();
  static String get journeyGroupTime => 'journeyGroupTime'.tr();
  static String get journeyGroupYourDiary => 'journeyGroupYourDiary'.tr();
  static String get journeyLongest => 'journeyLongest'.tr();
  static String get journeyFootage => 'journeyFootage'.tr();

  static String journeyDaysLeft(int count, {NumberFormat? format}) =>
      _plural('journeyDaysLeft', count, format: format);

  /// "Since your first clip (Jan 2025)": [month] is the first clip's month
  /// and year.
  static String journeySinceFirstClip({required String month}) =>
      'journeySinceFirstClip'.tr(namedArgs: {'month': month});

  static String journeyPlaceCount(int count, {NumberFormat? format}) =>
      _plural('journeyPlaceCount', count, format: format);

  static String get journeyAddPlaces => 'journeyAddPlaces'.tr();
  static String get journeyAddPlacesHint => 'journeyAddPlacesHint'.tr();
  static String get journeyPlacesNotOnMap => 'journeyPlacesNotOnMap'.tr();

  static String journeyPlacesAllIn({required String country}) =>
      'journeyPlacesAllIn'.tr(namedArgs: {'country': country});

  static String journeyPlacesInCountries(int count, {NumberFormat? format}) =>
      _plural('journeyPlacesInCountries', count, format: format);

  static String get journeyTapToSee => 'journeyTapToSee'.tr();
  static String get journeyTopTags => 'journeyTopTags'.tr();

  // Movies.

  static String get createMovieWhichDays => 'createMovieWhichDays'.tr();
  static String get chooseMonth => 'chooseMonth'.tr();
  static String get createMoviePickVideos => 'createMoviePickVideos'.tr();

  static String movieClipsFound(int count, {NumberFormat? format}) =>
      _plural('movieClipsFound', count, format: format);

  static String get movieNoClipsFound => 'movieNoClipsFound'.tr();

  /// [count] is the minimum number of clips for a movie.
  static String movieNeedMoreClips(int count, {NumberFormat? format}) =>
      _plural('movieNeedMoreClips', count, format: format);

  static String get monthNoClips => 'monthNoClips'.tr();
  static String get previousYear => 'previousYear'.tr();
  static String get nextYear => 'nextYear'.tr();
  static String get deselectAll => 'deselectAll'.tr();

  static String selectedCount(int count, {NumberFormat? format}) =>
      _plural('selectedCount', count, format: format);

  static String get noneSelected => 'noneSelected'.tr();
  static String get pickVideosEmptyTitle => 'pickVideosEmptyTitle'.tr();
  static String get pickVideosEmptyBody => 'pickVideosEmptyBody'.tr();

  static String clipUnavailableSemantics({required String date}) =>
      'clipUnavailableSemantics'.tr(namedArgs: {'date': date});

  static String pickVideosSectionWithProfile({
    required String month,
    required String profile,
  }) => 'pickVideosSectionWithProfile'.tr(
    namedArgs: {'month': month, 'profile': profile},
  );

  static String get newMovieTitle => 'newMovieTitle'.tr();

  /// [clips] is [clipCount]; [orientation] is [landscape] or [portrait].
  static String movieSummary({
    required String clips,
    required String profile,
    required String orientation,
  }) => 'movieSummary'.tr(
    namedArgs: {'clips': clips, 'profile': profile, 'orientation': orientation},
  );

  /// [days] lists the skipped days (at most 6) joined for the locale; more
  /// than 6 use [movieSkippedDaysCount].
  static String movieSkippedDays(
    int count, {
    required String days,
    NumberFormat? format,
  }) => _plural(
    'movieSkippedDays',
    count,
    namedArgs: {'days': days},
    format: format,
  );

  static String movieSkippedDaysCount(int count, {NumberFormat? format}) =>
      _plural('movieSkippedDaysCount', count, format: format);

  static String get movieHandPickedNote => 'movieHandPickedNote'.tr();

  static String get movieIncludePrivate => 'movieIncludePrivate'.tr();

  static String get movieIncludePrivateConfirmTitle =>
      'movieIncludePrivateConfirmTitle'.tr();

  static String movieIncludePrivateConfirmBody(
    int count, {
    NumberFormat? format,
  }) => _plural('movieIncludePrivateConfirmBody', count, format: format);

  static String get movieIncludePrivateConfirm =>
      'movieIncludePrivateConfirm'.tr();

  /// The private clips a range leaves out of the movie.
  static String moviePrivateLeftOut(int count, {NumberFormat? format}) =>
      _plural('moviePrivateLeftOut', count, format: format);

  /// The private clips a movie holds.
  static String moviePrivateIncluded(int count, {NumberFormat? format}) =>
      _plural('moviePrivateIncluded', count, format: format);

  /// What a movie with private clips says about itself in My movies.
  static String get movieHasPrivateClips => 'movieHasPrivateClips'.tr();

  static String movieTitleHandPicked(int count, {NumberFormat? format}) =>
      _plural('movieTitleHandPicked', count, format: format);

  static String movieNameWithProfile({
    required String profile,
    required String name,
  }) =>
      'movieNameWithProfile'.tr(namedArgs: {'profile': profile, 'name': name});

  static String movieEstimatedLength({required String duration}) =>
      'movieEstimatedLength'.tr(namedArgs: {'duration': duration});

  static String get makingMovieTitle => 'makingMovieTitle'.tr();

  /// "[done] / [count] clips": [count] clips in the movie, [done] processed.
  static String makingMovieOfTotal(
    int count, {
    required int done,
    NumberFormat? format,
  }) => _plural(
    'makingMovieOfTotal',
    count,
    namedArgs: {'done': format?.format(done) ?? '$done'},
    format: format,
  );

  static String get makingMovieWait => 'makingMovieWait'.tr();
  static String get makingMovieError => 'makingMovieError'.tr();

  static String makingMovieNoSpace({required String size}) =>
      'makingMovieNoSpace'.tr(namedArgs: {'size': size});

  static String get makingMovieCancelBody => 'makingMovieCancelBody'.tr();
  static String get makingMovieKeepGoing => 'makingMovieKeepGoing'.tr();
  static String get makingMovieStop => 'makingMovieStop'.tr();

  /// [percent] is already formatted; [count] clips in the movie, [done]
  /// processed.
  static String makingMovieProgressSemantics(
    int count, {
    required int done,
    required String percent,
    NumberFormat? format,
  }) => _plural(
    'makingMovieProgressSemantics',
    count,
    namedArgs: {'done': format?.format(done) ?? '$done', 'percent': percent},
    format: format,
  );

  static String get movieWatch => 'movieWatch'.tr();

  static String watchMovieNamed({required String name}) =>
      'watchMovieNamed'.tr(namedArgs: {'name': name});

  static String get myMoviesViewGrid => 'myMoviesViewGrid'.tr();
  static String get myMoviesViewLarge => 'myMoviesViewLarge'.tr();
  static String get myMoviesHelpTitle => 'myMoviesHelpTitle'.tr();
  static String get myMoviesHelpBody => 'myMoviesHelpBody'.tr();
  static String get myMoviesHelpPlayTitle => 'myMoviesHelpPlayTitle'.tr();
  static String get myMoviesHelpPlayBody => 'myMoviesHelpPlayBody'.tr();
  static String get myMoviesHelpSelectTitle => 'myMoviesHelpSelectTitle'.tr();
  static String get myMoviesHelpSelectBody => 'myMoviesHelpSelectBody'.tr();
  static String get myMoviesHelpViewTitle => 'myMoviesHelpViewTitle'.tr();
  static String get myMoviesHelpViewBody => 'myMoviesHelpViewBody'.tr();
  static String get myMoviesHelpProfileTitle => 'myMoviesHelpProfileTitle'.tr();
  static String get myMoviesHelpProfileBody => 'myMoviesHelpProfileBody'.tr();
  static String get myMoviesHelpCreateTitle => 'myMoviesHelpCreateTitle'.tr();
  static String get myMoviesHelpCreateBody => 'myMoviesHelpCreateBody'.tr();

  /// [clips] is [clipCount].
  static String movieItemSemantics({
    required String name,
    required String clips,
  }) => 'movieItemSemantics'.tr(namedArgs: {'name': name, 'clips': clips});

  static String get myMoviesEmptyBody => 'myMoviesEmptyBody'.tr();
  static String get movieFileMissing => 'movieFileMissing'.tr();
  static String get selectionClose => 'selectionClose'.tr();
  static String get deleteMovieTitle => 'deleteMovieTitle'.tr();

  /// For 2 or more movies; one movie uses [deleteMovieTitle].
  static String deleteMoviesTitle(int count, {NumberFormat? format}) =>
      _plural('deleteMoviesTitle', count, format: format);

  static String deleteMovieBody({required String name}) =>
      'deleteMovieBody'.tr(namedArgs: {'name': name});

  static String get deleteMoviesBody => 'deleteMoviesBody'.tr();
  static String get deleteMovieClipsSafe => 'deleteMovieClipsSafe'.tr();
  static String get movieDeleted => 'movieDeleted'.tr();

  /// For 2 or more movies; one movie uses [movieDeleted].
  static String moviesDeleted(int count, {NumberFormat? format}) =>
      _plural('moviesDeleted', count, format: format);

  static String get movieDeleteFailed => 'movieDeleteFailed'.tr();
  static String get renameMovieTitle => 'renameMovieTitle'.tr();
  static String get movieNameHint => 'movieNameHint'.tr();
  static String get movieNameEmptyError => 'movieNameEmptyError'.tr();
  static String get movieRenameFailed => 'movieRenameFailed'.tr();

  /// The profile sheet's title from the Create movie profile chip.
  static String get createMovieFromProfile => 'createMovieFromProfile'.tr();

  /// [name] is the profile's display name.
  static String movieProfileChipSemantics({required String name}) =>
      'movieProfileChipSemantics'.tr(namedArgs: {'name': name});

  /// A size in megabytes; [size] is already formatted.
  static String movieSizeMegabytes({required String size}) =>
      'movieSizeMegabytes'.tr(namedArgs: {'size': size});

  /// A size in gigabytes; [size] is already formatted.
  static String movieSizeGigabytes({required String size}) =>
      'movieSizeGigabytes'.tr(namedArgs: {'size': size});

  /// The error when the phone filled up during the movie and doesn't say
  /// how much is free (iOS); [makingMovieNoSpace] says how much to free.
  static String get makingMovieNoSpaceUnknown =>
      'makingMovieNoSpaceUnknown'.tr();

  /// [count] clips could not be read and are not in the movie: under
  /// [movieCreatedTitle], and with [movieInsufficientVideos] when too few
  /// were left to make one.
  static String movieSkippedClips(int count, {NumberFormat? format}) =>
      _plural('movieSkippedClips', count, format: format);
  static String moviePrivateClipsLeftOut(int count, {NumberFormat? format}) =>
      _plural('moviePrivateClipsLeftOut', count, format: format);

  /// A movie without a clip count (one made by an older install);
  /// [movieItemSemantics] has the count.
  static String movieItemSemanticsNoCount({required String name}) =>
      'movieItemSemanticsNoCount'.tr(namedArgs: {'name': name});

  /// What a long press on a movie does (a semantics hint; a tap plays it:
  /// [play]).
  static String get movieItemLongPressHint => 'movieItemLongPressHint'.tr();

  /// Shown when `Movies/` can't be read (storage access lost).
  static String get myMoviesLoadFailed => 'myMoviesLoadFailed'.tr();

  /// Under "Couldn't open your movies" (`myMoviesLoadFailed`), over "Try
  /// again".
  static String get myMoviesLoadFailedHint => 'myMoviesLoadFailedHint'.tr();

  // My movies: profile filter.

  /// The filter button and its sheet's title.
  static String get movieFilterByProfile => 'movieFilterByProfile'.tr();

  /// The choice that keeps the movies made by an older install, which name
  /// no profile.
  static String get movieFilterNoProfile => 'movieFilterNoProfile'.tr();

  /// The filter keeps no movie (Clear filter under it: [diaryFilterClear]).
  static String get movieFilterNoMatches => 'movieFilterNoMatches'.tr();

  /// "12 movies": a profile's count in the sheet, and the filter's under
  /// the bar.
  static String movieFilterMatches(int count, {NumberFormat? format}) =>
      _plural('movieFilterMatches', count, format: format);

  /// The movie player's seek bar (a slider, for screen readers).
  static String get moviePlayerSeek => 'moviePlayerSeek'.tr();

  // Movies: choose dates.

  static String get movieChooseDates => 'movieChooseDates'.tr();

  /// The "Choose dates" row's second line.
  static String get movieChooseDatesSubtitle => 'movieChooseDatesSubtitle'.tr();

  /// The first day's field.
  static String get movieDateFrom => 'movieDateFrom'.tr();

  /// The last day's field.
  static String get movieDateTo => 'movieDateTo'.tr();

  // Movies: transitions.

  /// The confirmation's "Transition" row.
  static String get movieTransition => 'movieTransition'.tr();

  static String get movieTransitionSheetTitle =>
      'movieTransitionSheetTitle'.tr();

  static String get movieTransitionNone => 'movieTransitionNone'.tr();
  static String get movieTransitionCrossfade => 'movieTransitionCrossfade'.tr();
  static String get movieTransitionFadeBlack => 'movieTransitionFadeBlack'.tr();
  static String get movieTransitionFadeWhite => 'movieTransitionFadeWhite'.tr();

  /// The "Also apply to older clips" switch row.
  static String get movieTransitionUpgradeOlder =>
      'movieTransitionUpgradeOlder'.tr();

  /// Under the switch, off: the clips that join with a hard cut.
  static String movieTransitionOlderClipsOff(
    int count, {
    NumberFormat? format,
  }) => _plural('movieTransitionOlderClipsOff', count, format: format);

  /// Under the switch, on: the clips re-encoded first.
  static String get clipMute => 'clipMute'.tr();
  static String get clipMuted => 'clipMuted'.tr();
  static String get clipMuteConfirmTitle => 'clipMuteConfirmTitle'.tr();
  static String get clipMuteConfirmBody => 'clipMuteConfirmBody'.tr();
  static String get clipMuteConfirm => 'clipMuteConfirm'.tr();
  static String get clipMutedDone => 'clipMutedDone'.tr();
  static String get clipMuteError => 'clipMuteError'.tr();
  static String get saveVideoMute => 'saveVideoMute'.tr();
  static String get saveVideoMuteHint => 'saveVideoMuteHint'.tr();
  static String get saveVideoZoom => 'saveVideoZoom'.tr();
  static String get saveVideoZoomHint => 'saveVideoZoomHint'.tr();
  static String get movieMusic => 'movieMusic'.tr();
  static String get movieMusicNone => 'movieMusicNone'.tr();
  static String movieMusicTracks(int count, {NumberFormat? format}) =>
      _plural('movieMusicTracks', count, format: format);
  static String movieMusicSummary({
    required String tracks,
    required String volume,
  }) => 'movieMusicSummary'.tr(namedArgs: {'tracks': tracks, 'volume': volume});
  static String get movieMusicSheetTitle => 'movieMusicSheetTitle'.tr();
  static String get movieMusicAddTracks => 'movieMusicAddTracks'.tr();
  static String get movieMusicLoopNote => 'movieMusicLoopNote'.tr();
  static String get movieMusicKeepClipSound => 'movieMusicKeepClipSound'.tr();
  static String get movieMusicKeepClipSoundOff =>
      'movieMusicKeepClipSoundOff'.tr();
  static String get movieMusicVolume => 'movieMusicVolume'.tr();
  static String movieMusicVolumePercent({required String percent}) =>
      'movieMusicVolumePercent'.tr(namedArgs: {'percent': percent});
  static String movieMusicRemoveTrack({required String name}) =>
      'movieMusicRemoveTrack'.tr(namedArgs: {'name': name});
  static String get movieMusicNoneAdded => 'movieMusicNoneAdded'.tr();
  static String get movieMusicOn => 'movieMusicOn'.tr();
  static String get movieMusicOff => 'movieMusicOff'.tr();
  static String get movieMusicTurnOff => 'movieMusicTurnOff'.tr();
  static String get movieMusicTurnOn => 'movieMusicTurnOn'.tr();
  static String get movieMusicSwapError => 'movieMusicSwapError'.tr();
  static String movieTransitionOlderClipsOn(
    int count, {
    NumberFormat? format,
  }) => _plural('movieTransitionOlderClipsOn', count, format: format);

  /// A field without a day yet.
  static String get movieDatePickDay => 'movieDatePickDay'.tr();

  /// Under the grid once the first day is picked.
  static String get movieDatePickEnd => 'movieDatePickEnd'.tr();

  // Settings.

  static String get settingsValueOff => 'settingsValueOff'.tr();
  static String get settingsValueBlocked => 'settingsValueBlocked'.tr();
  static String get backupTutorial => 'backupTutorial'.tr();

  /// The settings row that shares the app; other share actions use [share].
  static String get settingsShareWithFriend => 'settingsShareWithFriend'.tr();

  static String shareAppMessage({required String url}) =>
      'shareAppMessage'.tr(namedArgs: {'url': url});

  static String get sourceCode => 'sourceCode'.tr();
  static String get website => 'website'.tr();
  static String get notificationsChangeTime => 'notificationsChangeTime'.tr();
  static String get notificationsPersistentSubtitle =>
      'notificationsPersistentSubtitle'.tr();
  static String get notificationsPreview => 'notificationsPreview'.tr();

  static String notificationsTimeSemantics({required String time}) =>
      'notificationsTimeSemantics'.tr(namedArgs: {'time': time});

  static String get notificationsTimeSheetTitle =>
      'notificationsTimeSheetTitle'.tr();
  static String get notificationsBlockedTitle =>
      'notificationsBlockedTitle'.tr();
  static String get notificationsBlockedBody => 'notificationsBlockedBody'.tr();

  // The Android notification channel, in the phone's app notification
  // settings.
  static String get notificationsChannelName => 'notificationsChannelName'.tr();
  static String get notificationsChannelDescription =>
      'notificationsChannelDescription'.tr();
  static String get preferencesSectionRecording =>
      'preferencesSectionRecording'.tr();
  static String get preferencesRequiredOnThisAndroid =>
      'preferencesRequiredOnThisAndroid'.tr();
  static String get preferencesSectionGallery =>
      'preferencesSectionGallery'.tr();
  static String get preferencesFilterByDateSubtitle =>
      'preferencesFilterByDateSubtitle'.tr();
  static String get preferencesSectionAccessibility =>
      'preferencesSectionAccessibility'.tr();
  static String get preferencesAltCalendarColorsSubtitle =>
      'preferencesAltCalendarColorsSubtitle'.tr();
  static String get preferencesSaveFailed => 'preferencesSaveFailed'.tr();

  static String aboutCopyright({required String author, required int year}) =>
      'aboutCopyright'.tr(namedArgs: {'author': author, 'year': '$year'});

  static String get aboutChangelog => 'aboutChangelog'.tr();
  static String get thanksContributors => 'thanksContributors'.tr();
  static String get thanksTranslators => 'thanksTranslators'.tr();
  static String get aboutVersionCopied => 'aboutVersionCopied'.tr();
  static String get iosBackupWarning => 'iosBackupWarning'.tr();
  static String get supportHeadline => 'supportHeadline'.tr();
  static String get supportBody => 'supportBody'.tr();
  static String get supportBuyCoffee => 'supportBuyCoffee'.tr();
  static String get supportGithubSponsor => 'supportGithubSponsor'.tr();
  static String get contactTitle => 'contactTitle'.tr();
  static String get contactSubtitle => 'contactSubtitle'.tr();
  static String get contactBugTitle => 'contactBugTitle'.tr();
  static String get contactBugSubtitle => 'contactBugSubtitle'.tr();
  static String get contactIdeaTitle => 'contactIdeaTitle'.tr();
  static String get contactIdeaSubtitle => 'contactIdeaSubtitle'.tr();

  static String get contactLogsUnavailable => 'contactLogsUnavailable'.tr();
  static String get contactPreparingLogs => 'contactPreparingLogs'.tr();
  static String get contactNoEmailAppTitle => 'contactNoEmailAppTitle'.tr();

  static String contactNoEmailAppBody({required String address}) =>
      'contactNoEmailAppBody'.tr(namedArgs: {'address': address});

  static String get contactCopyAddress => 'contactCopyAddress'.tr();

  /// The "Preferences" row in a language whose `preferences` repeats its
  /// word for "Settings" (de, ru): see `SettingsLabels.preferences`.
  static String get settingsPreferencesDistinct =>
      'settingsPreferencesDistinct'.tr();

  /// A Changelog section: [version] is [appVersion]'s text, [date] the
  /// release month formatted by the caller ("September 2026").
  static String changelogReleaseTitle({
    required String version,
    required String date,
  }) =>
      'changelogReleaseTitle'.tr(namedArgs: {'version': version, 'date': date});

  /// The Changelog or Special thanks page when its bundled file can't be
  /// read.
  static String get aboutDocumentUnavailable => 'aboutDocumentUnavailable'.tr();

  // Profiles.

  static String get profilesHintLongPress => 'profilesHintLongPress'.tr();
  static String get profilesHelpTitle => 'profilesHelpTitle'.tr();
  static String get profilesHelpBody => 'profilesHelpBody'.tr();
  static String get profilesHelpActivateBody => 'profilesHelpActivateBody'.tr();
  static String get profilesHelpEditBody => 'profilesHelpEditBody'.tr();
  static String get profilesActiveBadge => 'profilesActiveBadge'.tr();

  static String profileActivated({required String name}) =>
      'profileActivated'.tr(namedArgs: {'name': name});

  static String get profilesActivateFailed => 'profilesActivateFailed'.tr();
  static String get profilesFoundOnPhone => 'profilesFoundOnPhone'.tr();
  static String get profilesFoundOnPhoneHint => 'profilesFoundOnPhoneHint'.tr();
  static String get profilesAddBack => 'profilesAddBack'.tr();
  static String get profileEditTitle => 'profileEditTitle'.tr();
  static String get profileChangePhoto => 'profileChangePhoto'.tr();
  static String get profileAddPhoto => 'profileAddPhoto'.tr();
  static String get profileAddPhotoOptional => 'profileAddPhotoOptional'.tr();
  static String get profileOrientationLocked => 'profileOrientationLocked'.tr();

  static String profileDeleteDialogTitle({required String name}) =>
      'profileDeleteDialogTitle'.tr(namedArgs: {'name': name});

  static String get profileDeleted => 'profileDeleted'.tr();
  static String get profileSaveFailed => 'profileSaveFailed'.tr();
  static String get profilePhotoTitle => 'profilePhotoTitle'.tr();
  static String get profilePhotoChoose => 'profilePhotoChoose'.tr();
  static String get profilePhotoTake => 'profilePhotoTake'.tr();
  static String get profilePhotoRemove => 'profilePhotoRemove'.tr();
  static String get profileOrientationHint => 'profileOrientationHint'.tr();
  static String get profileDeleteFailed => 'profileDeleteFailed'.tr();

  /// The sub-line of [profileDeleted] when the phone kept [count] of the
  /// profile's clips (Android asks before deleting a previous install's).
  static String profileDeletedKeptVideos(int count, {NumberFormat? format}) =>
      _plural('profileDeletedKeptVideos', count, format: format);

  // Places.

  /// Settings › Places, and its row.
  static String get places => 'places'.tr();

  /// The caption of the saved chips in the place sheet.
  static String get savedPlaces => 'savedPlaces'.tr();

  /// The caption of the recent chips in the place sheet.
  static String get recentPlaces => 'recentPlaces'.tr();

  /// "Save this place", in the place sheet.
  static String get savePlace => 'savePlace'.tr();

  static String get placeSaved => 'placeSaved'.tr();

  /// "3 places": the Settings row's count.
  static String placeCount(int count, {NumberFormat? format}) =>
      _plural('placeCount', count, format: format);

  static String get placesNoneYet => 'placesNoneYet'.tr();

  static String get managePlacesDescription => 'managePlacesDescription'.tr();

  static String get addPlace => 'addPlace'.tr();

  static String get editPlace => 'editPlace'.tr();

  /// The hint of the name field of the place sheet.
  static String get placeName => 'placeName'.tr();

  static String get placeUseCurrentLocation => 'placeUseCurrentLocation'.tr();

  static String get placeNoCoordinates => 'placeNoCoordinates'.tr();

  static String get placeRemoveCoordinates => 'placeRemoveCoordinates'.tr();

  /// "Use current location" found no fix.
  static String get placeLocationUnavailable => 'placeLocationUnavailable'.tr();

  static String get placeErrorEmpty => 'placeErrorEmpty'.tr();

  static String placeErrorTooLong({required int max}) =>
      'placeErrorTooLong'.tr(namedArgs: {'max': '$max'});

  static String get placeErrorDuplicate => 'placeErrorDuplicate'.tr();

  static String get removePlace => 'removePlace'.tr();

  static String removePlaceTitle({required String place}) =>
      'removePlaceTitle'.tr(namedArgs: {'place': place});

  static String get removePlaceBody => 'removePlaceBody'.tr();

  /// "Used 3 times": how often a saved place was picked.
  static String placeUses(int count, {NumberFormat? format}) =>
      _plural('placeUses', count, format: format);

  static String get quality => 'quality'.tr();
  static String get qualitySheetTitle => 'qualitySheetTitle'.tr();
  static String get qualityPresetStandard => 'qualityPresetStandard'.tr();
  static String get qualityPresetStandardPitch =>
      'qualityPresetStandardPitch'.tr();
  static String get qualityPresetSmallerFiles =>
      'qualityPresetSmallerFiles'.tr();
  static String get qualityPresetSmallerFilesPitch =>
      'qualityPresetSmallerFilesPitch'.tr();
  static String get qualityPresetHigh => 'qualityPresetHigh'.tr();
  static String get qualityPresetHighPitch => 'qualityPresetHighPitch'.tr();
  static String get qualityPresetUltra => 'qualityPresetUltra'.tr();
  static String get qualityPresetUltraPitch => 'qualityPresetUltraPitch'.tr();
  static String get qualityAdvanced => 'qualityAdvanced'.tr();
  static String get qualityResolution => 'qualityResolution'.tr();
  static String get qualityCodec => 'qualityCodec'.tr();
  static String get qualityFrameRate => 'qualityFrameRate'.tr();
  static String get qualityAudio => 'qualityAudio'.tr();
  static String get qualityDynamicRange => 'qualityDynamicRange'.tr();
  static String get qualityTier720 => 'qualityTier720'.tr();
  static String get qualityTier1080 => 'qualityTier1080'.tr();
  static String get qualityTier1440 => 'qualityTier1440'.tr();
  static String get qualityTier2160 => 'qualityTier2160'.tr();
  static String get qualityCodecH264 => 'qualityCodecH264'.tr();
  static String get qualityCodecHevc => 'qualityCodecHevc'.tr();
  static String qualityFps({required String fps}) =>
      'qualityFps'.tr(namedArgs: {'fps': fps});
  static String get qualityMono => 'qualityMono'.tr();
  static String get qualityStereo => 'qualityStereo'.tr();
  static String get qualitySdr => 'qualitySdr'.tr();
  static String get qualityHlg => 'qualityHlg'.tr();
  static String get qualityHdrForImports => 'qualityHdrForImports'.tr();

  /// "4K 60 fps · HEVC · Stereo": [tier] is a `qualityTier…`, [fps] is
  /// [qualityFps], [codec] and [audio] their labels.
  static String qualityFormatSummary({
    required String tier,
    required String fps,
    required String codec,
    required String audio,
  }) => 'qualityFormatSummary'.tr(
    namedArgs: {'tier': tier, 'fps': fps, 'codec': codec, 'audio': audio},
  );

  /// "4K 30 fps · HEVC · Stereo · HDR (HLG)": [summary] is
  /// [qualityFormatSummary], [range] is [qualityHlg].
  static String qualityFormatSummaryHdr({
    required String summary,
    required String range,
  }) => 'qualityFormatSummaryHdr'.tr(
    namedArgs: {'summary': summary, 'range': range},
  );

  /// The per-choice speed line of the quality picker.
  static String qualitySaveTime({required String seconds}) =>
      'qualitySaveTime'.tr(namedArgs: {'seconds': seconds});

  static String get qualityNotSupported => 'qualityNotSupported'.tr();
  static String get qualitySlow => 'qualitySlow'.tr();
  static String get qualityRecommended => 'qualityRecommended'.tr();

  /// "Your phone encodes 4K 60 at 2.4× real time and has 480 GB free".
  static String qualityRecommendationReason({
    required String format,
    required String factor,
    required String free,
  }) => 'qualityRecommendationReason'.tr(
    namedArgs: {'format': format, 'factor': factor, 'free': free},
  );

  /// "Ultra is 4K 30 fps on this phone".
  static String qualityPresetDemoted({
    required String preset,
    required String format,
  }) => 'qualityPresetDemoted'.tr(
    namedArgs: {'preset': preset, 'format': format},
  );

  static String get qualityNotChecked => 'qualityNotChecked'.tr();
  static String get qualityFixed => 'qualityFixed'.tr();

  /// The quality sheet's button.
  static String get qualityUse => 'qualityUse'.tr();

  /// The editor's note when the camera recorded below the profile's tier.
  static String recordedAt({required String tier}) =>
      'recordedAt'.tr(namedArgs: {'tier': tier});

  static String get convertIntoNewProfile => 'convertIntoNewProfile'.tr();
  static String get convertProfileTitle => 'convertProfileTitle'.tr();
  static String get convertProfileName => 'convertProfileName'.tr();
  static String convertProfileDefaultName({
    required String name,
    required String quality,
  }) => 'convertProfileDefaultName'.tr(
    namedArgs: {'name': name, 'quality': quality},
  );

  /// [clips] is [clipCount]; the rest already formatted.
  static String convertProfileEstimate({
    required String clips,
    required String length,
    required String time,
    required String space,
  }) => 'convertProfileEstimate'.tr(
    namedArgs: {'clips': clips, 'length': length, 'time': time, 'space': space},
  );

  static String get convertProfileStart => 'convertProfileStart'.tr();
  static String convertProfileProgress({
    required String done,
    required String total,
    required String remaining,
  }) => 'convertProfileProgress'.tr(
    namedArgs: {'done': done, 'total': total, 'remaining': remaining},
  );
  static String get convertProfileKeepOpen => 'convertProfileKeepOpen'.tr();
  static String convertProfileDone({required String name}) =>
      'convertProfileDone'.tr(namedArgs: {'name': name});
  static String convertProfileCancelled({required String name}) =>
      'convertProfileCancelled'.tr(namedArgs: {'name': name});
  static String get convertProfileResume => 'convertProfileResume'.tr();
  static String get convertProfileSameQuality =>
      'convertProfileSameQuality'.tr();

  /// The estimate card while the converter computes it.
  static String get convertProfileEstimating => 'convertProfileEstimating'.tr();
  static String get convertProfileNoSources => 'convertProfileNoSources'.tr();

  /// The refusal before a save, movie, conversion or check: [amount] is
  /// the shortfall, formatted ("1.2 GB").
  static String storageShort({required String amount}) =>
      'storageShort'.tr(namedArgs: {'amount': amount});

  static String storageNeeded({required String needed, required String free}) =>
      'storageNeeded'.tr(namedArgs: {'needed': needed, 'free': free});

  static String get whatsNewQualityTitle => 'whatsNewQualityTitle'.tr();
  static String get whatsNewQualityBody => 'whatsNewQualityBody'.tr();
  static String get whatsNewQualityConvert => 'whatsNewQualityConvert'.tr();

  static String get phoneCheckTitle => 'phoneCheckTitle'.tr();
  static String get phoneCheckBody => 'phoneCheckBody'.tr();
  static String phoneCheckTestEncode({required String format}) =>
      'phoneCheckTestEncode'.tr(namedArgs: {'format': format});
  static String get phoneCheckTestDecode => 'phoneCheckTestDecode'.tr();
  static String get phoneCheckTestCamera => 'phoneCheckTestCamera'.tr();
  static String get phoneCheckTestStorage => 'phoneCheckTestStorage'.tr();
  static String phoneCheckProgress({
    required String done,
    required String total,
  }) => 'phoneCheckProgress'.tr(namedArgs: {'done': done, 'total': total});
  static String get phoneCheckResultTitle => 'phoneCheckResultTitle'.tr();
  static String get phoneCheckUseThis => 'phoneCheckUseThis'.tr();
  static String get phoneCheckChooseAnother => 'phoneCheckChooseAnother'.tr();
  static String get phoneCheckSkip => 'phoneCheckSkip'.tr();
  static String get phoneCheckSkipped => 'phoneCheckSkipped'.tr();
  static String get phoneCheckFailed => 'phoneCheckFailed'.tr();
  static String get phoneCheckBenchmark => 'phoneCheckBenchmark'.tr();
  static String get phoneCheckBenchmarkDescription =>
      'phoneCheckBenchmarkDescription'.tr();
  static String get phoneCheckRunAgain => 'phoneCheckRunAgain'.tr();
  static String get phoneCheckStale => 'phoneCheckStale'.tr();
  static String phoneCheckLastRun({required String date}) =>
      'phoneCheckLastRun'.tr(namedArgs: {'date': date});
  static String get onboardingContinue => 'onboardingContinue'.tr();

  static String get backupRestore => 'backupRestore'.tr();
  static String get backupChoiceTitle => 'backupChoiceTitle'.tr();
  static String get backupChoiceSave => 'backupChoiceSave'.tr();
  static String get backupChoiceBringIn => 'backupChoiceBringIn'.tr();

  /// [path] is the real folder of this phone (`AppPaths.videos`), never
  /// a hardcoded string.
  static String backupAndroidStep1({required String path}) =>
      'backupAndroidStep1'.tr(namedArgs: {'path': path});

  static String get backupAndroidStep2 => 'backupAndroidStep2'.tr();
  static String get backupAndroidStep3 => 'backupAndroidStep3'.tr();
  static String get backupAndroidStep4 => 'backupAndroidStep4'.tr();
  static String get backupAndroidStep5 => 'backupAndroidStep5'.tr();
  static String get backupIosStep1 => 'backupIosStep1'.tr();
  static String get backupIosStep2 => 'backupIosStep2'.tr();
  static String get backupIosStep3 => 'backupIosStep3'.tr();
  static String get backupIosStep4 => 'backupIosStep4'.tr();

  /// [path] as in [backupAndroidStep1].
  static String importAndroidStep1({required String path}) =>
      'importAndroidStep1'.tr(namedArgs: {'path': path});

  static String get importStepDateNamed => 'importStepDateNamed'.tr();
  static String get importStepLook => 'importStepLook'.tr();
  static String get importStepProcessed => 'importStepProcessed'.tr();
  static String get importIosStep1 => 'importIosStep1'.tr();
  static String get importIosStep3 => 'importIosStep3'.tr();
  static String get backupOpenInFiles => 'backupOpenInFiles'.tr();
  static String get backupOpenInFilesFallback =>
      'backupOpenInFilesFallback'.tr();
  static String get backupCopyPath => 'backupCopyPath'.tr();
  static String get backupPathCopied => 'backupPathCopied'.tr();
  static String get backupLookForNewVideos => 'backupLookForNewVideos'.tr();
  static String get backupLooking => 'backupLooking'.tr();
  static String backupFoundClips(int count, {NumberFormat? format}) =>
      _plural('backupFoundClips', count, format: format);
  static String backupNothingNew({required String folder}) =>
      'backupNothingNew'.tr(namedArgs: {'folder': folder});
  static String get backupWatchVideo => 'backupWatchVideo'.tr();
  static String get backupOriginalsNote => 'backupOriginalsNote'.tr();

  static String get clipImported => 'clipImported'.tr();
  static String importedVideoCount(int count, {NumberFormat? format}) =>
      _plural('importedVideoCount', count, format: format);

  /// The prompt after a scan: [videos] is [importedVideoCount].
  static String importedVideosProcess({required String videos}) =>
      'importedVideosProcess'.tr(namedArgs: {'videos': videos});

  static String get processImport => 'processImport'.tr();

  /// The row of a clip's action sheet that opens a foreign clip in the
  /// editor to process it by hand.
  static String get clipProcessImport => 'clipProcessImport'.tr();
  static String get processImportsTitle => 'processImportsTitle'.tr();

  /// One row of the processing sheet: [videos] is [importedVideoCount],
  /// [length] the total length formatted.
  static String processImportsProfile({
    required String profile,
    required String videos,
    required String length,
  }) => 'processImportsProfile'.tr(
    namedArgs: {'profile': profile, 'videos': videos, 'length': length},
  );

  static String get processImportsLength => 'processImportsLength'.tr();

  /// [length] is the remembered quick cut, formatted ("1.5 s").
  static String processImportsKeepFirst({required String length}) =>
      'processImportsKeepFirst'.tr(namedArgs: {'length': length});

  static String get processImportsKeepWhole => 'processImportsKeepWhole'.tr();
  static String get processImportsDateStamp => 'processImportsDateStamp'.tr();
  static String processImportsStart(int count, {NumberFormat? format}) =>
      _plural('processImportsStart', count, format: format);
  static String processImportsProgress({
    required String done,
    required String total,
  }) => 'processImportsProgress'.tr(namedArgs: {'done': done, 'total': total});
  static String processImportsDone(int count, {NumberFormat? format}) =>
      _plural('processImportsDone', count, format: format);
  static String processImportsSkipped(int count, {NumberFormat? format}) =>
      _plural('processImportsSkipped', count, format: format);
  static String get processImportsMoveRefused =>
      'processImportsMoveRefused'.tr();

  /// The movie confirmation's line when foreign clips need converting.
  static String movieImportedWillConvert(
    int count, {
    required String time,
    NumberFormat? format,
  }) => _plural(
    'movieImportedWillConvert',
    count,
    namedArgs: {'time': time},
    format: format,
  );

  static String get movieProcessNow => 'movieProcessNow'.tr();

  /// "12 min · 365 clips": [clips] is [clipCount].
  static String movieLengthAndClips({
    required String length,
    required String clips,
  }) => 'movieLengthAndClips'.tr(namedArgs: {'length': length, 'clips': clips});

  static String originalsSize({required String size}) =>
      'originalsSize'.tr(namedArgs: {'size': size});
  static String get deleteOriginals => 'deleteOriginals'.tr();
  static String get deleteOriginalsTitle => 'deleteOriginalsTitle'.tr();
  static String deleteOriginalsBody({required String size}) =>
      'deleteOriginalsBody'.tr(namedArgs: {'size': size});

  /// Settings › Preferences, the "Original videos" group: kept
  /// recordings and processed imports' originals.
  static String get originalVideosSection => 'originalVideosSection'.tr();

  /// "3 videos · 850 MB".
  static String originalVideosCount(
    int count, {
    required String size,
    NumberFormat? format,
  }) => _plural(
    'originalVideosCount',
    count,
    namedArgs: {'size': size},
    format: format,
  );
  static String get originalVideosNone => 'originalVideosNone'.tr();
  static String get originalVideosDescription =>
      'originalVideosDescription'.tr();

  /// The warning before "Delete originals" in Preferences: exactly what
  /// deleting means.
  static String deleteOriginalsWarning(
    int count, {
    required String size,
    NumberFormat? format,
  }) => _plural(
    'deleteOriginalsWarning',
    count,
    namedArgs: {'size': size},
    format: format,
  );
  static String get keepOriginals => 'keepOriginals'.tr();
  static String get keepOriginalsDescription => 'keepOriginalsDescription'.tr();

  /// Under the switch, from the format's capture bitrate.
  static String keepOriginalsPerRecording({required String size}) =>
      'keepOriginalsPerRecording'.tr(namedArgs: {'size': size});

  static String get editAgain => 'editAgain'.tr();

  static String get framingSheetTitle => 'framingSheetTitle'.tr();
  static String get framingFill => 'framingFill'.tr();
  static String get framingFillBlack => 'framingFillBlack'.tr();
  static String get framingFillBlur => 'framingFillBlur'.tr();
  static String get framingFit => 'framingFit'.tr();
  static String get framingCover => 'framingCover'.tr();

  /// The zoom slider's mark up to which the clip loses no detail.
  static String get framingLossless => 'framingLossless'.tr();

  static String get framingHint => 'framingHint'.tr();

  /// "1.5 s": [seconds] already formatted.
  static String secondsValue({required String seconds}) =>
      'secondsValue'.tr(namedArgs: {'seconds': seconds});

  /// The processing and conversion sheets' "Stop" while a run goes on.
  static String get processImportsStop => 'processImportsStop'.tr();

  /// A place's clips: opens the Diary on the clip's day.
  static String get placeClipsOpenDay => 'placeClipsOpenDay'.tr();
}

/// The plural [key] for [count] in the current language, with `{count}`
/// filled in (formatted by [format] when given).
///
/// A language that has no translation of [key] yet shows the English text,
/// and then English plural rules pick the form: left to easy_localization,
/// the current language's rules would pick it, giving "1 clips" in zh (only
/// `other`), "21 clip" in ru and "0 clip" in fr.
///
/// A language has translated [key] when it has any form of it: a complete
/// Russian translation may have only `one`, `few` and `many`, since CLDR
/// keeps `other` for fractions. It probes the forms because `trExists` on
/// the plural key itself throws in easy_localization 3.0.8 (it reads the
/// forms map as a `String`).
///
/// A [count] shown with a fraction ("1.5", "0.64") takes the form CLDR
/// gives the digits shown ([_fractionForm]): "1.5 seconds", never the "one"
/// of a rounded 1.
String _plural(
  String key,
  num count, {
  Map<String, String> namedArgs = const {},
  NumberFormat? format,
}) {
  final String shown = format?.format(count) ?? '$count';
  final int fractionDigits = _fractionDigits(shown, format);
  final bool translated = _pluralForms.any(
    (String form) => '$key.$form'.trExists(),
  );
  if (translated && fractionDigits == 0) {
    return key.plural(
      count,
      name: 'count',
      namedArgs: namedArgs,
      format: format,
    );
  }
  final String form = translated
      ? _fractionForm(key, count, fractionDigits)
      : (count == 1 && fractionDigits == 0 ? 'one' : 'other');
  return '$key.$form'.tr(namedArgs: {...namedArgs, 'count': shown});
}

/// The form a translated [key] takes for [count] shown with
/// [fractionDigits] decimals, by the app language's CLDR rules
/// (`Intl.defaultLocale`, which `OsdLocalization.applyToIntl` keeps as the
/// app language). easy_localization rounds a fraction first, so 1.2 would
/// take English "one" ("1.2 second") and Czech 1,5 the "few" of 2. A form
/// the translation lacks falls back to `other`, as easy_localization's own.
String _fractionForm(String key, num count, int fractionDigits) {
  final String form = Intl.pluralLogic<String>(
    count,
    locale: Intl.defaultLocale,
    precision: fractionDigits,
    zero: 'zero',
    one: 'one',
    two: 'two',
    few: 'few',
    many: 'many',
    other: 'other',
  );
  return '$key.$form'.trExists() ? form : 'other';
}

/// CLDR's `v`: how many fraction digits [shown] has after [format]'s
/// decimal separator ("1.5": 1, "0.64": 2, "2": 0).
int _fractionDigits(String shown, NumberFormat? format) {
  final String separator = format?.symbols.DECIMAL_SEP ?? '.';
  final int at = shown.lastIndexOf(separator);
  if (at < 0) return 0;
  return _leadingDigits
      .stringMatch(shown.substring(at + separator.length))!
      .length;
}

final RegExp _leadingDigits = RegExp('^[0-9]*');

/// The CLDR plural categories, the forms a plural key can have.
const List<String> _pluralForms = [
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
];
