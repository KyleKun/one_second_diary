import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A layout with short, readable roots for the pure path rules.
AppPaths _paths() => AppPaths(
  internal: '/data/app',
  videos: '/root/DCIM/OneSecondDiary/',
  temporary: '/data/tmp',
  cache: '/data/cache',
);

/// The same install after a reinstall moved the iOS container.
AppPaths _moved() => AppPaths(
  internal: '/var/mobile/NEW-UUID/Library/Application Support',
  videos: '/var/mobile/NEW-UUID/Documents/OneSecondDiary/',
  temporary: '/var/mobile/NEW-UUID/tmp',
  cache: '/var/mobile/NEW-UUID/Library/Caches',
);

void main() {
  group('storageRootOf', () {
    test('walks up from the app private folder to the storage root, for the '
        'main user, a removable volume and a secondary user', () {
      const String app = 'Android/data/com.kylekun.one_second_diary/files';
      const Map<String, String> rows = <String, String>{
        '/storage/emulated/0/$app': '/storage/emulated/0',
        '/storage/1A2B-3C4D/$app': '/storage/1A2B-3C4D',
        '/storage/emulated/10/$app': '/storage/emulated/10',
        // No Android segment to stop at.
        '': '/fallback',
        '/Android/data/pkg/files': '/fallback',
      };
      for (final MapEntry<String, String> row in rows.entries) {
        expect(
          AppPaths.storageRootOf(row.key, fallback: '/fallback'),
          row.value,
          reason: row.key,
        );
      }
    });
  });

  group('profileVideos', () {
    test('Default (the empty key) lives at the root, a named profile in '
        'Profiles/<key>/', () {
      final AppPaths paths = _paths();

      expect(
        paths.profileVideos(ProfileKey.defaultProfile),
        '/root/DCIM/OneSecondDiary/',
      );
      expect(
        paths.profileVideos(const ProfileKey('Work')),
        '/root/DCIM/OneSecondDiary/Profiles/Work/',
      );
    });
  });

  group('folders', () {
    test('movies, logs and stamp fonts stay where v1.7 keeps them; new '
        'private data sits in internal storage, purgeable data in the OS '
        'temp and cache folders', () {
      final AppPaths paths = AppPaths(
        internal: '/data/app',
        videos: '/root/DCIM/OneSecondDiary',
        temporary: '/data/tmp',
        cache: '/data/cache',
      );

      expect(paths.videos, '/root/DCIM/OneSecondDiary/');
      expect(paths.movies, '/root/DCIM/OneSecondDiary/Movies/');
      expect(paths.logsDir, '/data/app/Logs');
      expect(paths.logsZipPath, '/data/app/logs.zip');
      expect(paths.fontsDir, '/data/app');
      expect(paths.supportIndexDir, '/data/app/index');
      expect(paths.trashDir, '/data/app/trash');
      expect(paths.avatarsDir, '/data/app/avatars');
      expect(paths.scratchDir, '/data/tmp/scratch');
      expect(paths.cacheDir, '/data/cache');
      expect(paths.thumbsDir, '/data/cache/thumbs');
      expect(paths.normalizedDir, '/data/cache/normalized');
    });

    // Beside the diary, never inside it, so the clip scanner never sees it and no folder
    // name inside the diary is reserved.
    test('originals is the sibling folder of the diary on both platforms: '
        'DCIM/OneSecondDiary Originals/ on Android, Documents/OneSecondDiary '
        'Originals/ on iOS, ending with /', () {
      final AppPaths android = AppPaths.fromPlatform(
        isIOS: false,
        documents: '/data/user/0/com.kylekun.one_second_diary/app_flutter',
        applicationSupport: '/data/user/0/com.kylekun.one_second_diary/files',
        externalStorage:
            '/storage/emulated/0/Android/data/com.kylekun.one_second_diary/files',
        temporary: '/data/user/0/com.kylekun.one_second_diary/cache',
        cache: '/data/user/0/com.kylekun.one_second_diary/cache',
      );
      expect(android.videos, '/storage/emulated/0/DCIM/OneSecondDiary/');
      expect(
        android.originals,
        '/storage/emulated/0/DCIM/OneSecondDiary Originals/',
      );

      final AppPaths ios = AppPaths.fromPlatform(
        isIOS: true,
        documents: '/var/mobile/UUID/Documents',
        applicationSupport: '/var/mobile/UUID/Library/Application Support',
        externalStorage: null,
        temporary: '/var/mobile/UUID/tmp',
        cache: '/var/mobile/UUID/Library/Caches',
      );
      expect(ios.videos, '/var/mobile/UUID/Documents/OneSecondDiary/');
      expect(
        ios.originals,
        '/var/mobile/UUID/Documents/OneSecondDiary Originals/',
      );

      expect(_paths().originals, '/root/DCIM/OneSecondDiary Originals/');
      expect(
        AppPaths.forTest(Directory('/tmp/t')).originals,
        '/tmp/t/media/OneSecondDiary Originals/',
      );
      expect(PathNames.originalsFolder, 'OneSecondDiary Originals');
      expect(PathNames.noMedia, '.nomedia');
      // Nothing under it is inside the diary.
      expect(
        () => _paths().relativeToVideos(
          '/root/DCIM/OneSecondDiary Originals/2024-01-05.mp4',
        ),
        throwsArgumentError,
      );
    });
  });

  group('relative paths', () {
    test('relativeToVideos and absoluteFromVideos are inverses', () {
      final AppPaths paths = _paths();

      expect(
        paths.relativeToVideos('/root/DCIM/OneSecondDiary/2024-01-05.mp4'),
        '2024-01-05.mp4',
      );
      const String relative = 'Profiles/José/2024-01-05-2.mp4';
      final String absolute = paths.absoluteFromVideos(relative);
      expect(
        absolute,
        '/root/DCIM/OneSecondDiary/Profiles/José/2024-01-05-2.mp4',
      );
      expect(paths.relativeToVideos(absolute), relative);
    });

    test('a path outside the videos folder, or escaping it, is rejected', () {
      final AppPaths paths = _paths();

      for (final String absolute in <String>[
        '/data/app/2024-01-05.mp4',
        '/root/DCIM/OneSecondDiaryOld/a.mp4',
        '/root/DCIM/OneSecondDiary/../a.mp4',
        '/root/DCIM/OneSecondDiary/',
      ]) {
        expect(
          () => paths.relativeToVideos(absolute),
          throwsArgumentError,
          reason: absolute,
        );
      }
      for (final String relative in <String>[
        '/etc/passwd',
        '../x.mp4',
        'Profiles/../../x.mp4',
        '',
      ]) {
        expect(
          () => paths.absoluteFromVideos(relative),
          throwsArgumentError,
          reason: relative,
        );
      }
    });

    test('survive a reinstall that moves the container', () {
      final String relative = _paths().relativeToVideos(
        '/root/DCIM/OneSecondDiary/2024-01-05.mp4',
      );

      expect(
        _moved().absoluteFromVideos(relative),
        '/var/mobile/NEW-UUID/Documents/OneSecondDiary/2024-01-05.mp4',
      );
    });
  });

  group('internal-relative paths (profile photos)', () {
    test('survive a moved container, and nothing outside the internal '
        'folder resolves', () {
      final AppPaths paths = _paths();

      final String relative = paths.relativeToInternal(
        '/data/app/avatars/default-1.jpg',
      );
      expect(relative, 'avatars/default-1.jpg');
      expect(
        _moved().absoluteFromInternal(relative),
        '/var/mobile/NEW-UUID/Library/Application Support/avatars/default-1.jpg',
      );

      for (final String absolute in <String>[
        '/data/application/x.jpg',
        '/data/app/../x.jpg',
      ]) {
        expect(
          () => paths.relativeToInternal(absolute),
          throwsArgumentError,
          reason: absolute,
        );
      }
      for (final String relative in <String>[
        '/x.jpg',
        'avatars/../../x.jpg',
        '',
      ]) {
        expect(
          () => paths.absoluteFromInternal(relative),
          throwsArgumentError,
          reason: relative,
        );
      }
    });
  });

  group('legacy Android folders (pre-2023 migration source)', () {
    test('sit beside DCIM at the storage root, where v1.0-v1.5 wrote them '
        '(storage_utils.dart:105-116)', () {
      final AppPaths paths = AppPaths(
        internal: '/data/user/0/app/app_flutter',
        videos: '/storage/emulated/0/DCIM/OneSecondDiary/',
        temporary: '/data/tmp',
        cache: '/data/cache',
      );

      expect(paths.legacyAndroidVideos, '/storage/emulated/0/OneSecondDiary/');
      expect(paths.legacyAndroidMovies, '/storage/emulated/0/OSD-Movies/');
    });
  });

  group('albumFor', () {
    test('names the gallery album holding a file as v1.7 set it, keeps a '
        'user-made sub-folder, and rejects a file outside the videos '
        'folder', () {
      final AppPaths paths = _paths();
      const Map<String, String> rows = <String, String>{
        '2024-01-05.mp4': 'OneSecondDiary',
        'Profiles/Work/2024-01-05.mp4': 'OneSecondDiary/Profiles/Work',
        'Movies/OSD-Movie-3-2024-01-05.mp4': 'OneSecondDiary/Movies',
        'trip/2024-01-05.mp4': 'OneSecondDiary/trip',
      };
      for (final MapEntry<String, String> row in rows.entries) {
        expect(
          paths.albumFor('/root/DCIM/OneSecondDiary/${row.key}'),
          row.value,
          reason: row.key,
        );
      }

      expect(() => paths.albumFor('/data/app/x.mp4'), throwsArgumentError);
    });
  });

  group('fromPlatform', () {
    test('iOS keeps clips in Documents and private files in Application '
        'Support; Android keeps clips in DCIM under the storage root and '
        'private files in the app Documents folder', () {
      final AppPaths ios = AppPaths.fromPlatform(
        isIOS: true,
        documents: '/var/mobile/UUID/Documents',
        applicationSupport: '/var/mobile/UUID/Library/Application Support',
        externalStorage: null,
        // What path_provider reports on a device: Caches for both.
        temporary: '/var/mobile/UUID/Library/Caches',
        cache: '/var/mobile/UUID/Library/Caches',
      );
      final AppPaths android = AppPaths.fromPlatform(
        isIOS: false,
        documents: '/data/user/0/com.kylekun.one_second_diary/app_flutter',
        applicationSupport: '/data/user/0/com.kylekun.one_second_diary/files',
        externalStorage:
            '/storage/emulated/0/Android/data/com.kylekun.one_second_diary/files',
        temporary: '/data/user/0/com.kylekun.one_second_diary/cache',
        cache: '/data/user/0/com.kylekun.one_second_diary/cache',
      );

      expect(ios.videos, '/var/mobile/UUID/Documents/OneSecondDiary/');
      expect(ios.movies, '/var/mobile/UUID/Documents/OneSecondDiary/Movies/');
      expect(ios.internal, '/var/mobile/UUID/Library/Application Support');
      expect(ios.scratchDir, '/var/mobile/UUID/Library/Caches/scratch');
      expect(ios.cacheDir, '/var/mobile/UUID/Library/Caches');
      expect(android.videos, '/storage/emulated/0/DCIM/OneSecondDiary/');
      expect(
        android.internal,
        '/data/user/0/com.kylekun.one_second_diary/app_flutter',
      );
    });

    test('Android without a storage root is an error, not a silent move to '
        'private storage, and the error state can name the private folder '
        'v1.7 fell back to', () {
      AppPaths android(String? external) => AppPaths.fromPlatform(
        isIOS: false,
        documents: '/data/app_flutter',
        applicationSupport: '/data/files',
        externalStorage: external,
        temporary: '/data/cache',
        cache: '/data/cache',
      );

      expect(() => android(null), throwsA(isA<StorageException>()));
      expect(
        () => android('/Android/data/pkg/files'),
        throwsA(isA<StorageException>()),
      );
      expect(
        AppPaths.legacyPrivateVideos(
          documents: '/data/user/0/com.kylekun.one_second_diary/app_flutter',
        ),
        '/data/user/0/com.kylekun.one_second_diary/app_flutter/DCIM/'
        'OneSecondDiary/',
      );
    });
  });

  test('createDirectories makes the logs, videos and movies folders', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'osd_app_paths_',
    );
    addTearDown(() => root.delete(recursive: true));
    final AppPaths paths = AppPaths.forTest(root);

    await paths.createDirectories();

    expect(Directory(paths.logsDir).existsSync(), isTrue);
    expect(Directory(paths.videos).existsSync(), isTrue);
    expect(Directory(paths.movies).existsSync(), isTrue);
  });

  // Under `flutter test` no path_provider plugin is registered, so the
  // platform calls fail the way a broken channel would. Bootstrap handles a
  // StorageException from resolve() (its error state); a raw plugin error,
  // or the ParallelWaitError of the concurrent calls, it would not.
  test('resolve: a path_provider failure is a StorageException', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await expectLater(AppPaths.resolve(), throwsA(isA<StorageException>()));
  });
}
