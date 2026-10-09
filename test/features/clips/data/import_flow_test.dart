import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../shared/fakes/fake_picker_gateway.dart';
import '../../../support/support.dart';

/// The label the flow asks for, spelled out so tests can read it.
String _label({required PickerMedia media, required LocalDay? from}) =>
    '${media.name} ${from?.fileStem ?? 'latest'}';

void main() {
  late FakePickerGateway picker;
  late FakeDeviceInfoGateway deviceInfo;
  late MemoryLogSink log;
  late AppPaths paths;

  final LocalDay today = LocalDay(2024, 1, 5);
  final LocalDay missed = LocalDay(2023, 12, 20);

  setUp(() {
    picker = FakePickerGateway();
    deviceInfo = FakeDeviceInfoGateway();
    log = MemoryLogSink();
  });

  /// The flow over [prefs] on a phone that [isAndroid] or [isIOS].
  Future<ImportFlow> flowOver(
    WidgetTester tester, {
    Map<String, Object>? prefs,
    bool isAndroid = true,
    bool isIOS = false,
  }) async {
    final PrefsStore store = (await tester.runAsync(
      () => openLegacyPrefs(prefs ?? legacyPrefs()),
    ))!;
    paths = (await tester.runAsync(createTestPaths))!;
    return ImportFlow(
      picker: picker,
      settings: SettingsRepository(prefs: store),
      deviceInfo: deviceInfo,
      paths: paths,
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
      logger: memoryLogger(log),
      isAndroid: isAndroid,
      isIOS: isIOS,
      firstCellLabel: _label,
    );
  }

  Future<BuildContext> page(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    return tester.element(find.byType(SizedBox));
  }

  Map<String, Object> prefsWith(Map<String, Object> extra) =>
      legacyPrefs(extra: extra);

  group('Add video', () {
    // The in-app picker hands over the user's own file on Android, which is
    // never deleted. On iOS the picker exports a temp copy, which the save
    // deletes; the system picker gives a cache copy.
    testWidgets(
      'from the in-app picker, an Android pick is the user’s own file; an '
      'iOS pick is a temp export; the system picker gives a cache copy; a '
      'photo is owned as the picker says; a cancel, a refused permission and '
      'an unavailable file each say so',
      (WidgetTester tester) async {
        final ImportFlow android = await flowOver(tester);
        picker.galleryAnswers.add(const Picked('/storage/DCIM/Camera/a.mp4'));
        expect(
          await tester.runAsync(
            () async => android.pickVideo(await page(tester), day: today),
          ),
          const ImportPicked(
            VideoSource(
              path: '/storage/DCIM/Camera/a.mp4',
              ownership: ClipOwnership.userOriginal,
            ),
          ),
        );

        picker.galleryAnswers.add(const Picked('/storage/DCIM/Camera/p.jpg'));
        expect(
          await tester.runAsync(
            () async => android.pickPhoto(
              await page(tester),
              day: today,
              format: const ClipFormat.legacy(VideoOrientation.landscape),
            ),
          ),
          const ImportPicked(
            PhotoSource(
              path: '/storage/DCIM/Camera/p.jpg',
              ownership: ClipOwnership.userOriginal,
            ),
          ),
        );
        expect(picker.galleryRequests.last.media, PickerMedia.photo);
        expect(picker.galleryRequests.last.firstCellLabel, 'photo latest');

        final ImportFlow ios = await flowOver(
          tester,
          isAndroid: false,
          isIOS: true,
        );
        picker.galleryAnswers.add(const Picked('/tmp/export/a.mp4'));
        expect(
          await tester.runAsync(
            () async => ios.pickVideo(await page(tester), day: today),
          ),
          const ImportPicked(
            VideoSource(
              path: '/tmp/export/a.mp4',
              ownership: ClipOwnership.platformExport,
            ),
          ),
        );

        final ImportFlow system = await flowOver(
          tester,
          prefs: prefsWith(<String, Object>{'useExperimentalPicker': false}),
        );
        picker.systemAnswers.add(const Picked('/cache/image_picker_1.mp4'));
        final int galleryRequests = picker.galleryRequests.length;
        expect(
          await tester.runAsync(
            () async => system.pickVideo(await page(tester), day: today),
          ),
          const ImportPicked(
            VideoSource(
              path: '/cache/image_picker_1.mp4',
              ownership: ClipOwnership.pickerCopy,
            ),
          ),
        );
        expect(picker.systemRequests, <PickerMedia>[PickerMedia.video]);
        expect(picker.galleryRequests, hasLength(galleryRequests));

        // A cancel, a refused permission and an unavailable file each say so.
        {
          final ImportFlow flow = await flowOver(tester);
          picker.galleryAnswers.addAll(<PickerOutcome>[
            const PickCancelled(),
            const PickDenied(),
            const PickUnavailable(),
          ]);

          final List<ImportResult> results = <ImportResult>[
            for (int i = 0; i < 3; i++)
              (await tester.runAsync(
                () async => flow.pickVideo(await page(tester), day: today),
              ))!,
          ];

          expect(results, const <ImportResult>[
            ImportCancelled(),
            ImportDenied(),
            ImportUnavailable(),
          ]);
        }
      },
    );

    // The filter only narrows a past day, and only when "Use date filter"
    // is on.
    testWidgets('the date filter starts the picker at a past day; without '
        'it the picker shows the latest', (WidgetTester tester) async {
      final ImportFlow flow = await flowOver(
        tester,
        prefs: prefsWith(<String, Object>{
          'useFilterInExperimentalPicker': true,
        }),
      );

      await tester.runAsync(
        () async => flow.pickVideo(await page(tester), day: missed),
      );
      await tester.runAsync(
        () async => flow.pickVideo(await page(tester), day: today),
      );

      expect(picker.galleryRequests, <GalleryPickRequest>[
        (
          media: PickerMedia.video,
          from: DateTime(2023, 12, 20),
          firstCellLabel: 'video 2023-12-20',
        ),
        (media: PickerMedia.video, from: null, firstCellLabel: 'video latest'),
      ]);

      // Without the date filter, the picker shows the latest.
      final ImportFlow unfiltered = await flowOver(tester);
      await tester.runAsync(
        () async => unfiltered.pickVideo(await page(tester), day: missed),
      );
      expect(picker.galleryRequests.last.from, isNull);
    });
  });

  // The source must never be the destination.
  group('the self-import guard', () {
    testWidgets('refuses the very clip a replace would overwrite, under any '
        'spelling', (WidgetTester tester) async {
      final ImportFlow flow = await flowOver(tester);
      final File clip = (await tester.runAsync(
        () => seedClip(paths, ProfileKey.defaultProfile, today),
      ))!;
      picker.galleryAnswers.add(Picked(clip.path));
      final ClipRef ref = ClipRef(
        profile: ProfileKey.defaultProfile,
        relPath: '2024-01-05.mp4',
      );

      final ImportResult result = (await tester.runAsync(
        () async => flow.pickVideo(
          await page(tester),
          day: today,
          mode: ReplaceClip(ref),
        ),
      ))!;

      expect(result, const ImportRejected());
      expect(log.lines.single, contains('[IMPORT]'));

      // Another spelling of that clip is the same clip.
      final Link alias = (await tester.runAsync(
        () => Link('${clip.parent.parent.path}/alias.mp4').create(clip.path),
      ))!;
      picker.galleryAnswers.add(Picked(alias.path));

      final ImportResult aliased = (await tester.runAsync(
        () async => flow.pickVideo(
          await page(tester),
          day: today,
          mode: ReplaceClip(
            ClipRef(
              profile: ProfileKey.defaultProfile,
              relPath: '2024-01-05.mp4',
            ),
          ),
        ),
      ))!;

      expect(aliased, const ImportRejected());
    });

    testWidgets('lets a clip be added to its own day again as a new clip', (
      WidgetTester tester,
    ) async {
      final ImportFlow flow = await flowOver(tester);
      final File clip = (await tester.runAsync(
        () => seedClip(paths, ProfileKey.defaultProfile, today),
      ))!;
      picker.galleryAnswers.add(Picked(clip.path));

      final ImportResult result = (await tester.runAsync(
        () async => flow.pickVideo(await page(tester), day: today),
      ))!;

      expect(result, isA<ImportPicked>());
    });
  });

  group('the system camera', () {
    testWidgets(
      'is used below Android 10, and when S3 forces it; it is required '
      'below Android 10, whatever S3 says; it records a camera temp the '
      'save may delete',
      (WidgetTester tester) async {
        deviceInfo.sdkInt = 28;
        expect(await (await flowOver(tester)).usesSystemCamera(), isTrue);

        deviceInfo.sdkInt = 29;
        expect(await (await flowOver(tester)).usesSystemCamera(), isFalse);
        expect(
          await (await flowOver(
            tester,
            prefs: prefsWith(<String, Object>{'forceNativeCamera': true}),
          )).usesSystemCamera(),
          isTrue,
        );

        deviceInfo.sdkInt = null;
        expect(
          await (await flowOver(
            tester,
            isAndroid: false,
            isIOS: true,
          )).usesSystemCamera(),
          isFalse,
        );

        // The settings show "Force native camera" on and locked there.
        deviceInfo.sdkInt = 28;
        expect(await (await flowOver(tester)).systemCameraRequired(), isTrue);

        deviceInfo.sdkInt = 29;
        expect(
          await (await flowOver(
            tester,
            prefs: prefsWith(<String, Object>{'forceNativeCamera': true}),
          )).systemCameraRequired(),
          isFalse,
        );

        // Records a camera temp the save may delete.
        {
          final ImportFlow flow = await flowOver(tester);
          picker.cameraAnswers.add(const Picked('/cache/REC_camera.mp4'));

          final ImportResult result = (await tester.runAsync(
            flow.recordWithSystemCamera,
          ))!;

          expect(
            result,
            const ImportPicked(
              VideoSource(
                path: '/cache/REC_camera.mp4',
                ownership: ClipOwnership.cameraTemp,
              ),
            ),
          );
        }
      },
    );
  });

  // What Android kept while it had killed the app.
  group('a pick lost while the app was away', () {
    // A clip belongs to the day recording stopped, when the camera wrote
    // the file.
    testWidgets('a video comes back as a camera temp of the day it was '
        'recorded; a photo as a picker copy, for today when its file says '
        'nothing', (WidgetTester tester) async {
      final ImportFlow flow = await flowOver(tester);
      final File recording = (await tester.runAsync(() async {
        final File file = File('${paths.temporaryDir}/REC_lost.mp4');
        await file.create(recursive: true);
        await file.setLastModified(DateTime(2024, 1, 4, 23, 59));
        return file;
      }))!;
      picker.lost = LostPick(path: recording.path, media: PickerMedia.video);

      expect(
        await tester.runAsync(flow.recoverLostPick),
        RecoveredClip(
          source: VideoSource(
            path: recording.path,
            ownership: ClipOwnership.cameraTemp,
          ),
          day: LocalDay(2024, 1, 4),
        ),
      );
      expect(await tester.runAsync(flow.recoverLostPick), isNull);

      // A photo comes back as a picker copy, for today when its file says
      // nothing.
      picker.lost = const LostPick(
        path: '/cache/image_picker_2.jpg',
        media: PickerMedia.photo,
      );

      expect(
        await tester.runAsync(flow.recoverLostPick),
        RecoveredClip(
          source: const PhotoSource(
            path: '/cache/image_picker_2.jpg',
            ownership: ClipOwnership.pickerCopy,
          ),
          day: today,
        ),
      );
    });
  });
}
