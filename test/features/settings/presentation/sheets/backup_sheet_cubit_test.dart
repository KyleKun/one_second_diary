// The Backup & restore sheet: the choice first, then the steps; "Look for
// new videos" rescans every profile and counts what was not there before
// plus the date-named files beside the clips; the iOS Files app URL is
// percent-encoded, and a refused open says so.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/domain/app_links.dart';
import 'package:one_second_diary/features/settings/domain/backup_steps.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_state.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _work = ProfileKey('Work');

void main() {
  late FakeClipRepository clips;
  late FakeUrlGateway urls;
  late MemoryLogSink sink;

  setUp(() {
    clips = FakeClipRepository();
    urls = FakeUrlGateway();
    sink = MemoryLogSink();
  });

  tearDown(() => clips.close());

  BackupSheetCubit build({required bool isIOS, required AppPaths paths}) {
    final BackupSheetCubit cubit = BackupSheetCubit(
      clips: clips,
      profiles: FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          testProfile(key: _work),
        ],
      ),
      urls: urls,
      paths: paths,
      logger: memoryLogger(sink),
      isIOS: isIOS,
      originalsBytes: () async => 1234,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('choice → steps of the mode (the import steps read the Originals '
      'size) → back to the choice; scanning counts the new clips of every '
      'profile and the date-named files beside them', () async {
    final AppPaths paths = AppPaths(
      internal: '/data/user/0/app/files',
      videos: '/storage/emulated/0/DCIM/OneSecondDiary',
      temporary: '/data/user/0/app/cache',
      cache: '/data/user/0/app/cache',
    );
    clips.publish(clipIndexOf(_default, <LocalDay>[LocalDay(2024, 1, 5)]));
    clips.publish(clipIndexOf(_work, <LocalDay>[LocalDay(2024, 1, 5)]));
    final BackupSheetCubit cubit = build(isIOS: false, paths: paths);

    expect(cubit.state.stage, BackupSheetStage.choice);
    expect(cubit.state.steps, isEmpty);
    expect(cubit.folderPath, '/storage/emulated/0/DCIM/OneSecondDiary');

    await cubit.choose(BackupMode.bringIn);
    expect(cubit.state.stage, BackupSheetStage.steps);
    expect(
      cubit.state.steps,
      BackupSteps.of(
        platform: BackupPlatform.android,
        mode: BackupMode.bringIn,
      ),
    );
    expect(cubit.state.originalsBytes, 1234);
    expect(cubit.state.showsVideoLink, isFalse);

    // The user copied two clips in and a .mov beside them.
    clips.readableOnRescan(
      clipIndexOf(_default, <LocalDay>[
        LocalDay(2024, 1, 5),
        LocalDay(2024, 1, 6),
        LocalDay(2024, 1, 7),
      ]),
    );
    clips.foreignFiles[_work] = <String>['Profiles/Work/2024-01-08.mov'];
    final List<BackupSheetStage> stages = <BackupSheetStage>[];
    cubit.stream.listen((BackupSheetState state) => stages.add(state.stage));

    await cubit.lookForNewVideos();

    expect(stages, <BackupSheetStage>[
      BackupSheetStage.scanning,
      BackupSheetStage.scanned,
    ]);
    expect(clips.rescanned, <ProfileKey>[_default, _work]);
    expect(
      cubit.state.found,
      const BackupScanFound(newClips: 2, foreignFiles: 1),
    );
    expect(cubit.state.found?.total, 3);

    cubit.back();
    expect(cubit.state.stage, BackupSheetStage.choice);
    expect(cubit.state.mode, isNull);
    expect(cubit.state.steps, isEmpty);

    await cubit.choose(BackupMode.backUp);
    expect(cubit.state.showsVideoLink, isTrue);
    await cubit.watchVideo();
    expect(urls.opened, <Uri>[AppLinks.backupTutorial]);
  });

  test('iOS: Open in Files opens shareddocuments:// on the diary folder '
      'with the path percent-encoded (a space in Application Support); a '
      'refused open is logged and the state says so', () async {
    final AppPaths paths = AppPaths(
      internal: '/var/mobile/Containers/Data/App/X/Library/Application Support',
      videos: '/var/mobile/Containers/Data/App/X/Documents/OneSecondDiary',
      temporary: '/var/mobile/Containers/Data/App/X/tmp',
      cache: '/var/mobile/Containers/Data/App/X/Library/Caches',
    );
    final BackupSheetCubit cubit = build(isIOS: true, paths: paths);
    await cubit.choose(BackupMode.backUp);

    await cubit.openInFiles();
    expect(
      urls.opened.single.toString(),
      'shareddocuments:///var/mobile/Containers/Data/App/X/Documents/OneSecondDiary',
    );
    expect(cubit.state.openInFilesFailed, isFalse);
    expect(
      BackupSteps.filesAppUri('/a/Application Support/b').toString(),
      'shareddocuments:///a/Application%20Support/b',
    );

    urls.result = false;
    await cubit.openInFiles();
    expect(cubit.state.openInFilesFailed, isTrue);
    expect(sink.lines.join(), contains('Could not open the Files app'));

    cubit.back();
    expect(cubit.state.openInFilesFailed, isFalse);
  });
}
