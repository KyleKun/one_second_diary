import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../support/support.dart';
import 'fake_gateways.dart';

/// The app's real dependency container (`registerDependencies`, every
/// feature's `register<F>` included) over a fake for every platform gateway
/// ([FakeGateways]) and a temp folder, without launching the app.
///
/// For the `<feature>_injection_test.dart` files, which resolve what their
/// feature registers, and any test that needs the real service graph but no
/// widget tree. Tests may read `sl`; `lib/` may not (only the composition
/// files do, `service_locator_guard_test.dart`).
///
/// ```dart
/// setUp(() async => container = await TestContainer.create());
/// tearDown(() => container.dispose());
/// ```
final class TestContainer {
  TestContainer._({
    required this.core,
    required this.gateways,
    required this.clock,
    required this.log,
  });

  /// What bootstrap would have built before the first frame.
  final LaunchCore core;

  final FakeGateways gateways;
  final FakeClock clock;

  /// Everything the services logged.
  final MemoryLogSink log;

  AppPaths get paths => core.paths;

  /// Registers every dependency over [prefs] (an onboarded install by
  /// default), on the given platform, with the device in [deviceLanguage].
  static Future<TestContainer> create({
    Map<String, Object>? prefs,
    bool isAndroid = false,
    bool isIOS = false,
    String deviceLanguage = 'en',
    DateTime? now,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
    await sl.reset();
    final FakeClock clock = FakeClock(now ?? DateTime(2024, 1, 5, 10));
    final MemoryLogSink log = MemoryLogSink();
    final PrefsStore store = await openLegacyPrefs(prefs ?? legacyPrefs());
    final AppPaths paths = await createTestPaths();
    final LaunchCore core = LaunchCore(
      clock: clock,
      prefs: store,
      paths: paths,
      logger: memoryLogger(log, clock: clock),
      logSession: null,
      settings: SettingsRepository(prefs: store),
      isAndroid: isAndroid,
      isIOS: isIOS,
      deviceLanguageCode: () => deviceLanguage,
    );
    final FakeGateways gateways = FakeGateways(clock: clock, paths: paths);
    registerDependencies(core: core, overrides: gateways.register);
    return TestContainer._(
      core: core,
      gateways: gateways,
      clock: clock,
      log: log,
    );
  }

  /// Resets the container (closing what it made) and the fakes.
  Future<void> dispose() async {
    await sl.reset();
    await gateways.close();
  }
}
