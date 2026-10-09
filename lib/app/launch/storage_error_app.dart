import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/launch/storage_error_page.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/app/osd_material_app.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// The app when `AppPaths.resolve()` fails at launch (an Android device
/// without a storage root): only [StorageErrorPage], localised and themed,
/// with no services behind it. Its router has that one page.
class StorageErrorApp extends StatefulWidget {
  const StorageErrorApp({
    super.key,
    required this.language,
    required this.darkMode,
    required this.legacyVideosPath,
  });

  final AppLanguage language;
  final bool darkMode;
  final String? legacyVideosPath;

  @override
  State<StorageErrorApp> createState() => _StorageErrorAppState();
}

class _StorageErrorAppState extends State<StorageErrorApp> {
  late final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            StorageErrorPage(legacyVideosPath: widget.legacyVideosPath),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OsdLocalizationRoot(
      language: widget.language,
      child: OsdMaterialApp(darkMode: widget.darkMode, routerConfig: _router),
    );
  }
}
