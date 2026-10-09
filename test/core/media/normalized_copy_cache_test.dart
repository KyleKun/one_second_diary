import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/normalized_copy_cache.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../../support/support.dart';

void main() {
  late Directory root;
  late FakeClock clock;

  setUp(() async {
    root = await createTempRoot();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
  });

  /// A cache whose cap reads [capBytes] at each trim ([caps] records the
  /// reads).
  int caps = 0;
  NormalizedCopyCache cache({int Function()? capBytes}) => NormalizedCopyCache(
    directory: '${root.path}/normalized',
    capBytes: () async {
      caps++;
      return capBytes?.call() ?? 1000;
    },
    clock: clock,
  );

  final String key = NormalizedCopyCache.keyFor(
    relPath: '2019-05-01.mp4',
    sizeBytes: 5000,
    modified: DateTime.utc(2019, 5, 1, 20),
    format: const ClipFormat.legacy(VideoOrientation.landscape),
  );

  // The cap follows the free space (`StorageBudget.normalizedCacheCap`), read afresh at
  // each trim, so a phone that filled up since the last movie trims harder.
  test('reads its cap at each trim, not when it is made', () async {
    int cap = 1 << 30;
    final NormalizedCopyCache store = cache(capBytes: () => cap);
    expect(caps, 0);

    await store.trim();
    expect(caps, 1);

    for (int i = 0; i < 3; i++) {
      final File copy = File('${root.path}/scratch/job-$i/f.mp4')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(100, i));
      clock.advance(const Duration(minutes: 1));
      await store.put(key: '$key-$i', file: copy.path);
    }
    cap = 250;
    await store.trim();

    expect(caps, 2);
    expect(
      Directory('${root.path}/normalized').listSync().length,
      2,
      reason: 'the oldest copy went to meet the new cap',
    );
  });

  test('has nothing for a clip it never stored; keeps a stored copy and '
      'hands it back for the same clip', () async {
    expect(await cache().lookup(key), isNull);
    final File normalised = File('${root.path}/scratch/job-1/f.mp4')
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[1, 2, 3]);
    final NormalizedCopyCache store = cache();

    final String stored = await store.put(key: key, file: normalised.path);

    expect(stored, startsWith('${root.path}/normalized/'));
    expect(await store.lookup(key), stored);
    expect(File(stored).readAsBytesSync(), <int>[1, 2, 3]);
    expect(normalised.existsSync(), isFalse, reason: 'moved, not copied');
  });

  // A clip edited or replaced (new size or time) must never get a copy of
  // its old content; a sub-folder clip gets its own entry.
  test('a clip is known by its path, size, modification time and canvas', () {
    // A copy of one format never serves a movie of another.
    const ClipFormat fourK = ClipFormat(
      tier: ResolutionTier.p2160,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f60,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    );
    String keyOf({
      String relPath = 'Profiles/My Trip/trip/2019-05-01.mp4',
      int sizeBytes = 5000,
      DateTime? modified,
      ClipFormat format = const ClipFormat.legacy(VideoOrientation.landscape),
    }) => NormalizedCopyCache.keyFor(
      relPath: relPath,
      sizeBytes: sizeBytes,
      modified: modified ?? DateTime.utc(2019, 5, 1, 20),
      format: format,
    );

    final List<String> keys = <String>[
      keyOf(),
      keyOf(relPath: 'Profiles/My Trip/2019-05-01.mp4'),
      keyOf(sizeBytes: 5001),
      keyOf(modified: DateTime.utc(2019, 5, 1, 20, 0, 0, 1)),
      keyOf(format: const ClipFormat.legacy(VideoOrientation.portrait)),
      keyOf(format: fourK),
    ];

    expect(keys.toSet(), hasLength(keys.length));
    expect(keyOf(), keyOf(), reason: 'stable from movie to movie');
    expect(
      keys.where((String k) => !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(k)),
      isEmpty,
      reason: 'a plain file name',
    );
  });

  group('capped', () {
    String keyOf(String name) => NormalizedCopyCache.keyFor(
      relPath: name,
      sizeBytes: 400,
      modified: DateTime.utc(2019),
      format: const ClipFormat.legacy(VideoOrientation.landscape),
    );

    Future<String> store(NormalizedCopyCache cache, String name) {
      final File copy = File('${root.path}/scratch/$name')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(400, 7));
      return cache.put(key: keyOf(name), file: copy.path);
    }

    test('keeps everything at or under the cap and drops the least recently '
        'used copies above it', () async {
      final NormalizedCopyCache capped = cache(capBytes: () => 1000);
      await store(capped, 'a.mp4');
      clock.advance(const Duration(minutes: 1));
      await store(capped, 'b.mp4');
      clock.advance(const Duration(minutes: 1));
      await capped.trim();
      expect(await capped.lookup(keyOf('a.mp4')), isNotNull, reason: '800 B');
      expect(await capped.lookup(keyOf('b.mp4')), isNotNull, reason: '800 B');
      clock.advance(const Duration(minutes: 1));
      await store(capped, 'c.mp4');
      clock.advance(const Duration(minutes: 1));
      await capped.lookup(keyOf('a.mp4')); // used again: now the newest

      await capped.trim();

      expect(await capped.lookup(keyOf('b.mp4')), isNull);
      expect(await capped.lookup(keyOf('a.mp4')), isNotNull);
      expect(await capped.lookup(keyOf('c.mp4')), isNotNull);
    });
  });
}
