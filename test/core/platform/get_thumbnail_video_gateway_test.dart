import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/get_thumbnail_video_gateway.dart';

import '../../support/support.dart';

const MethodChannel _channel = MethodChannel('video_thumbnail');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late MemoryLogSink sink;
  late GetThumbnailVideoGateway gateway;
  late List<MethodCall> calls;

  /// Answers like the plugin: writes the JPEG where it was asked to and
  /// returns its path.
  void answerLikeThePlugin() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
        calls.add(call);
        final String path =
            (call.arguments as Map<Object?, Object?>)['path']! as String;
        File(path).writeAsBytesSync(FakeThumbnailGateway.jpegBytes);
        return path;
      });

  setUp(() async {
    root = await createTempRoot();
    sink = MemoryLogSink();
    calls = <MethodCall>[];
    gateway = GetThumbnailVideoGateway(logger: memoryLogger(sink));
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );
  });

  test('asks the plugin for a JPEG file at the exact path, bounded both '
      'ways, after creating its folder; refuses an output that is not a .jpg '
      'file (the plugin would treat it as a folder and name the file after '
      'the video)', () async {
    answerLikeThePlugin();
    final String output = '${root.path}/thumbs/a_1_2_200.jpg';

    await expectLater(
      gateway.writeThumbnail(
        videoPath: '/videos/2024-01-05.mp4',
        outputPath: '${root.path}/thumbs',
        maxWidth: 200,
        maxHeight: 200,
        quality: 75,
        timeMs: 0,
      ),
      throwsArgumentError,
    );
    expect(calls, isEmpty);

    final String? written = await gateway.writeThumbnail(
      videoPath: '/videos/2024-01-05.mp4',
      outputPath: output,
      maxWidth: 200,
      maxHeight: 200,
      quality: 75,
      timeMs: 0,
    );

    expect(written, output);
    expect(File(output).existsSync(), isTrue);
    expect(calls.single.method, 'file');
    expect(calls.single.arguments, <String, Object?>{
      'video': '/videos/2024-01-05.mp4',
      'headers': null,
      'path': output,
      'format': 0, // ImageFormat.JPEG
      'maxh': 200,
      'maxw': 200,
      'timeMs': 0,
      'quality': 75,
    });
  });

  test('a frame the plugin cannot extract gives null, with its reason in '
      'the log', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _channel,
          (MethodCall call) async => throw PlatformException(
            code: 'exception',
            message: 'java.lang.NullPointerException',
          ),
        );

    final String? written = await gateway.writeThumbnail(
      videoPath: '/videos/2024-01-05.mp4',
      outputPath: '${root.path}/thumbs/a_1_2_200.jpg',
      maxWidth: 200,
      maxHeight: 200,
      quality: 75,
      timeMs: 0,
    );

    expect(written, isNull);
    expect(
      sink.lines.single,
      contains(
        '[THUMBNAILS] No frame from '
        '/videos/2024-01-05.mp4',
      ),
    );
    expect(sink.lines.single, contains('NullPointerException'));
  });
}
