// A tag's chip colour: one from its name unless the user chose one in
// Settings › Tags; the choices are the `tagColors` preference.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';

import '../../../support/support.dart';

void main() {
  late PrefsStore prefs;
  late MemoryLogSink sink;

  Future<TagColors> colorsOver(Map<String, Object> stored) async {
    prefs = await openLegacyPrefs(stored);
    sink = MemoryLogSink();
    final TagColors colors = TagColors(
      prefs: prefs,
      logger: memoryLogger(sink),
    );
    addTearDown(colors.dispose);
    return colors;
  }

  test('without a choice a tag takes a colour from its name: the same for '
      'every spelling of it, one of the tag swatches (never white, black or '
      'grey)', () async {
    final TagColors colors = await colorsOver(<String, Object>{});

    expect(colors.isChosen('trip'), isFalse);
    expect(colors.indexOf('trip'), TagColors.automaticIndexOf('trip'));
    expect(
      colors.indexOf('  TRIP '),
      colors.indexOf('trip'),
      reason: 'compared by fold',
    );
    expect(
      colors.colorOf('trip'),
      OsdMedia.stampSwatches[colors.indexOf('trip')],
    );
    for (final String tag in <String>['trip', 'bread', 'kids', 'été', 'x']) {
      expect(
        TagColors.swatchIndexes,
        contains(TagColors.automaticIndexOf(tag)),
      );
    }
    expect(TagColors.swatchIndexes, isNot(contains(0)));
    expect(TagColors.swatchIndexes, isNot(contains(1)));
    expect(TagColors.swatchIndexes, isNot(contains(14)));
  });

  test('a chosen colour is stored by fold key, read back by a new instance, '
      'and forgotten again with null; a swatch that is not a tag colour is '
      'refused', () async {
    final TagColors colors = await colorsOver(<String, Object>{});
    final List<void> changes = <void>[];
    colors.changes.listen(changes.add);

    await colors.set('Trip', 9);

    expect(prefs.read(PrefKeys.tagColors), '{"trip":9}');
    expect(colors.isChosen('trip'), isTrue);
    expect(colors.indexOf('TRIP'), 9);
    expect(
      TagColors(prefs: prefs, logger: memoryLogger(sink)).indexOf('trip'),
      9,
    );

    await colors.set('trip', null);

    expect(prefs.read(PrefKeys.tagColors), '{}');
    expect(colors.isChosen('trip'), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(changes, hasLength(2));

    await expectLater(colors.set('trip', 0), throwsRangeError);
    await expectLater(colors.set('trip', 99), throwsRangeError);
    expect(prefs.read(PrefKeys.tagColors), '{}');
  });

  test('a preference that does not decode reads as no choices, with one '
      'warning however often it is read', () async {
    final TagColors colors = await colorsOver(<String, Object>{
      'tagColors': '{"trip": "nine"',
    });

    expect(colors.isChosen('trip'), isFalse);
    expect(colors.indexOf('trip'), TagColors.automaticIndexOf('trip'));
    colors.indexOf('bread');
    expect(
      sink.lines.where((String line) => line.contains('tagColors')),
      hasLength(1),
    );

    // A value of the wrong kind is skipped the same way.
    await prefs.write(PrefKeys.tagColors, '{"trip": 9, "bread": 99}');
    expect(colors.indexOf('trip'), 9);
    expect(colors.isChosen('bread'), isFalse);
  });

  test('a rename moves the chosen colour to the new name, unless that name '
      'already has one', () async {
    final TagColors colors = await colorsOver(<String, Object>{});
    await colors.set('trip', 9);
    await colors.set('kids', 5);

    await colors.rename('trip', 'Journey');

    expect(colors.isChosen('trip'), isFalse);
    expect(colors.indexOf('journey'), 9);

    await colors.rename('journey', 'kids');

    expect(colors.isChosen('journey'), isFalse);
    expect(colors.indexOf('kids'), 5, reason: 'the target keeps its own');

    await colors.rename('nothing', 'kids');
    expect(prefs.read(PrefKeys.tagColors), '{"kids":5}');
  });
}
