import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// Mounts [child] under the app's own localisation root,
/// [OsdLocalizationRoot] (so these tests pin its settings:
/// `ignorePluralRules`, `saveLocale` and the rest), around a [MaterialApp]
/// that takes its locale and delegates from it, as the app's does.
///
/// [startLocale] must be an app language. [assetLoader] defaults to the
/// real asset bundle; pass an in-memory loader to test with translations
/// that are not in the app (plural keys).
class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({
    super.key,
    required this.startLocale,
    required this.child,
    this.assetLoader = const RootBundleAssetLoader(),
  });

  final Locale startLocale;
  final AssetLoader assetLoader;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OsdLocalizationRoot(
      language: AppLanguage.values.byName(startLocale.languageCode),
      assetLoader: assetLoader,
      child: _LocalizedMaterialApp(child: child),
    );
  }
}

class _LocalizedMaterialApp extends StatelessWidget {
  const _LocalizedMaterialApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: Material(child: child),
    );
  }
}
