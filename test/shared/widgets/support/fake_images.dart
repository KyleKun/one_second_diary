import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Makes [FakeImages] for this test file and empties the image cache after
/// each test, so providers never leak between tests. Call it from `main`.
void useFakeImages() {
  setUpAll(FakeImages.init);
  tearDown(() => PaintingBinding.instance.imageCache.clear());
}

/// Test images for widgets that show photos and thumbnails, made once per
/// test file (see [useFakeImages]), outside the fake clock.
abstract final class FakeImages {
  static ui.Image? _landscape;
  static ui.Image? _portrait;

  static ui.Image get landscape => _landscape!;

  static ui.Image get portrait => _portrait!;

  /// Creates the images. Call it from `setUpAll`.
  static Future<void> init() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _landscape ??= await createTestImage(width: 16, height: 9);
    _portrait ??= await createTestImage(width: 9, height: 16);
  }
}

/// An image provider whose load the test drives: [complete] delivers an
/// image, [fail] reports a decoding error. It ignores the requested decode
/// size, so it also works behind `ResizeImage`.
class FakeImageProvider extends ImageProvider<FakeImageProvider> {
  FakeImageProvider([this.name = 'fake']);

  /// A provider that is already loaded: the first frame arrives
  /// synchronously, as it does for an image in the cache.
  FakeImageProvider.ready(ui.Image image, [this.name = 'ready']) {
    _ready = ImageInfo(image: image.clone());
  }

  /// A readable name for failure messages.
  final String name;

  final Completer<ImageInfo> _completer = Completer<ImageInfo>();
  ImageInfo? _ready;

  /// How many times the image was requested.
  int loads = 0;

  void complete(ui.Image image) =>
      _completer.complete(ImageInfo(image: image.clone()));

  void fail() => _completer.completeError(StateError('$name is broken'));

  @override
  Future<FakeImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FakeImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    FakeImageProvider key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    final ready = _ready;
    return OneFrameImageStreamCompleter(
      ready == null
          ? _completer.future
          : SynchronousFuture<ImageInfo>(ready.clone()),
    );
  }

  @override
  String toString() => 'FakeImageProvider($name)';
}
