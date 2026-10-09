import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';

import '../../../support/support.dart';

const String _a = '/videos/2024-01-01.mp4';
const String _b = '/videos/2024-01-02.mp4';
const String _c = '/videos/2024-01-03.mp4';
const String _d = '/videos/2024-01-04.mp4';

void main() {
  late MemoryLogSink sink;
  late FakePlayerFactory factory;
  late PlayerPool pool;

  setUp(() {
    sink = MemoryLogSink();
    factory = FakePlayerFactory();
    pool = PlayerPool(
      factory: factory,
      logger: memoryLogger(sink),
      muted: true,
    );
    addTearDown(pool.dispose);
  });

  FakePlayerHandle handleOf(String path) =>
      factory.alive.singleWhere((FakePlayerHandle h) => h.path == path);

  test('shows the selected clip once its player is ready, looping, muted '
      'and mixing with other audio (Z MB-14); a clip that cannot be played is '
      'still shown, with its error, and the failure is logged (v1.7 jumped to '
      'HOME from build)', () async {
    await pool.select(_a);

    final ShownPlayer shown = pool.shown.value!;
    final FakePlayerHandle handle = handleOf(_a);
    expect(shown.path, _a);
    expect(shown.handle, same(handle));
    expect(handle.value.value.initialized, isTrue);
    expect(handle.looping, isTrue);
    expect(handle.volume, 0);
    expect(handle.mixWithOthers, isTrue);

    // A clip that cannot be played.
    {
      factory.failingPaths.add(_b);
      await pool.select(_a);

      await pool.select(_b);

      expect(pool.shown.value!.path, _b);
      expect(pool.shown.value!.handle.value.value.error, isNotNull);
      expect(
        sink.lines.single,
        contains('[CALENDAR] Could not open the player of $_b'),
      );
    }
  });

  test('keeps the old clip on screen until the new one is ready, and only '
      'then disposes it (v1.7 showed a black gap); a clip tapped past before '
      'its player was ready is never shown', () async {
    await pool.select(_a);
    final FakePlayerHandle a = handleOf(_a);
    factory.holdInitialize = true;

    unawaited(pool.select(_b));
    await pumpEventQueue();
    expect(pool.shown.value!.path, _a);
    expect(a.isDisposed, isFalse);

    handleOf(_b).completeInitialize();
    await pumpEventQueue();
    expect(pool.shown.value!.path, _b);
    expect(a.isDisposed, isTrue);

    // A clip tapped past before its player was ready is never shown, and
    // its player is disposed.
    unawaited(pool.select(_c));
    unawaited(pool.select(_d));
    await pumpEventQueue();
    final FakePlayerHandle c = factory.created.lastWhere(
      (FakePlayerHandle h) => h.path == _c,
    );
    c.completeInitialize();
    await pumpEventQueue();
    expect(pool.shown.value!.path, _b);
    expect(c.isDisposed, isTrue);

    handleOf(_d).completeInitialize();
    await pumpEventQueue();
    expect(pool.shown.value!.path, _d);
  });

  test('warms the previous and next recorded clips, paused, so stepping to '
      'one shows its own player at once; never more than three players, even '
      'while a far jump is loading', () async {
    await pool.select(_b, neighbours: <String>[_a, _c]);
    await pumpEventQueue();

    expect(
      factory.alive.map((FakePlayerHandle h) => h.path),
      unorderedEquals(<String>[_a, _b, _c]),
    );
    final FakePlayerHandle warmC = handleOf(_c);
    expect(warmC.value.value.initialized, isTrue);
    expect(warmC.value.value.playing, isFalse);

    await pool.select(_c, neighbours: <String>[_b]);

    expect(pool.shown.value!.handle, same(warmC));

    // Never more than three players: the selected clip and its two
    // neighbours, even while a far jump is loading.
    {
      final _PeakCountingFactory factory = _PeakCountingFactory();
      final PlayerPool pool = PlayerPool(
        factory: factory,
        logger: memoryLogger(sink),
        muted: true,
      );
      addTearDown(pool.dispose);
      FakePlayerHandle handleOf(String path) =>
          factory.alive.singleWhere((FakePlayerHandle h) => h.path == path);
      String day(int d) =>
          '/videos/2024-01-${d.toString().padLeft(2, '0')}.mp4';
      for (int d = 2; d <= 6; d++) {
        await pool.select(day(d), neighbours: <String>[day(d - 1), day(d + 1)]);
        await pumpEventQueue();
        expect(factory.alive.length, lessThanOrEqualTo(3));
      }

      factory.holdInitialize = true;
      unawaited(pool.select(day(20), neighbours: <String>[day(19), day(21)]));
      await pumpEventQueue();
      expect(factory.alive.map((FakePlayerHandle h) => h.path), <String>[
        day(6),
        day(20),
      ]);

      handleOf(day(20)).completeInitialize();
      await pumpEventQueue();
      expect(factory.alive.map((FakePlayerHandle h) => h.path), <String>[
        day(20),
        day(19),
        day(21),
      ]);
      expect(factory.mostAlive, 3);
    }
  });

  // The viewer takes the Diary's warm player: the clip plays at once.
  group('handing a player over', () {
    test('an adopted player shows at once, from the start, in the pool\'s '
        'mode, and the pool disposes it; release gives up the ready player of '
        'a clip, undisposed, and nothing while it is not ready', () async {
      final PlayerPool other = PlayerPool(
        factory: factory,
        logger: memoryLogger(sink),
        muted: false,
      );
      await pool.select(_a);
      final FakePlayerHandle a = handleOf(_a);
      await a.play();
      await a.seekTo(const Duration(milliseconds: 700));

      other.adopt(pool.release(_a)!);
      await other.select(_a);

      expect(other.shown.value!.handle, same(a));
      expect(factory.created, hasLength(1), reason: 'no player was opened');
      expect(a.value.value.playing, isFalse);
      expect(a.value.value.position, Duration.zero);
      expect(a.volume, 1);
      await other.dispose();
      expect(a.isDisposed, isTrue);

      // Release gives up the ready player of a clip: it leaves the screen
      // and the pool, undisposed; nothing to release while not ready.
      {
        factory.holdInitialize = true;
        unawaited(pool.select(_d));
        await pumpEventQueue();
        expect(pool.release(_d), isNull);
        handleOf(_d).completeInitialize();
        factory.holdInitialize = false;

        await pool.select(_a, neighbours: <String>[_b]);
        await pumpEventQueue();
        final FakePlayerHandle a = handleOf(_a);
        final FakePlayerHandle b = handleOf(_b);

        final ShownPlayer? released = pool.release(_a);

        expect(released, ShownPlayer(path: _a, handle: a));
        expect(pool.shown.value, isNull);
        await pool.dispose();
        expect(a.isDisposed, isFalse, reason: 'its new owner disposes it');
        expect(b.isDisposed, isTrue);
      }
    });
  });

  group('setMuted', () {
    test('unmuting recreates the players without mixing, so the clip takes '
        'audio focus like v1.7, and keeps playing where it was; toggling '
        'twice while the first replacement loads, or selecting another clip '
        'while it loads, keeps at most three players and leaks none (review '
        '1b)', () async {
      await pool.select(_a, neighbours: <String>[_b]);
      await pumpEventQueue();
      final PlayerHandle before = pool.shown.value!.handle;
      await before.seekTo(const Duration(milliseconds: 700));
      await before.play();

      await pool.setMuted(false);
      await pumpEventQueue();

      final FakePlayerHandle after = handleOf(_a);
      expect(pool.shown.value!.handle, same(after));
      expect(after, isNot(same(before)));
      expect(after.volume, 1);
      expect(after.value.value.position, const Duration(milliseconds: 700));
      expect(after.value.value.playing, isTrue);
      expect(
        factory.alive.every((FakePlayerHandle h) => !h.mixWithOthers),
        isTrue,
      );
      expect(
        factory.alive.map((FakePlayerHandle h) => h.path),
        unorderedEquals(<String>[_a, _b]),
      );

      // Toggling while a replacement loads.
      {
        await pool.select(_a, neighbours: <String>[_b, _c]);
        await pumpEventQueue();
        factory.holdInitialize = true;

        unawaited(pool.setMuted(false));
        await pumpEventQueue();
        unawaited(pool.setMuted(true));
        await pumpEventQueue();
        factory.holdInitialize = false;
        for (final FakePlayerHandle handle in factory.alive) {
          handle.completeInitialize();
        }
        await pumpEventQueue();

        expect(
          factory.alive.map((FakePlayerHandle h) => (h.path, h.mixWithOthers)),
          unorderedEquals(<(String, bool)>[(_a, true), (_b, true), (_c, true)]),
        );
        expect(handleOf(_a).volume, 0, reason: 'muted at once');

        // Selecting another clip while the unmuted replacement of the one on
        // screen loads drops that replacement.
        const String e = '/videos/2024-01-05.mp4';
        const String f = '/videos/2024-01-06.mp4';
        factory.holdInitialize = true;
        unawaited(pool.setMuted(false));
        await pumpEventQueue();
        factory.holdInitialize = false;
        await pool.select(_d, neighbours: <String>[e, f]);
        await pumpEventQueue();

        expect(pool.shown.value!.path, _d);
        expect(
          factory.alive.map((FakePlayerHandle h) => h.path),
          unorderedEquals(<String>[_d, e, f]),
        );
        await pool.dispose();
        expect(factory.alive, isEmpty);
      }
    });
  });

  test('opens a clip again when its file was rewritten since its player '
      'opened (a replaced clip keeps its name: the warm ExoPlayer read the '
      'new bytes with the old sample table and failed with "Invalid NAL '
      'length"); an unchanged file keeps its warm player', () async {
    final Directory dir = await Directory.systemTemp.createTemp('osd_pool_');
    addTearDown(() => dir.delete(recursive: true));
    final File clip = File('${dir.path}/2024-01-01.mp4');
    await clip.writeAsBytes(List<int>.filled(16, 1));

    await pool.select(clip.path);
    final FakePlayerHandle first = handleOf(clip.path);
    await pool.select(clip.path);
    expect(pool.shown.value!.handle, same(first), reason: 'unchanged file');

    // The clip is replaced: same name, other bytes.
    await clip.writeAsBytes(List<int>.filled(32, 2));
    await pool.select(clip.path);

    expect(pool.shown.value!.path, clip.path);
    expect(pool.shown.value!.handle, isNot(same(first)));
    expect(first.isDisposed, isTrue, reason: 'left once the new one shows');
    expect(factory.alive.map((FakePlayerHandle h) => h.path), <String>[
      clip.path,
    ]);
  });
}

/// Records the most players alive right after any creation.
class _PeakCountingFactory extends FakePlayerFactory {
  int mostAlive = 0;

  @override
  PlayerHandle create(String path, {required bool mixWithOthers}) {
    final PlayerHandle handle = super.create(
      path,
      mixWithOthers: mixWithOthers,
    );
    if (alive.length > mostAlive) mostAlive = alive.length;
    return handle;
  }
}
