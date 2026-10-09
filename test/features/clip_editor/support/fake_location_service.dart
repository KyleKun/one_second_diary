import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';

/// Tokyo, as the fake finds it.
const LocationFound tokyo = LocationFound(
  position: GeoPosition(latitude: 35.71, longitude: 139.79),
  placeName: 'Tokyo, Japan',
);

/// A [LocationService] whose lookups the test answers.
///
/// Each `locate` waits for an answer: [answer] completes the oldest lookup
/// still waiting. Scripted [answers] are given at once instead, in order.
/// [locales] records the language of every lookup.
class FakeLocationService extends Fake implements LocationService {
  final Queue<LocationResult> answers = Queue<LocationResult>();
  final List<String> locales = <String>[];
  final Queue<Completer<LocationResult>> _waiting =
      Queue<Completer<LocationResult>>();

  /// How many lookups wait for an answer.
  int get waiting => _waiting.length;

  @override
  Future<LocationResult> locate({required String localeIdentifier}) {
    locales.add(localeIdentifier);
    if (answers.isNotEmpty) {
      return Future<LocationResult>.value(answers.removeFirst());
    }
    final Completer<LocationResult> lookup = Completer<LocationResult>();
    _waiting.add(lookup);
    return lookup.future;
  }

  /// Answers the oldest lookup still waiting with [result], at once: for
  /// widget tests, which pump the answer through themselves.
  void answerNow(LocationResult result) =>
      _waiting.removeFirst().complete(result);

  /// Answers the oldest lookup still waiting with [result], and lets the
  /// event queue run (unit tests).
  Future<void> answer(LocationResult result) async {
    await pumpEventQueue();
    _waiting.removeFirst().complete(result);
    await pumpEventQueue();
  }
}
