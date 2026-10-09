import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/app/launch/launch_app.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_environment.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/app/launch/storage_error_app.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/global_error_handlers.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../support/support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Key appKey = Key('app');

  late List<String> journal;
  late AppPaths paths;
  late FakeClock clock;
  late FakeGateways gateways;
  late List<String> console;
  late List<GlobalErrorHandlers> errorHandlers;
  Widget? app;

  setUp(() async {
    await sl.reset();
    journal = <String>[];
    paths = AppPaths.forTest(await createTempRoot());
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    gateways = FakeGateways(clock: clock, paths: paths);
    console = <String>[];
    errorHandlers = <GlobalErrorHandlers>[];
    app = null;
  });

  tearDown(() async {
    await sl.reset();
    await gateways.close();
    rootBundle.clear();
  });

  LaunchEnvironment environment({
    Map<String, Object> prefs = freshInstallPrefs,
    bool platformIsDark = true,
    Object? pathsError,
    Object? documentsError,
    String deviceLanguage = 'en',
  }) => LaunchEnvironment(
    clock: clock,
    isAndroid: false,
    isIOS: false,
    openPrefs: () async {
      journal.add('prefs');
      return openLegacyPrefs(prefs);
    },
    resolvePaths: () async {
      journal.add('paths');
      if (pathsError != null) throw pathsError;
      return paths;
    },
    documentsPath: () async {
      if (documentsError != null) throw documentsError;
      return '/private/documents';
    },
    platformIsDark: () => platformIsDark,
    deviceLanguageCode: () => deviceLanguage,
    installErrorHandlers: (GlobalErrorHandlers handlers) {
      journal.add('error handlers');
      errorHandlers.add(handlers);
    },
    loadDateSymbols: () async => journal.add('date symbols'),
    loadTranslations: () async => journal.add('translations'),
    printLog: console.add,
    lockPortrait: () async => journal.add('portrait'),
  );

  Future<void> launch(LaunchEnvironment environment) => launchApp(
    environment: environment,
    buildApp: () => const SizedBox(key: appKey),
    runApp: (Widget widget) => app = widget,
    overrides: gateways.register,
  );

  group('before the first frame', () {
    test('only the portrait lock, the preferences, the folders and the log '
        'file are touched', () async {
      await launch(environment(platformIsDark: false));

      // Portrait first.
      expect(journal, <String>[
        'portrait',
        'prefs',
        'paths',
        'error handlers',
        'date symbols',
        'translations',
      ]);
      expect(gateways.untouched, isTrue);
      expect(
        Directory(paths.logsDir).listSync().single.path,
        endsWith('/2024-01-05_10-00-00.txt'),
      );
      // A fresh install follows the phone once, and the schema version is
      // recorded; nothing else is written.
      final SharedPreferences stored = await SharedPreferences.getInstance();
      expect(stored.getKeys(), <String>{'isDarkMode', 'osdSchemaVersion'});
      expect(stored.getBool('isDarkMode'), isFalse);
      expect(Directory(paths.videos).existsSync(), isFalse);
      expect((app! as SizedBox).key, appKey);
      // The rest starts from the widget tree (LaunchStarter), not here.
      expect(sl.isRegistered<LaunchCubit>(), isTrue);
      expect(sl.checkLazySingletonInstanceExists<LaunchCubit>(), isFalse);
      expect(sl.checkLazySingletonInstanceExists<PostFrameLaunch>(), isFalse);
    });
  });

  group('without a storage root', () {
    test('only the storage error state shows, and nothing else '
        'starts', () async {
      await launch(
        environment(pathsError: const StorageException('No storage root')),
      );

      expect(
        app,
        isA<StorageErrorApp>().having(
          (StorageErrorApp app) => app.legacyVideosPath,
          'legacyVideosPath',
          '/private/documents/DCIM/OneSecondDiary/',
        ),
      );
      expect(journal, <String>['portrait', 'prefs', 'paths', 'translations']);
      expect(sl.isRegistered<AppLogger>(), isFalse);
      expect(gateways.untouched, isTrue);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });

    test('names no folder when the private one is unknown too', () async {
      await launch(
        environment(
          pathsError: const StorageException('No storage root'),
          documentsError: const StorageException('path_provider failed'),
        ),
      );

      expect((app! as StorageErrorApp).legacyVideosPath, isNull);
    });
  });

  // intl formats in the app language, never in the phone's raw locale
  // (EasyLocalization.ensureInitialized puts that in Intl.systemLocale).
  group('intl', () {
    late String systemLocale;

    setUp(() {
      systemLocale = Intl.systemLocale;
      // What findSystemLocale leaves on a Javanese phone: a locale intl has
      // no data for.
      Intl.systemLocale = 'jv_ID';
      Intl.defaultLocale = null;
    });

    tearDown(() {
      Intl.systemLocale = systemLocale;
      Intl.defaultLocale = null;
    });

    test('uses the app language, English on a phone in a language the app '
        'has not got', () async {
      await launch(environment(prefs: legacyPrefs(), deviceLanguage: 'jv'));

      expect(Intl.getCurrentLocale(), 'en');
    });

    test('uses the language the user picked', () async {
      await launch(
        environment(
          prefs: legacyPrefs(extra: <String, Object>{'lang': 'de'}),
          deviceLanguage: 'jv',
        ),
      );

      expect(Intl.getCurrentLocale(), 'de');
    });

    test('uses the app language in the storage error state too', () async {
      await launch(
        environment(
          pathsError: const StorageException('No storage root'),
          deviceLanguage: 'pt',
        ),
      );

      expect(Intl.getCurrentLocale(), 'pt');
    });
  });

  group('the log', () {
    test("catches uncaught errors in this launch's file", () async {
      await launch(environment());

      errorHandlers.single.onPlatformError(
        StateError('boom'),
        StackTrace.empty,
      );
      await sl<AppLogger>().flush();

      expect(
        File('${paths.logsDir}/2024-01-05_10-00-00.txt').readAsStringSync(),
        contains(
          '[ERROR] 2024-01-05 10:00:00.000: [UNCAUGHT] Uncaught asynchronous '
          'error\nError: Bad state: boom',
        ),
      );
    });

    test('goes to the console when its file cannot be created, and the '
        'launch goes on', () async {
      File(paths.logsDir).createSync(recursive: true);

      await launch(environment(prefs: legacyPrefs()));
      await sl<LaunchCubit>().start();
      await sl<MediaEngine>().init();

      expect(
        console.first,
        startsWith(
          '[ERROR] 2024-01-05 10:00:00.000: [LOGS] Could not create the log '
          'file; logging to the console',
        ),
      );
      expect(sl<LaunchCubit>().state.status, LaunchStatus.ready);
      final SharedPreferences stored = await SharedPreferences.getInstance();
      expect(stored.containsKey('currentLogFile'), isFalse);
      expect(stored.getString('appPath'), paths.videos);
    });
  });

  group('after the first frame', () {
    /// Starts the launch as the app's first page does (LaunchStarter), and
    /// waits for it.
    Future<void> firstFrame() async {
      await sl<LaunchCubit>().start();
      // Started without waiting by the launch; memoised.
      await sl<MediaEngine>().init();
    }

    test('the launch runs through the real services', () async {
      await launch(environment(prefs: legacyPrefs()));

      await firstFrame();

      final SharedPreferences stored = await SharedPreferences.getInstance();
      expect(stored.getString('currentLogFile'), '2024-01-05_10-00-00.txt');
      expect(stored.getString('appPath'), paths.videos);
      expect(stored.getInt('sdkVersion'), 34);
      expect(sl<LaunchCubit>().state.status, LaunchStatus.ready);
      expect(
        gateways.calls,
        containsAllInOrder(<String>[
          'deviceInfo.androidSdkInt',
          'notifications.taps',
          'notifications.initialize',
        ]),
      );
      expect(gateways.calls, contains('ffmpeg.listEncoders'));
      expect(Directory(paths.videos).existsSync(), isTrue);
    });

    test('a fresh install still has no diary folder', () async {
      await launch(environment());

      await firstFrame();

      expect(sl<LaunchCubit>().state.status, LaunchStatus.ready);
      expect(Directory(paths.videos).existsSync(), isFalse);
    });
  });
}
