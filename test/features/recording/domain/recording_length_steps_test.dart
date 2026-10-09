// RecordingLengthSteps: the camera's clip-length slider is non-linear:
// a second at a time to 10 s, then 15, 20, 30, 45
// and 60, with marks at 2, 5, 10, 30 and 60.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/recording/domain/recording_length_steps.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

void main() {
  test('the steps run 2..10 by one, then 15, 20, 30, 45, 60, within the '
      'camera\'s range; the marks are among them', () {
    expect(RecordingLengthSteps.values, <int>[
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      15,
      20,
      30,
      45,
      60,
    ]);
    expect(RecordingLengthSteps.marks, <int>[2, 5, 10, 30, 60]);
    expect(
      RecordingLengthSteps.values.first,
      SettingsRepository.minRecordingSeconds,
    );
    expect(
      RecordingLengthSteps.values.last,
      SettingsRepository.maxRecordingSeconds,
    );
    expect(RecordingLengthSteps.lastIndex, 13);
    for (final int mark in RecordingLengthSteps.marks) {
      expect(RecordingLengthSteps.values, contains(mark));
    }
  });

  test('a length maps to its step\'s index, a stored length between steps '
      'to the nearest one, and an index back to its length within the '
      'list', () {
    // seconds -> index
    final Map<int, int> table = <int, int>{
      2: 0,
      10: 8,
      15: 9,
      60: 13,
      12: 8,
      13: 9,
      41: 11,
      0: 0,
      99: 13,
    };
    for (final MapEntry<int, int> row in table.entries) {
      expect(RecordingLengthSteps.indexOf(row.key), row.value, reason: '$row');
    }
    expect(RecordingLengthSteps.at(9), 15);
    expect(RecordingLengthSteps.at(-1), 2);
    expect(RecordingLengthSteps.at(40), 60);
  });

  // The chip and the sheet show seconds, and minutes past 59 s.
  test('a length reads as seconds up to 59 and as "1:00" from 60', () {
    expect(ClipLengthFormat.showsMinutes(59), isFalse);
    expect(ClipLengthFormat.showsMinutes(60), isTrue);
    expect(ClipLengthFormat.minutes(60), '1:00');
    expect(ClipLengthFormat.minutes(75), '1:15');
  });
}
