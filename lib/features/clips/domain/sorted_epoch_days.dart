/// Binary searches over a sorted, de-duplicated list of epoch days
/// (`LocalDay.epochDay`), the representation the clip index and the Journey
/// statistics share. Every lookup is O(log n), so no screen ever pays per
/// clip for a day query.
extension SortedEpochDays on List<int> {
  /// The first index whose day is `>= day` ([length] when none is).
  int indexAtOrAfter(int day) {
    int low = 0;
    int high = length;
    while (low < high) {
      final int middle = (low + high) >> 1;
      if (this[middle] < day) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  bool containsDay(int day) {
    final int index = indexAtOrAfter(day);
    return index < length && this[index] == day;
  }

  /// How many days lie in the closed range [first]..[last].
  int countBetween(int first, int last) =>
      last < first ? 0 : indexAtOrAfter(last + 1) - indexAtOrAfter(first);
}
