import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/platform/plugin_picker_gateway.dart';

import '../../support/support.dart';

/// What the system picker was asked for, and what it answers.
class _ImagePicker extends Fake implements ImagePicker {
  Object? answer;
  final List<String> asked = <String>[];
  ({double? maxWidth, double? maxHeight, int? quality, CameraDevice device})?
  imageOptions;
  LostDataResponse lost = LostDataResponse.empty();

  Future<XFile?> _answer() async => switch (answer) {
    final XFile file => file,
    final Exception error => throw error,
    _ => null,
  };

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) {
    asked.add('video ${source.name}${maxDuration == null ? '' : ' limited'}');
    return _answer();
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    asked.add('image ${source.name}');
    imageOptions = (
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: imageQuality,
      device: preferredCameraDevice,
    );
    return _answer();
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    asked.add('lost');
    return lost;
  }
}

void main() {
  late _ImagePicker imagePicker;

  setUp(() => imagePicker = _ImagePicker());

  PluginPickerGateway gateway({bool isAndroid = true}) => PluginPickerGateway(
    imagePicker: imagePicker,
    clock: FakeClock(DateTime(2024, 1, 5, 10)),
    isAndroid: isAndroid,
    logger: memoryLogger(MemoryLogSink()),
  );

  test(
    'the system picker and the system camera: a file is picked, nothing '
    'is a cancel, a refusal a denial, any other failure unavailable',
    () async {
      final List<
        (String, Future<PickerOutcome> Function(), Object?, PickerOutcome)
      >
      rows =
          <(String, Future<PickerOutcome> Function(), Object?, PickerOutcome)>[
            (
              'video gallery',
              () => gateway().pickWithSystemPicker(media: PickerMedia.video),
              XFile('/cache/image_picker_1.mp4'),
              const Picked('/cache/image_picker_1.mp4'),
            ),
            (
              'image gallery',
              () => gateway().pickWithSystemPicker(media: PickerMedia.photo),
              XFile('/cache/image_picker_2.jpg'),
              const Picked('/cache/image_picker_2.jpg'),
            ),
            (
              'video gallery',
              () => gateway().pickWithSystemPicker(media: PickerMedia.video),
              null,
              const PickCancelled(),
            ),
            (
              'image gallery',
              () => gateway().pickWithSystemPicker(media: PickerMedia.photo),
              PlatformException(code: 'photo_access_denied'),
              const PickDenied(),
            ),
            (
              'image gallery',
              () => gateway().pickWithSystemPicker(media: PickerMedia.photo),
              PlatformException(code: 'invalid_image'),
              const PickUnavailable(),
            ),
            (
              'video camera',
              () => gateway().recordWithSystemCamera(),
              XFile('/cache/REC_camera.mp4'),
              const Picked('/cache/REC_camera.mp4'),
            ),
            (
              'video camera',
              () => gateway().recordWithSystemCamera(),
              PlatformException(code: 'camera_access_denied'),
              const PickDenied(),
            ),
          ];

      for (final (
            String asked,
            Future<PickerOutcome> Function() pick,
            Object? answer,
            PickerOutcome expected,
          )
          in rows) {
        imagePicker
          ..answer = answer
          ..asked.clear();

        expect(await pick(), expected, reason: '$asked answering $answer');
        expect(imagePicker.asked, <String>[asked]);
      }
    },
  );

  test('a profile photo is at most 512 px, from the selfie lens when '
      'taken', () async {
    imagePicker.answer = XFile('/cache/face.jpg');

    expect(
      await gateway().pickProfilePhoto(origin: PhotoOrigin.camera),
      const Picked('/cache/face.jpg'),
    );
    expect(imagePicker.asked, <String>['image camera']);
    expect(imagePicker.imageOptions, (
      maxWidth: 512.0,
      maxHeight: 512.0,
      quality: 90,
      device: CameraDevice.front,
    ));

    await gateway().pickProfilePhoto(origin: PhotoOrigin.gallery);
    expect(imagePicker.asked.last, 'image gallery');
  });

  // The native camera is forced on API 26–28, the phones most likely to
  // lose the app while the camera is open.
  test('a pick the system kept after the app was killed comes back once '
      'asked at launch, is nothing when there is none, and is never asked '
      'for on iOS, which keeps none', () async {
    expect(await gateway().retrieveLostPick(), isNull);

    imagePicker.lost = LostDataResponse(
      file: XFile('/cache/REC_lost.mp4'),
      type: RetrieveType.video,
    );
    expect(
      await gateway().retrieveLostPick(),
      const LostPick(path: '/cache/REC_lost.mp4', media: PickerMedia.video),
    );

    imagePicker.asked.clear();
    expect(await gateway(isAndroid: false).retrieveLostPick(), isNull);
    expect(imagePicker.asked, isEmpty);
  });
}
