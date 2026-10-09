import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/app/launch/launch_app.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_environment.dart';
import 'package:one_second_diary/app/launch/launch_starter.dart';
import 'package:one_second_diary/app/osd_app.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/global_error_handlers.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/migrations/v3_schema_steps.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/support.dart';
import 'fake_gateways.dart';
import 'settle.dart';
import 'settle.dart' as waits show settleUntil;

/// What [AppHarness.launch] was told about the phone.
typedef _Phone = ({
  bool platformIsDark,
  String deviceLanguage,
  bool isAndroid,
  bool isIOS,
});

/// The whole app, launched the way the device launches it: `launchApp`
/// (prefs, paths, the log file, theme settling, the schema step, date
/// symbols, translations, the real dependency graph), `OsdApp`'s first
/// frame, then the post-frame launch through `LaunchCubit`, all on a temp
/// folder and the given preferences, with a fake for every platform
/// gateway ([FakeGateways]). No plugin runs, and [platformChannels] records
/// every channel anything sent a message on.
///
/// Real file IO runs in `tester.runAsync`; the widget test's fake clock
/// drives everything else. After an action whose effect goes through the
/// services the launch built, wait for the effect with [settleUntil].
final class AppHarness {
  AppHarness._(
    this._phone, {
    required this.tester,
    required this.paths,
    required this.clock,
    required this.gateways,
    required this.platformChannels,
  });

  /// The phone the app was launched on, for [relaunch].
  final _Phone _phone;

  final WidgetTester tester;
  final AppPaths paths;
  final FakeClock clock;
  final FakeGateways gateways;

  /// Every platform channel a message was sent on, in order.
  final List<String> platformChannels;

  GoRouter get router => sl<GoRouter>();

  /// The preference store, as the next launch would read it.
  Future<SharedPreferences> get storedPrefs => SharedPreferences.getInstance();

  /// The phone frame of the design (390 × 844 at 3×).
  static const Size phone = Size(390, 844);

  /// The moment the app starts unless a test picks one ([launch]'s `now`).
  static final DateTime defaultNow = DateTime(2024, 1, 5, 10);

  /// Launches the app. [prefs] is the preference store (`legacyPrefs()` for
  /// an onboarded install, `freshInstallPrefs` for a first launch);
  /// [platformIsDark], [deviceLanguage], [isAndroid] and [isIOS] describe
  /// the phone (neither: a host platform), and [now] is when the app starts
  /// ([defaultNow]; the [clock] moves on from there). A fresh install gets
  /// no diary folder, as on a device. [seed] writes files into the folders
  /// before the launch. [configureGateways] scripts the fake platform
  /// before the app starts (a lens list, a permission answer, a pick the
  /// system kept while the app was away).
  static Future<AppHarness> launch(
    WidgetTester tester, {
    required Map<String, Object> prefs,
    bool platformIsDark = true,
    String deviceLanguage = 'en',
    bool isAndroid = false,
    bool isIOS = false,
    DateTime? now,
    Future<void> Function(AppPaths paths)? seed,
    void Function(FakeGateways gateways)? configureGateways,
  }) => _launch(
    tester,
    prefs: prefs,
    phone: (
      platformIsDark: platformIsDark,
      deviceLanguage: deviceLanguage,
      isAndroid: isAndroid,
      isIOS: isIOS,
    ),
    now: now,
    seed: seed,
    configureGateways: configureGateways,
  );

  /// The OS kills the app (its pages go away without a word) and the user
  /// opens it again on the same phone, at the clock's time: a new launch
  /// over the preferences and the folders the app left.
  /// [configureGateways] scripts the platform for the new launch (a
  /// permission the user granted in the phone's settings meanwhile).
  Future<AppHarness> relaunch({
    void Function(FakeGateways gateways)? configureGateways,
  }) async {
    final SharedPreferences stored = await storedPrefs;
    final Map<String, Object> left = <String, Object>{
      for (final String key in stored.getKeys()) key: stored.get(key)!,
    };
    await tester.pumpWidget(const SizedBox.shrink());
    // The dead process's services go with it (their file IO needs the real
    // zone to finish).
    await tester.runAsync(sl.reset);
    return _launch(
      tester,
      prefs: left,
      phone: _phone,
      now: clock.now(),
      paths: paths,
      configureGateways: configureGateways,
    );
  }

