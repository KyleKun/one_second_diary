import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';

/// A [ClipMetadataCache] that answers `recentPlaces` with [recent]: what
/// the clip editor reads for the place sheet's "Recent" chips.
class FakeRecentPlaces extends Fake implements ClipMetadataCache {
  FakeRecentPlaces([this.recent = const <({String place, int count})>[]]);

  List<({String place, int count})> recent;

  @override
  List<({String place, int count})> recentPlaces() => recent;
}
