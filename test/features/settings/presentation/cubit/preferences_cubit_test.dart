// The seven preferences, each change stored at once and logged with the line
// bug reports rely on ("[PREFERENCES] - <logName> was enabled / disabled").
// The retired "Strict clip length" key stays listed in PrefKeys, unread, and no switch shows it.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/app_preference.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

/// An [ImportFlow] that only answers whether this phone needs the system
/// camera (Android below 10).
class _SystemCameraRule extends Fake implements ImportFlow {
  _SystemCameraRule({required this.required});

  final bool required;

  @override
  Future<bool> systemCameraRequired() async => required;
}

void main() {
  late MemoryLogSink log;

  Future<PreferencesCubit> cubitOver(
    Map<String, Object> prefs, {
    bool systemCameraRequired = false,
  }) async {
    final PrefsStore store = await openLegacyPrefs(prefs);
    log = MemoryLogSink();
    final PreferencesCubit cubit = PreferencesCubit(
      settings: SettingsRepository(prefs: store),
      imports: _SystemCameraRule(required: systemCameraRequired),
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test("shows v1.7's defaults: only the experimental picker is on", () async {
    final PreferencesCubit cubit = await cubitOver(legacyPrefs());

    expect(
      <AppPreference, bool>{
        for (final AppPreference preference in AppPreference.values)
          preference: cubit.state.isOn(preference),
      },
      <AppPreference, bool>{
        AppPreference.forceNativeCamera: false,
        AppPreference.legacyStampFont: false,
        AppPreference.clipDeviceInfo: false,
        AppPreference.keepOriginals: false,
        AppPreference.experimentalPicker: true,
        AppPreference.filterByDate: false,
        AppPreference.alternativeCalendarColors: false,
        AppPreference.verboseLogging: false,
      },
    );
    expect(cubit.state.status, PreferencesStatus.ready);
  });

  test(
    'each switch stores its v1.7 key at once and logs v1.7\'s line',
    () async {
      final PreferencesCubit cubit = await cubitOver(legacyPrefs());
      const List<(AppPreference, String, bool)> switches =
          <(AppPreference, String, bool)>[
            (AppPreference.forceNativeCamera, 'forceNativeCamera', true),
            (AppPreference.legacyStampFont, 'legacyStampFont', true),
            (AppPreference.experimentalPicker, 'useExperimentalPicker', false),
            (
              AppPreference.alternativeCalendarColors,
              'useAlternativeCalendarColors',
              true,
            ),
            (AppPreference.verboseLogging, 'verboseLogging', true),
            // With the in-app picker back on, its date filter can be.
            (AppPreference.experimentalPicker, 'useExperimentalPicker', true),
            (AppPreference.filterByDate, 'useFilterInExperimentalPicker', true),
          ];

      for (final (AppPreference preference, String key, bool value)
          in switches) {
        await cubit.set(preference, value);

        expect(cubit.state.isOn(preference), value, reason: key);
        expect(
          (await SharedPreferences.getInstance()).getBool(key),
          value,
          reason: key,
        );
      }
      expect(
        log.lines.map((String line) => line.split(': ').skip(1).join(': ')),
        <String>[
          '[PREFERENCES] - Force native camera for recording was enabled',
          '[PREFERENCES] - Legacy font in videos was enabled',
          '[PREFERENCES] - Use experimental file picker was disabled',
          '[PREFERENCES] - Use alternative calendar colors was enabled',
          '[PREFERENCES] - Verbose logging was enabled',
          '[PREFERENCES] - Use experimental file picker was enabled',
          '[PREFERENCES] - Use filter in experimental file picker was enabled',
        ],
      );
      expect(cubit.state.status, PreferencesStatus.ready);
    },
  );

  group('the date filter needs the in-app picker (S3 §6)', () {
    test('with the picker off it shows off and can\'t be turned on, even '
        'when v1.7 stored it on (v1.7 ignored it then); turning the picker '
        'on turns that filter off', () async {
      final PreferencesCubit cubit = await cubitOver(
        legacyPrefs(
          extra: <String, Object>{
            'useExperimentalPicker': false,
            'useFilterInExperimentalPicker': true,
          },
        ),
      );

      expect(cubit.state.isOn(AppPreference.filterByDate), isFalse);
      expect(cubit.state.isEnabled(AppPreference.filterByDate), isFalse);
      await cubit.set(AppPreference.filterByDate, true);

      expect(cubit.state.isOn(AppPreference.filterByDate), isFalse);
      expect(log.lines, isEmpty);

      // Turning the picker on over it turns the filter off, so it never
      // comes back on by itself.
      await cubit.set(AppPreference.experimentalPicker, true);

      expect(cubit.state.isOn(AppPreference.filterByDate), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'useFilterInExperimentalPicker',
        ),
        isFalse,
      );
    });

    test('turning the picker off turns the filter off; turning the picker '
        'back on leaves it off', () async {
      final PreferencesCubit cubit = await cubitOver(
        legacyPrefs(
          extra: <String, Object>{'useFilterInExperimentalPicker': true},
        ),
      );

      await cubit.set(AppPreference.experimentalPicker, false);
      expect(cubit.state.isOn(AppPreference.filterByDate), isFalse);
      await cubit.set(AppPreference.experimentalPicker, true);

      expect(cubit.state.isOn(AppPreference.experimentalPicker), isTrue);
      expect(cubit.state.isEnabled(AppPreference.filterByDate), isTrue);
      expect(cubit.state.isOn(AppPreference.filterByDate), isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'useFilterInExperimentalPicker',
        ),
        isFalse,
      );
      expect(
        log.lines.map((String line) => line.split(': ').skip(1).join(': ')),
        <String>[
          '[PREFERENCES] - Use experimental file picker was disabled',
          '[PREFERENCES] - Use filter in experimental file picker was disabled',
          '[PREFERENCES] - Use experimental file picker was enabled',
        ],
      );
    });
  });

  test('a refused write shows the stored value again and says so, every '
      'time (S3 §6)', () async {
    final (PrefsStore store, _) = await openRefusingPrefs(
      legacyPrefs(),
      refused: <String>{'legacyStampFont'},
    );
    log = MemoryLogSink();
    final PreferencesCubit cubit = PreferencesCubit(
      settings: SettingsRepository(prefs: store),
      imports: _SystemCameraRule(required: false),
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    final List<(PreferencesStatus, bool)> seen = <(PreferencesStatus, bool)>[];
    cubit.stream.listen(
      (PreferencesState s) =>
          seen.add((s.status, s.isOn(AppPreference.legacyStampFont))),
    );

    await cubit.set(AppPreference.legacyStampFont, true);
    await cubit.set(AppPreference.legacyStampFont, true);
    await pumpEventQueue();

    expect(seen, <(PreferencesStatus, bool)>[
      (PreferencesStatus.saving, true),
      (PreferencesStatus.saveFailed, false),
      (PreferencesStatus.saving, true),
      (PreferencesStatus.saveFailed, false),
    ]);
    expect(
      log.lines,
      everyElement(
        contains('[PREFERENCES] Could not store Strict clip length'),
      ),
    );
  });

  test('below Android 10 "Force native camera" shows on and locked '
      '(SYNTHESIS Q-S8); nothing is stored; from Android 10 on it is a '
      'normal switch', () async {
    final PreferencesCubit cubit = await cubitOver(
      legacyPrefs(),
      systemCameraRequired: true,
    );

    await cubit.load();
    await cubit.set(AppPreference.forceNativeCamera, false);

    expect(cubit.state.nativeCameraRequired, isTrue);
    expect(cubit.state.isOn(AppPreference.forceNativeCamera), isTrue);
    expect(cubit.state.isEnabled(AppPreference.forceNativeCamera), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('forceNativeCamera'),
      isNull,
    );

    // From Android 10 on, it is a normal switch.
    final PreferencesCubit android10 = await cubitOver(legacyPrefs());
    await android10.load();

    expect(android10.state.nativeCameraRequired, isFalse);
    expect(android10.state.isEnabled(AppPreference.forceNativeCamera), isTrue);
  });
}