  static Future<AppHarness> _launch(
    WidgetTester tester, {
    required Map<String, Object> prefs,
    required _Phone phone,
    DateTime? now,
    AppPaths? paths,
    Future<void> Function(AppPaths paths)? seed,
    void Function(FakeGateways gateways)? configureGateways,
  }) async {
    final (
      :bool platformIsDark,
      :String deviceLanguage,
      :bool isAndroid,
      :bool isIOS,
    ) = phone;
    assert(!(isAndroid && isIOS), 'One phone at a time');
    EasyLocalization.logger.enableLevels = [];
    tester.view
      ..physicalSize = AppHarness.phone * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final List<String> channels = _recordPlatformChannels(tester);
    await sl.reset();
    final FakeClock clock = FakeClock(now ?? defaultNow);
    final bool onboarded = prefs['showIntro'] == false;
    final AppPaths folders =
        paths ??
        (await tester.runAsync(
          () async => onboarded
              ? createTestPaths()
              : AppPaths.forTest(await createTempRoot()),
        ))!;
    if (seed != null) await tester.runAsync(() => seed(folders));
    final FakeGateways gateways = FakeGateways(clock: clock, paths: folders);
    configureGateways?.call(gateways);
    addTearDown(() async {
      await sl.reset();
      await gateways.close();
      rootBundle.clear();
    });

    Widget? app;
    // An onboarded install the journeys launch has run 2.0's schema steps
    // already (`v3SchemaVersion`) unless its prefs say otherwise: the
    // one-time "What's new: quality" sheet those steps flag
    // would otherwise open on every Today. A fresh
    // install runs them for real.
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (onboarded) PrefKeys.osdSchemaVersion.name: v3SchemaVersion,
      ...prefs,
    });
    await tester.runAsync(
      () => launchApp(
        environment: LaunchEnvironment(
          clock: clock,
          isAndroid: isAndroid,
          isIOS: isIOS,
          openPrefs: PrefsStore.open,
          resolvePaths: () async => folders,
          documentsPath: () async => folders.internal,
          platformIsDark: () => platformIsDark,
          deviceLanguageCode: () => deviceLanguage,
          // The test framework owns the global error handlers.
          installErrorHandlers: (GlobalErrorHandlers handlers) {},
          loadDateSymbols: initializeDateFormatting,
          loadTranslations: EasyLocalization.ensureInitialized,
          printLog: (String line) {},
          lockPortrait: gateways.screenOrientation.portraitOnly,
        ),
        buildApp: () => const OsdApp(),
        runApp: (Widget widget) => app = widget,
        overrides: gateways.register,
      ),
    );
    // Exactly one frame, as on a device: it builds the app-scoped cubits
    // and the router, and is empty below the app's `Localizations`, which
    // are still loading the translations.
    await tester.pumpWidget(app!);
    expect(
      find.byType(LaunchStarter),
      findsNothing,
      reason:
          'The first frame mounted the pages: their LaunchStarter would '
          'start the launch in the fake-async zone, where its real IO never '
          'completes.',
    );
    // The launch starts now, before the pages and the migration dialog's
    // listener are mounted: the earliest a launch can start, so a journey
    // sees the app cope with any order. On a device `LaunchStarter` starts
    // it later, once the pages show; its own start then joins this one.
    // The launch builds its services here, in the real zone, where their
    // file IO completes.
    await tester.runAsync(() async {
      await sl<LaunchCubit>().start();
      await sl<MediaEngine>().init();
    });
    await settle(tester);
    return AppHarness._(
      phone,
      tester: tester,
      paths: folders,
      clock: clock,
      gateways: gateways,
      platformChannels: channels,
    );
  }

  /// Lets the app run until [condition] holds, then settles it; fails the
  /// test with [reason] when it still does not hold after [timeout].
  ///
  /// The launch built the services in the real zone, and real file IO
  /// completes on the VM's IO threads, outside the event loop: no number of
  /// event-queue turns is sure to cover them. Wait on what a user or the OS
  /// can observe: the page shown, a snackbar, a count, a file, what the
  /// notification gateway holds. The
  /// fake clock follows the wall clock meanwhile, never faster (see the
  /// shared [settleUntil] in `settle.dart`), so a slower machine never lets
  /// a snackbar or a timer run out; the wall clock only bounds the wait.
  Future<void> settleUntil(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 30),
  }) => waits.settleUntil(tester, condition, reason: reason, timeout: timeout);

  /// Records the channel of every message sent to the platform, and passes
  /// it on to the test binding as usual.
  static List<String> _recordPlatformChannels(WidgetTester tester) {
    final List<String> channels = <String>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.allMessagesHandler =
        (String channel, MessageHandler? handler, ByteData? message) {
          channels.add(channel);
          return handler != null
              ? handler(message)
              : messenger.delegate.send(channel, message);
        };
    addTearDown(() => messenger.allMessagesHandler = null);
    return channels;
  }
}
