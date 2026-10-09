// The camera page over the real container and the recording routes: the
// hand-over to the clip editor, the lifecycle and back during a take. The
// editor replaces the camera, so what it pops with reaches whoever opened
// the camera.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/router/route_guards.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/pages/camera_page.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_bottom_panel.dart';
import 'package:one_second_diary/features/recording/recording_routes.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

import '../../../../shared/fakes/fake_camera_gateway.dart';
import '../../../../shared/harness/settle.dart';
import '../../../../shared/harness/test_container.dart';

final LocalDay _today = LocalDay(2024, 1, 5);
final RecordArgs _record = RecordArgs(
  day: _today,
  profile: ProfileKey.defaultProfile,
);

/// Where the camera is opened from; keeps what the push completed with.
class _Opener extends StatelessWidget {
  const _Opener({required this.results});

  final List<SavedClip?> results;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton(
          onPressed: () async =>
              results.add(await _record.push<SavedClip>(context)),
          child: const Text('open'),
        ),
      ],
    ),
  );
}

/// Stands in for the clip editor: shows its arguments, pops with a saved
/// clip.
class _EditorProbe extends StatelessWidget {
  const _EditorProbe({required this.args});

  static const Key saveKey = Key('editorProbe.save');

  final EditClipArgs args;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: saveKey,
      onPressed: () => context.pop(
        SavedClip(
          ref: ClipRef(
            profile: args.profile,
            relPath: '${args.day.fileStem}.mp4',
          ),
          undoToken: PublishedUndo(relPath: '${args.day.fileStem}.mp4'),
        ),
      ),
      child: const Text('save'),
    ),
  );
}

void main() {
  late TestContainer container;
  late List<SavedClip?> results;
  late List<EditClipArgs> editorOpenedWith;

  setUp(() async {
    container = await TestContainer.create();
    results = <SavedClip?>[];
    editorOpenedWith = <EditClipArgs>[];
  });

  tearDown(() => container.dispose());

  FakeCameraGateway camera() => container.gateways.camera;

  Future<void> launch(WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/opener',
      routes: <RouteBase>[
        GoRoute(
          path: '/opener',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: _Opener(results: results)),
        ),
        ...recordingRoutes(),
        GoRoute(
          path: AppRoute.editClip.path,
          builder: (BuildContext context, GoRouterState state) {
            final EditClipArgs args = argsOf<EditClipArgs>(state);
            editorOpenedWith.add(args);
            return Scaffold(body: _EditorProbe(args: args));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: OsdTheme.dark(), routerConfig: router),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  RecordingBloc blocOf(WidgetTester tester) =>
      tester.element(find.byType(CameraPage)).read<RecordingBloc>();

  testWidgets('a kept recording opens the clip editor in the camera\'s place, '
      'and the editor\'s saved clip reaches the opener', (
    WidgetTester tester,
  ) async {
    await launch(tester);
    expect(find.byKey(const ValueKey<AppRoute>(AppRoute.record)), findsOne);
    expect(camera().isOpen, isTrue);

    await tester.tap(find.byKey(CameraBottomPanel.shutterKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    expect(find.byType(CameraPage), findsNothing);
    expect(camera().isOpen, isFalse, reason: 'the camera page is gone');
    expect(
      editorOpenedWith.last,
      EditClipArgs(
        source: VideoSource(
          path: camera().current!.recordings.single,
          ownership: ClipOwnership.cameraTemp,
        ),
        day: _today,
        profile: ProfileKey.defaultProfile,
      ),
    );

    await tester.tap(find.byKey(_EditorProbe.saveKey));
    await settle(tester);

    expect(results.single?.ref.day, _today);
    expect(find.text('open'), findsOne);
  });

  // The page tells the bloc when the app goes away. Back cancels the take,
  // a second back closes.
  testWidgets('the camera is released while the app is away, and open again '
      'when it is back; back during a take drops it and stays; back again '
      'closes the camera with nothing saved', (WidgetTester tester) async {
    await launch(tester);
    expect(find.byKey(FakeCameraSession.previewKey), findsOne);

    <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(camera().isOpen, isFalse);

    <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(camera().isOpen, isTrue);
    expect(find.byKey(FakeCameraSession.previewKey), findsOne);

    await tester.tap(find.byKey(CameraBottomPanel.shutterKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.byType(CameraPage), findsOne);
    expect(blocOf(tester).state.status, RecordingStatus.ready);
    expect(camera().current!.isRecording, isFalse);

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.byType(CameraPage), findsNothing);
    expect(results, <SavedClip?>[null]);
    expect(camera().isOpen, isFalse);
  });
}
