import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/utils/app_paths.dart';

void main() {
  tearDown(AppPaths.debugReset);

  group('storageRootOf', () {
    test('walks up from the app private folder to the storage root', () {
      expect(
        AppPaths.storageRootOf(
          '/storage/emulated/0/Android/data/com.kylekun.one_second_diary/files',
          fallback: '/fallback',
        ),
        '/storage/emulated/0',
      );
    });

    test('handles a removable volume', () {
      expect(
        AppPaths.storageRootOf(
          '/storage/1A2B-3C4D/Android/data/com.kylekun.one_second_diary/files',
          fallback: '/fallback',
        ),
        '/storage/1A2B-3C4D',
      );
    });

    test('falls back when there is no Android segment to stop at', () {
      expect(
        AppPaths.storageRootOf('', fallback: '/fallback'),
        '/fallback',
      );
      expect(
        AppPaths.storageRootOf('/Android/data/pkg/files', fallback: '/fallback'),
        '/fallback',
      );
    });
  });

  group('withTrailingSlash', () {
    test('adds a slash only when it is missing', () {
      expect(AppPaths.withTrailingSlash('/a/b'), '/a/b/');
      expect(AppPaths.withTrailingSlash('/a/b/'), '/a/b/');
    });
  });

  group('profileVideos', () {
    setUp(() {
      AppPaths.debugSetPaths(
        videos: '/root/DCIM/OneSecondDiary/',
        movies: '/root/DCIM/OneSecondDiary/Movies/',
        internal: '/data/app',
      );
    });

    test('an empty name means the default profile, which lives at the root', () {
      expect(AppPaths.profileVideos(''), '/root/DCIM/OneSecondDiary/');
    });

    test('a named profile gets its own folder', () {
      expect(
        AppPaths.profileVideos('Work'),
        '/root/DCIM/OneSecondDiary/Profiles/Work/',
      );
    });
  });

  group('isReady', () {
    test('is false until the paths are resolved', () {
      expect(AppPaths.isReady, isFalse);
      AppPaths.debugSetPaths(videos: '/v/', movies: '/v/Movies/', internal: '/i');
      expect(AppPaths.isReady, isTrue);
    });
  });
}
