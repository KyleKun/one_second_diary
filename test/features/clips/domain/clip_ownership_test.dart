import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';

void main() {
  test("a user's original gallery file is never deleted after a save; files "
      'the app or the platform made for this save are cleaned up', () {
    expect(ClipOwnership.userOriginal.deletableAfterSave, isFalse);
    for (final ClipOwnership ownership in <ClipOwnership>[
      ClipOwnership.cameraTemp,
      ClipOwnership.pickerCopy,
      ClipOwnership.platformExport,
    ]) {
      expect(ownership.deletableAfterSave, isTrue, reason: ownership.name);
    }
  });
}
