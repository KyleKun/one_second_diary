import 'package:one_second_diary/core/platform/screen_orientation_gateway.dart';

/// A [ScreenOrientationGateway] that remembers what it was told:
/// [landscapeAllowed] is the current rule, [changes] every call in order
/// (`portrait`, `landscape`).
class FakeScreenOrientationGateway implements ScreenOrientationGateway {
  final List<String> changes = <String>[];

  /// Whether the screen may turn sideways now; false until told otherwise.
  bool get landscapeAllowed => changes.isNotEmpty && changes.last == landscape;

  static const String portrait = 'portrait';
  static const String landscape = 'landscape';

  @override
  Future<void> portraitOnly() async => changes.add(portrait);

  @override
  Future<void> allowLandscape() async => changes.add(landscape);
}
