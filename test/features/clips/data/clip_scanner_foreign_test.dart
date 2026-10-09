// A date-named video with another extension (.mov, .m4v, .3gp, .MP4)
// directly in a profile's folder is found for the processing sheet, never
// indexed, never shown as a day; one in a user-made sub-folder stays the
// user's.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';

void main() {
  test('isForeignName: a clip stem with a video extension that is not a '
      'clip name; nothing else', () {
    for (final (String name, bool foreign) in <(String, bool)>[
      ('2024-01-05.mov', true),
      ('2024-01-05-2.M4V', true),
      ('2024-01-05.3gp', true),
      ('2024-01-05.MP4', true),
      ('2024-01-05.mp4', false), // a clip
      ('2024-01-05-1.mov', false), // not a canonical stem
      ('holiday.mov', false),
      ('2024-01-05.jpg', false),
      ('2024-01-05', false),
    ]) {
      expect(ClipScan.isForeignName(name), foreign, reason: name);
    }
  });

  test('the scan lists the foreign files of the profile folder itself, '
      'sorted, apart from the clips; a sub-folder\'s and another '
      'profile\'s are not listed', () async {
    final AppPaths paths = await createTestPaths();
    final MemoryLogSink sink = MemoryLogSink();
    final ClipScanner scanner = ClipScanner(
      paths: paths,
      logger: memoryLogger(sink),
    );
    const ProfileKey work = ProfileKey('Work');
    await seedClip(paths, work, LocalDay(2024, 1, 5));
    await seedFile(paths, 'Profiles/Work/2024-01-06.mov');
    await seedFile(paths, 'Profiles/Work/2024-01-04.MP4');
    await seedFile(paths, 'Profiles/Work/trip/2024-01-07.mov');
    await seedFile(paths, 'Profiles/Work/holiday.mov');
    await seedFile(paths, '2024-01-08.mov');

    final ClipScan scan = await scanner.scan(work);

    expect(scan.foreignFiles, <String>[
      'Profiles/Work/2024-01-04.MP4',
      'Profiles/Work/2024-01-06.mov',
    ]);
    expect(scan.index.clipCount, 1);
    expect(scan.skippedNames, isEmpty);
    expect(
      (await scanner.scan(ProfileKey.defaultProfile)).foreignFiles,
      <String>['2024-01-08.mov'],
    );
  });
}
