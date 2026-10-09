import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/active_profile_clips.dart';
import 'package:one_second_diary/app/wiring/legacy_counter_wiring.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/fakes/clip_index_fixture.dart';
import '../../shared/fakes/fake_clip_repository.dart';
import '../../shared/fakes/fake_profiles_repository.dart';
import '../../support/support.dart';
import '../../support/track_1c/refusing_shared_preferences.dart';

const ProfileKey work = ProfileKey('Work');

// A downgraded app force-unwraps videoCount, so it must find the active
// profile's counters.
void main() {
  late FakeClock clock;
  late MemoryLogSink sink;
  late PrefsStore prefs;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late MidnightTicker midnight;

  setUp(() async {
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    sink = MemoryLogSink();
    prefs = await openLegacyPrefs(legacyPrefs());
    profiles = FakeProfilesRepository(
      profiles: <Profile>[
        testProfile(),
        testProfile(key: work),
      ],
    );
    clips = FakeClipRepository();
    midnight = MidnightTicker(clock: clock);
    addTearDown(() async {
      await profiles.close();
      await clips.close();
    });
  });

  LegacyCounterWiring wiring({PrefsStore? mirrorPrefs}) {
    final LegacyCounterWiring wiring = LegacyCounterWiring(
      activeClips: ActiveProfileClips(profiles: profiles, clips: clips),
      mirror: LegacyPrefsMirror(prefs: mirrorPrefs ?? prefs),
      midnight: midnight,
      clock: clock,
      logger: memoryLogger(sink, clock: clock),
    );
    addTearDown(wiring.dispose);
    return wiring;
  }

  test('are written from the active profile each time its snapshot '
      'changes', () async {
    wiring().start();

    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
        LocalDay(2024, 1, 3),
        LocalDay(2024, 1, 5),
      ]),
    );
    await pumpEventQueue();

    expect(prefs.read(PrefKeys.videoCount), 2);
    expect(prefs.read(PrefKeys.dailyEntry), isTrue);
    expect(prefs.read(PrefKeys.today), '2024-01-05');
  });

  test('are written at once for a diary already read', () async {
    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[LocalDay(2024, 1, 3)]),
    );

    wiring().start();
    await pumpEventQueue();

    expect(prefs.read(PrefKeys.videoCount), 1);
    expect(prefs.read(PrefKeys.dailyEntry), isFalse);
  });

  test('follow a profile switch', () async {
    wiring().start();
    clips
      ..publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          LocalDay(2024, 1, 3),
        ]),
      )
      ..publish(
        clipIndexOf(work, <LocalDay>[
          LocalDay(2024, 1, 1),
          LocalDay(2024, 1, 2),
          LocalDay(2024, 1, 5),
        ]),
      );
    await pumpEventQueue();
    expect(prefs.read(PrefKeys.videoCount), 1);

    await profiles.activate(work);
    await pumpEventQueue();

    expect(prefs.read(PrefKeys.videoCount), 3);
    expect(prefs.read(PrefKeys.dailyEntry), isTrue);
  });

  test('are written again at midnight, for the new day', () async {
    wiring().start();
    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[LocalDay(2024, 1, 5)]),
    );
    await pumpEventQueue();
    expect(prefs.read(PrefKeys.dailyEntry), isTrue);

    clock.setNow(DateTime(2024, 1, 6, 0, 0, 1));
    midnight.check();
    await pumpEventQueue();

    expect(prefs.read(PrefKeys.dailyEntry), isFalse);
    expect(prefs.read(PrefKeys.today), '2024-01-06');
    expect(prefs.read(PrefKeys.videoCount), 1);
  });

  test('ignore the snapshots of the other profiles', () async {
    wiring().start();

    clips.publish(clipIndexOf(work, <LocalDay>[LocalDay(2024, 1, 5)]));
    await pumpEventQueue();

    expect(prefs.read(PrefKeys.videoCount), 0);
    expect(prefs.contains(PrefKeys.dailyEntry), isFalse);
  });

  test('a counter the platform refuses to store is logged', () async {
    wiring(
      mirrorPrefs: PrefsStore(
        preferences: RefusingSharedPreferences(
          await SharedPreferences.getInstance(),
          refused: <String>{PrefKeys.videoCount.name},
        ),
      ),
    ).start();

    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[LocalDay(2024, 1, 5)]),
    );
    await pumpEventQueue();

    expect(
      sink.lines,
      contains(
        startsWith(
          '[ERROR] 2024-01-05 10:00:00.000: [APP] Could not write the legacy '
          'clip counters',
        ),
      ),
    );
  });

  test('stops following once disposed', () async {
    final LegacyCounterWiring subject = wiring()..start();
    await pumpEventQueue();

    await subject.dispose();
    clips.publish(
      clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[LocalDay(2024, 1, 5)]),
    );
    clock.setNow(DateTime(2024, 1, 6, 0, 0, 1));
    midnight.check();
    await pumpEventQueue();

    expect(prefs.contains(PrefKeys.dailyEntry), isFalse);
  });
}
