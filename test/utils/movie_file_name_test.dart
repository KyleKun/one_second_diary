import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/utils/movie_file_name.dart';

void main() {
  group('build', () {
    test('matches the historical naming scheme', () {
      expect(
        MovieFileName.build(7, '2026-10-05'),
        'OSD-Movie-7-2026-10-05.mp4',
      );
    });
  });

  group('firstFreeCount', () {
    test('keeps the stored count when nothing is in the way', () {
      expect(
        MovieFileName.firstFreeCount(
          startCount: 3,
          date: '2026-10-05',
          exists: (_) => false,
        ),
        3,
      );
    });

    test('skips every count whose file already exists', () {
      final Set<String> onDisk = {
        'OSD-Movie-1-2026-10-05.mp4',
        'OSD-Movie-2-2026-10-05.mp4',
        // A different date doesn't collide, so it must not be skipped over.
        'OSD-Movie-3-2026-09-01.mp4',
      };

      expect(
        MovieFileName.firstFreeCount(
          startCount: 1,
          date: '2026-10-05',
          exists: onDisk.contains,
        ),
        3,
      );
    });

    test('checks the bare file name, never a path', () {
      final List<String> asked = [];

      MovieFileName.firstFreeCount(
        startCount: 1,
        date: '2026-10-05',
        exists: (name) {
          asked.add(name);
          return false;
        },
      );

      expect(asked, ['OSD-Movie-1-2026-10-05.mp4']);
    });
  });
}
