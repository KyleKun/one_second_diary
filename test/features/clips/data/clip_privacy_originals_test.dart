// A private clip's kept original carries the same tag: marking the clip remuxes its source too and puts it back in its
// place; a source that could not be rewritten is logged, the clip's own
// mark stands.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_privacy.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

const ProfileKey _work = ProfileKey('Work');
const List<int> _sourceBytes = <int>[3, 3, 3];

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late FakeMediaEngine engine;
  late ClipRepository repository;
  late OriginalsStore originals;
  late ClipPrivacy privacy;
  late ClipRef clip;
  late File source;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    final FakeMediaStoreGateway gallery = FakeMediaStoreGateway.onDisk(paths);
    engine = FakeMediaEngine(scratchDir: paths.scratchDir);
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
    final ClipMetadataCache metadata = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(metadata.dispose);
    originals = OriginalsStore(
      paths: paths,
      gateway: gallery,
      logger: memoryLogger(sink),
      isAndroid: true,
    );
    addTearDown(originals.dispose);
    privacy = ClipPrivacy(
      engine: engine,
      publisher: MediaPublisher(
        gateway: gallery,
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
        originals: originals,
      ),
      repository: repository,
      metadata: metadata,
      thumbnails: ThumbnailRepository(
        gateway: FakeThumbnailGateway(),
        queue: ThumbnailQueue(),
        metadata: metadata,
        paths: paths,
        logger: memoryLogger(sink),
      ),
      paths: paths,
      logger: memoryLogger(sink),
      originals: originals,
    );
    final File file = await seedClip(paths, _work, LocalDay(2024, 1, 5));
    clip = ClipRef(profile: _work, relPath: paths.relativeToVideos(file.path));
    source = File(originals.absoluteOf('Profiles/Work/2024-01-05.mov'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(_sourceBytes);
    await originals.scanNames();
    await repository.loadAll(active: _work, profiles: const <ProfileKey>[]);
  });

  test(
    'marking a clip private remuxes its kept source with the same mark, '
    'after the clip, and puts the remux in the source\'s place; public '
    'again the same way; a clip without a source touches only itself',
    () async {
      await privacy.setPrivate(clip, private: true);

      expect(engine.privacyRequests, <({String clipPath, bool private})>[
        (clipPath: paths.absoluteFromVideos(clip.relPath), private: true),
        (clipPath: source.path, private: true),
      ]);
      expect(source.readAsBytesSync(), fakeVideoBytes, reason: 'the remux');
      expect(originals.sourceRelPaths, <String>{clip.relPath});

      await privacy.setPrivate(clip, private: false);
      expect(engine.privacyRequests.last, (
        clipPath: source.path,
        private: false,
      ));

      source.deleteSync();
      await originals.scanNames();
      await privacy.setPrivate(clip, private: true);
      expect(engine.privacyRequests, hasLength(5));
      expect(engine.privacyRequests.last.clipPath, isNot(source.path));
    },
  );

  test('a source that could not be remuxed is logged; the clip\'s own mark '
      'stands and the source is as it was', () async {
    engine.privacyError = null;
    // The clip's remux works, the source's fails: the engine fails on the
    // second request only.
    int calls = 0;
    engine.privacyErrorFor = (String clipPath) => ++calls == 2
        ? const VideoProcessingException(
            'ffmpeg failed',
            returnCode: 1,
            logTail: '',
          )
        : null;

    await privacy.setPrivate(clip, private: true);

    expect(repository.snapshotOf(_work)!.isPrivate(clip), isTrue);
    expect(source.readAsBytesSync(), _sourceBytes);
    expect(
      sink.lines.last,
      contains('Could not mark the original of ${clip.relPath} private'),
    );
  });
}
