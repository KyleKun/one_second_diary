// TrimSelection: the part of a video the clip keeps: a window of 1 to 60 s,
// the whole source when it is shorter, locked on a source
// of 1.5 s or less, quick cuts that keep the current start, and a saved end
// that is exactly the window's end.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';

void main() {
  test('a source opens on its first [lengthMs], the whole of it when it is '
      'shorter, and on its first 60 s by default or when more is asked', () {
    final TrimSelection short = TrimSelection.initial(sourceMs: 3400);
    expect((short.startMs, short.endMs), (0, 3400));

    final TrimSelection long = TrimSelection.initial(sourceMs: 90000);
    expect((long.startMs, long.lengthMs), (0, 60000));

    // (source, length asked) -> length
    final Map<(int, int), int> table = <(int, int), int>{
      (8000, 1500): 1500,
      (1200, 1500): 1200,
      (8000, 6000): 6000,
      (90000, 61000): 60000,
      (8000, 200): 1000,
    };
    for (final MapEntry<(int, int), int> row in table.entries) {
      final (int source, int asked) = row.key;
      final TrimSelection trim = TrimSelection.initial(
        sourceMs: source,
        lengthMs: asked,
      );
      expect((trim.startMs, trim.lengthMs), (0, row.value), reason: '$row');
    }
  });

  test('a quick cut keeps the current start and sets the length; near the '
      'end it moves the start back; longer than the source it takes the '
      'whole source', () {
    // (source, start, quick cut) -> (start, length)
    final List<((int, int, int), (int, int))> table =
        <((int, int, int), (int, int))>[
          ((8000, 2000, 1500), (2000, 1500)),
          ((6000, 4500, 3000), (3000, 3000)),
          ((2600, 900, 3000), (0, 2600)),
          ((75000, 20000, 60000), (15000, 60000)),
        ];

    for (final ((int source, int start, int cut), (int, int) expected)
        in table) {
      final TrimSelection trim = TrimSelection.initial(
        sourceMs: source,
      ).withLength(1000).movedTo(start).withLength(cut);
      expect((trim.startMs, trim.lengthMs), expected, reason: '$source');
    }
  });

  test('a quick cut is offered when the source is at least that long, to '
      'the ms (D-2)', () {
    final TrimSelection trim = TrimSelection.initial(sourceMs: 1900);

    expect(trim.allows(1000), isTrue);
    expect(trim.allows(1500), isTrue);
    expect(trim.allows(2000), isFalse);
    expect(TrimSelection.initial(sourceMs: 60000).allows(60000), isTrue);
  });

  test('dragging the window or an edge keeps it 1 to 60 s long and inside '
      'the source', () {
    final TrimSelection twoOfFive = TrimSelection.initial(
      sourceMs: 5000,
    ).withLength(2000);
    expect(twoOfFive.movedTo(1200).startMs, 1200);
    expect(twoOfFive.movedTo(4000).startMs, 3000);
    expect(twoOfFive.movedTo(-300).startMs, 0);
    expect(twoOfFive.movedTo(4000).lengthMs, 2000);

    final TrimSelection twoSeconds = TrimSelection.initial(
      sourceMs: 90000,
    ).withLength(2000).movedTo(10000);
    // (start, end) after each drag.
    final Map<String, (TrimSelection, (int, int))> table =
        <String, (TrimSelection, (int, int))>{
          'end edge': (twoSeconds.withEndAt(14200), (10000, 14200)),
          'start edge': (twoSeconds.withStartAt(8700), (8700, 12000)),
          'end edge, under 1 s': (twoSeconds.withEndAt(10400), (10000, 11000)),
          'start edge, under 1 s': (
            twoSeconds.withStartAt(11800),
            (11000, 12000),
          ),
          'end edge, over 60 s': (twoSeconds.withEndAt(80000), (10000, 70000)),
          'start edge, past 60 s back': (
            twoSeconds.movedTo(70000).withStartAt(0),
            (12000, 72000),
          ),
        };
    for (final MapEntry<String, (TrimSelection, (int, int))> row
        in table.entries) {
      final TrimSelection trim = row.value.$1;
      expect((trim.startMs, trim.endMs), row.value.$2, reason: row.key);
    }

    final TrimSelection nearEnd = TrimSelection.initial(
      sourceMs: 6000,
    ).withLength(2000).movedTo(3000);
    expect(nearEnd.withEndAt(7000).endMs, 6000);
    expect(nearEnd.withLength(1000).withStartAt(-500).startMs, 0);
  });

  test('an edge snaps the length to a quick cut within 50 ms; the quick cut '
      'matched is the one of its exact length', () {
    final TrimSelection twoSeconds = TrimSelection.initial(
      sourceMs: 30000,
    ).withLength(2000).movedTo(10000);

    expect(twoSeconds.withEndAt(13040).lengthMs, 3000);
    expect(twoSeconds.withEndAt(12960).lengthMs, 3000);
    expect(twoSeconds.withEndAt(13060).lengthMs, 3060);
    expect(twoSeconds.withEndAt(20030).lengthMs, 10000);
    expect(twoSeconds.withStartAt(10540).lengthMs, 1500);
    expect(twoSeconds.withStartAt(10540).endMs, 12000);

    final TrimSelection trim = TrimSelection.initial(sourceMs: 9000);
    expect(trim.withLength(1500).quickCutMs, 1500);
    expect(trim.withLength(5000).quickCutMs, 5000);
    expect(trim.withEndAt(2300).quickCutMs, isNull);
  });

  // The readout and the render both
  // end exactly where the window ends.
  test('what is saved ends exactly where the window ends, never past the '
      'source', () {
    final TrimSelection oneSecond = TrimSelection.initial(
      sourceMs: 6000,
    ).withLength(1000).movedTo(2000);

    expect(oneSecond.savedEndMs, 3000);
    expect(oneSecond.savedLengthMs, 1000);

    final TrimSelection atTheEnd = oneSecond.movedTo(5000);
    expect(atTheEnd.savedEndMs, 6000);
    expect(atTheEnd.savedLengthMs, 1000);

    final TrimSelection whole = TrimSelection.initial(sourceMs: 1234);
    expect(whole.savedEndMs, 1234);
  });

  test('a source of 1.5 s or less is locked to the whole clip: no quick '
      'cut, no move; a longer one is not', () {
    final TrimSelection trim = TrimSelection.initial(sourceMs: 1500);

    expect(trim.locked, isTrue);
    expect(trim.allows(1000), isFalse);
    expect(trim.withLength(1000), trim);
    expect(trim.movedTo(300), trim);
    expect(TrimSelection.initial(sourceMs: 1501).locked, isFalse);
  });

  // A recipe's window ("Edit again") is applied where it still fits.
  test('a window fitted from a recipe keeps its start and end within the '
      'source and the rules; one that starts past the source is dropped', () {
    final TrimSelection source = TrimSelection.initial(
      sourceMs: 8000,
      lengthMs: 1500,
    );

    final TrimSelection kept = source.fitted(startMs: 2000, endMs: 4500);
    expect((kept.startMs, kept.endMs), (2000, 4500));

    final TrimSelection pastTheEnd = source.fitted(startMs: 6000, endMs: 9500);
    expect((pastTheEnd.startMs, pastTheEnd.endMs), (6000, 8000));

    final TrimSelection tooShort = source.fitted(startMs: 1000, endMs: 1200);
    expect(tooShort.lengthMs, 1000);

    expect(source.fitted(startMs: 8000, endMs: 9000), source);
    expect(source.fitted(startMs: -1, endMs: 1000), source);
    expect(source.fitted(startMs: 3000, endMs: 3000), source);
    final TrimSelection locked = TrimSelection.initial(sourceMs: 1200);
    expect(locked.fitted(startMs: 100, endMs: 1100), locked);
  });
}
