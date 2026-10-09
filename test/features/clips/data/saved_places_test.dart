// The places the user saved: the `savedPlaces` preference, read most used
// first, with the name rules of a place and a store that never throws at a
// corrupt record.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';

import '../../../support/support.dart';

void main() {
  late PrefsStore prefs;
  late MemoryLogSink sink;

  Future<SavedPlaces> placesOver(Map<String, Object> stored) async {
    prefs = await openLegacyPrefs(stored);
    sink = MemoryLogSink();
    final SavedPlaces places = SavedPlaces(
      prefs: prefs,
      logger: memoryLogger(sink),
    );
    addTearDown(places.dispose);
    return places;
  }

  test('add, rename, coordinates, touch and remove round-trip through the '
      'preference, which a new instance reads back; changes fires on each '
      'write', () async {
    final SavedPlaces places = await placesOver(<String, Object>{});
    final List<void> changes = <void>[];
    places.changes.listen(changes.add);
    expect(places.read(), isEmpty);

    final SavedPlace home = await places.add('  Home ');
    await places.add('Office', latitude: 48.8566, longitude: 2.3522);

    expect(home, const SavedPlace(name: 'Home'));
    expect(
      SavedPlaces(prefs: prefs, logger: memoryLogger(sink)).read(),
      const <SavedPlace>[
        SavedPlace(name: 'Home'),
        SavedPlace(name: 'Office', latitude: 48.8566, longitude: 2.3522),
      ],
      reason: 'alphabetical while unused',
    );

    await places.touch('home');
    await places.touch('HOME');
    await places.rename('Home', "Grandma's house");
    await places.setCoordinates(
      "grandma's house",
      latitude: 35.71,
      longitude: 139.79,
    );
    await places.clearCoordinates('Office');

    expect(places.read(), const <SavedPlace>[
      SavedPlace(
        name: "Grandma's house",
        latitude: 35.71,
        longitude: 139.79,
        uses: 2,
      ),
      SavedPlace(name: 'Office'),
    ]);
    expect(places.has('office'), isTrue);
    expect(places.find('nowhere'), isNull);

    await places.remove('office');
    await places.remove('nowhere');

    expect(places.read().map((SavedPlace p) => p.name), <String>[
      "Grandma's house",
    ]);
    expect(changes, hasLength(8));
    expect(prefs.read(PrefKeys.savedPlaces), contains('"uses":2'));
    expect(sink.lines, isEmpty);
  });

  test('a name is cleaned, 1 to 60 characters and unique without case; a '
      'refused name is an ArgumentError naming why, and a coordinate alone '
      'is dropped', () async {
    final SavedPlaces places = await placesOver(<String, Object>{});
    await places.add('Home', latitude: 1);

    expect(places.read().single.hasCoordinates, isFalse);
    for (final (String name, SavedPlaceError why)
        in <(String, SavedPlaceError)>[
          ('   ', SavedPlaceError.empty),
          ('x' * 61, SavedPlaceError.tooLong),
          (' home ', SavedPlaceError.duplicate),
        ]) {
      expect(
        () => places.add(name),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'why',
            why.name,
          ),
        ),
        reason: name,
      );
      expect(SavedPlaceName.validate(name, existing: <String>['Home']), why);
    }
    await places.add('x' * 60);
    expect(SavedPlaceName.validate('Home', except: 'home'), isNull);
    expect(() => places.rename('Home', ''), throwsArgumentError);

    await places.rename('Home', 'HOME');

    expect(places.read().first.name, 'HOME', reason: 'a case change');
    expect(places.read(), hasLength(2));
  });

  test('read lists the most used first, then by name', () async {
    final SavedPlaces places = await placesOver(<String, Object>{
      'savedPlaces':
          '[{"name":"Zoo","uses":1},{"name":"beach","uses":3},'
          '{"name":"Alps","uses":1},{"name":"Office","lat":1,"lon":2}]',
    });

    expect(places.read().map((SavedPlace p) => p.name), <String>[
      'beach',
      'Alps',
      'Zoo',
      'Office',
    ]);
  });

  test('a preference that does not decode reads as no places, with one '
      'warning; a record that is not a place is left out', () async {
    final SavedPlaces broken = await placesOver(<String, Object>{
      'savedPlaces': '{"name": "Home"}',
    });

    expect(broken.read(), isEmpty);
    expect(broken.read(), isEmpty);
    expect(sink.lines, hasLength(1));
    expect(sink.lines.single, contains('savedPlaces'));

    final SavedPlaces mixed = await placesOver(<String, Object>{
      'savedPlaces':
          '[{"name":"Home"},{"name":""},{"name":"Office","lat":"x","lon":2},'
          '{"name":"home"},7,{"name":"Beach","uses":-1}]',
    });

    expect(mixed.read(), const <SavedPlace>[
      SavedPlace(name: 'Beach'),
      SavedPlace(name: 'Home'),
    ]);
    expect(sink.lines, hasLength(1));

    await mixed.add('Zoo');

    expect(mixed.read().map((SavedPlace p) => p.name), <String>[
      'Beach',
      'Home',
      'Zoo',
    ], reason: 'a write keeps the readable records');
  });
}
