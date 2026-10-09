// Each platform's app folders, for the media engine's argv goldens.
//
// Android has no space in any app folder; iOS keeps app data under
// `Library/Application Support`. An argv built on the iOS folders must have
// the same elements as on Android, with every path whole.

typedef Layout = ({String name, String internal, String videos, String cache});

const String _iosContainer =
    '/var/mobile/Containers/Data/Application/0F3C2A1B-1111-2222-3333-444455556666';

const Layout android = (
  name: 'Android',
  internal: '/data/user/0/com.kylekun.one_second_diary/app_flutter',
  videos: '/storage/emulated/0/DCIM/OneSecondDiary/',
  cache: '/data/user/0/com.kylekun.one_second_diary/cache',
);

const Layout ios = (
  name: 'iOS',
  internal: '$_iosContainer/Library/Application Support',
  videos: '$_iosContainer/Documents/OneSecondDiary/',
  cache: '$_iosContainer/Library/Caches',
);

/// [argv] with every [from] folder replaced by the matching [to] folder. An
/// iOS argv equal to `onLayout(androidArgv, from: android, to: ios)` has the
/// same elements as on Android: no path was split.
List<String> onLayout(
  List<String> argv, {
  required Layout from,
  required Layout to,
}) => <String>[
  for (final String argument in argv)
    argument
        .replaceAll(from.internal, to.internal)
        .replaceAll(from.videos, to.videos)
        .replaceAll(from.cache, to.cache),
];
