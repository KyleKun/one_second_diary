// A clip a user keeps in a sub-folder never disappears because the app
// records another clip for the same day.
//
// The new clip's ordinal is 1 + the highest ordinal of that day across the
// whole profile index. Had it taken the bare name at the root, the root file
// would have hidden `trip/2024-01-05.mp4` as a shallower duplicate. The clip
// store test covers a sub-folder clip the index knows; this one covers a
// clip copied in since the last scan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ClipRepository repository;
  final LocalDay day = LocalDay(2024, 1, 5);

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    repository = ClipRepository(
      scanner: ClipScanner(paths: paths, logger: memoryLogger(sink)),
      paths: paths,
      logger: memoryLogger(sink),
    );
    addTearDown(repository.dispose);
  });

  List<String> clipsOfDay(ClipIndex index) => <String>[
    for (final ClipRef clip in index.clipsOn(day)) clip.relPath,
  ];

  test('a sub-folder clip copied in since the last scan survives the next '
      'saved recording of its day', () async {
    const ProfileKey work = ProfileKey('Work');
    await repository.loadAll(active: work, profiles: <ProfileKey>[]);
    // Copied in (a sync app, the Files app) after the launch scan.
    await seedClip(paths, work, day, subFolder: 'trip');
    final ClipMetadataCache metadata = ClipMetadataCache(
      paths: paths,
      logger: memoryLogger(sink),
    );
    final ClipStore store = ClipStore(
      publisher: MediaPublisher(
        gateway: FakeMediaStoreGateway.onDisk(paths),
        paths: paths,
        logger: memoryLogger(sink),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
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
      isIOS: false,
    );
    final File camera = File('${paths.temporaryDir}/REC_0001.mp4');
    await camera.parent.create(recursive: true);
    await camera.writeAsBytes(fakeVideoBytes);
    final VideoSource source = VideoSource(
      path: camera.path,
      ownership: ClipOwnership.cameraTemp,
    );
    final VideoRender request = VideoRender(
      sourcePath: source.path,
      fromRecording: true,
      trimStartMs: 0,
      trimEndMs: 2500,
      outputFileName: '2024-01-05.mp4',
      stampText: '05/01/2024',
      stampStyle: const StampStyle(
        format: StampFormat.numeric,
        rgb: 0xFFFFFF,
        outline: true,
      ),
      legacyStampFont: false,
      location: const ClipLocation.off(),
      subtitles: '',
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Work',
    );
    final RenderedClip rendered = await FakeMediaEngine(
      scratchDir: paths.scratchDir,
    ).renderClip(request);

    final ClipWrite saved = await store.save(
      rendered: rendered,
      request: request,
      source: source,
      profile: work,
      day: day,
      mode: const AddClip(),
    );

    expect(saved.clip.relPath, 'Profiles/Work/2024-01-05-2.mp4');
    expect(clipsOfDay(await repository.rescan(work)), <String>[
      'Profiles/Work/trip/2024-01-05.mp4',
      'Profiles/Work/2024-01-05-2.mp4',
    ]);
  });
}
