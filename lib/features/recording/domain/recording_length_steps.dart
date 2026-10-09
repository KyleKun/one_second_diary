/// The clip lengths the camera's slider offers:
/// one second at a time up to 10, then 15, 20, 30, 45 and 60. The slider
/// indexes this list, so its track is non-linear in seconds and every
/// step is one tick.
abstract final class RecordingLengthSteps {
  /// The lengths, in seconds, in slider order.
  static const List<int> values = <int>[
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
  ];

  /// The lengths labelled under the slider.
  static const List<int> marks = <int>[2, 5, 10, 30, 60];

  /// The index of the step nearest to [seconds] (the first of two equally
  /// near); a stored length between steps lands on the nearest one.
  static int indexOf(int seconds) {
    int nearest = 0;
    for (int index = 1; index < values.length; index++) {
      if ((values[index] - seconds).abs() < (values[nearest] - seconds).abs()) {
        nearest = index;
      }
    }
    return nearest;
  }

  /// The length at [index], kept within the list.
  static int at(int index) => values[index.clamp(0, values.length - 1)];

  /// The last index.
  static int get lastIndex => values.length - 1;
}
