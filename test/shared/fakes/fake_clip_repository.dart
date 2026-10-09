import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A [ClipRepository] whose snapshots the test publishes ([publish], [fail])
/// and which records what it was asked to do.
///
/// [watch] behaves like the real one: the current snapshot on listen, then
/// every new one (and every failure) for that profile. [journal], when
/// given, gets `clips.<method>` entries in call order.
class FakeClipRepository extends Fake implements ClipRepository {
  FakeClipRepository({this.journal});

  final List<String>? journal;

  final Map<ProfileKey, ClipIndex> _snapshots = <ProfileKey, ClipIndex>{};
  final StreamController<(ProfileKey, ClipIndex?, Object?)> _updates =
      StreamController<(ProfileKey, ClipIndex?, Object?)>.broadcast();

  /// The profiles [rescan] was called for, in order.
  final List<ProfileKey> rescanned = <ProfileKey>[];

  /// The profiles [profileRemoved] was called for, in order.
  final List<ProfileKey> removed = <ProfileKey>[];

  /// The `active` argument of each [rescanChanged] call.
  final List<ProfileKey> rescannedChangedFor = <ProfileKey>[];

  /// What [foreignFilesOf] answers per profile (the date-named files
  /// beside the clips a scan found).
  final Map<ProfileKey, List<String>> foreignFiles =
      <ProfileKey, List<String>>{};

  /// The relPaths [privateClipsKnown] and [privacyKnown] marked private
  /// and not public since.
  final Set<String> private = <String>{};

  /// The tags [clipTagsKnown] and [tagsKnown] gave, by relPath.
  final Map<String, List<String>> tags = <String, List<String>>{};

  /// The relPaths [foreignClipsKnown] and [schemaKnown] marked as not made
  /// by the app, and not the app's since.
  final Set<String> foreign = <String>{};

  /// Each set [sourcesKnown] was given, in order (the Originals folder's
  /// names scans).
  final List<Set<String>> sources = <Set<String>>[];

  /// The arguments of each [loadAll] call.
  final List<({ProfileKey active, List<ProfileKey> profiles})> loads =
      <({ProfileKey active, List<ProfileKey> profiles})>[];

  @override
  Map<ProfileKey, ClipIndex> get snapshots =>
      Map<ProfileKey, ClipIndex>.unmodifiable(_snapshots);

  /// Makes [index] its profile's snapshot, marked with what
  /// [privateClipsKnown] / [privacyKnown], [clipTagsKnown] / [tagsKnown]
  /// and [foreignClipsKnown] / [schemaKnown] told (as the real repository
  /// marks every snapshot it publishes), and tells its watchers.
  void publish(ClipIndex index) {
    final ClipIndex marked = _marked(index);
    _snapshots[index.profile] = marked;
    _updates.add((index.profile, marked, null));
  }

  /// [index] with the fake's marks added to its own (an index built with
  /// its own `private`, `tags` or `foreign` keeps them).
  ClipIndex _marked(ClipIndex index) {
    if (private.isEmpty && tags.isEmpty && foreign.isEmpty) return index;
    final Set<String> allPrivate = <String>{...private};
    final Set<String> allForeign = <String>{...foreign};
    final Map<String, List<String>> allTags = <String, List<String>>{};
    for (final ClipRef ref in <ClipRef>[
      ...index.newestFirst,
      ...index.hiddenDuplicates,
    ]) {
      if (index.isPrivate(ref)) allPrivate.add(ref.relPath);
      if (index.isForeign(ref)) allForeign.add(ref.relPath);
      final List<String> own = index.tagsOf(ref);
      if (own.isNotEmpty) allTags[ref.relPath] = own;
    }
    allTags.addAll(tags);
    return index
        .withPrivate(allPrivate)
        .withClipTags(allTags)
        .withForeign(allForeign);
  }

  /// Reports a failed scan of [profile] to its watchers.
  void fail(ProfileKey profile, Object error) =>
      _updates.add((profile, null, error));

  /// The next [rescan] of [index]'s profile reads [index] (a folder that
  /// could not be read can be again) and publishes it, as the real one does.
  void readableOnRescan(ClipIndex index) => _onRescan[index.profile] = index;

  final Map<ProfileKey, ClipIndex> _onRescan = <ProfileKey, ClipIndex>{};

  @override
  ClipIndex? snapshotOf(ProfileKey profile) => _snapshots[profile];

  @override
  void sourcesKnown(Iterable<String> relPaths) {
    journal?.add('clips.sourcesKnown');
    sources.add(relPaths.toSet());
    for (final MapEntry<ProfileKey, ClipIndex> entry in _snapshots.entries) {
      _snapshots[entry.key] = entry.value.withSources(sources.last);
    }
  }

  @override
  List<String> foreignFilesOf(ProfileKey profile) =>
      foreignFiles[profile] ?? const <String>[];

  @override
  Stream<ClipIndex> watch(ProfileKey profile) =>
      Stream<ClipIndex>.multi((MultiStreamController<ClipIndex> listener) {
        final ClipIndex? current = _snapshots[profile];
        if (current != null) listener.add(current);
        final StreamSubscription<(ProfileKey, ClipIndex?, Object?)> updates =
            _updates.stream
                .where(((ProfileKey, ClipIndex?, Object?) u) => u.$1 == profile)
                .listen(((ProfileKey, ClipIndex?, Object?) u) {
                  final (_, ClipIndex? index, Object? error) = u;
                  if (index != null) listener.add(index);
                  if (error != null) listener.addError(error);
                });
        listener.onCancel = updates.cancel;
      });

  @override
  Future<void> loadAll({
    required ProfileKey active,
    required Iterable<ProfileKey> profiles,
  }) async {
    journal?.add('clips.loadAll');
    loads.add((active: active, profiles: profiles.toList()));
  }

  @override
  Future<ClipIndex> rescan(ProfileKey profile) async {
    journal?.add('clips.rescan');
    rescanned.add(profile);
    final ClipIndex? read = _onRescan.remove(profile);
    if (read != null) publish(read);
    return _snapshots[profile] ?? ClipIndex.empty(profile);
  }

  @override
  Future<void> rescanChanged({required ProfileKey active}) async {
    journal?.add('clips.rescanChanged');
    rescannedChangedFor.add(active);
  }

  @override
  void profileRemoved(ProfileKey profile) {
    journal?.add('clips.profileRemoved');
    removed.add(profile);
    _snapshots.remove(profile);
    _updates.add((profile, ClipIndex.empty(profile), null));
  }

  @override
  void privateClipsKnown(Iterable<String> relPaths) {
    private.addAll(relPaths);
    for (final ClipIndex index in _snapshots.values.toList()) {
      final ClipIndex marked = index.withPrivate(private);
      if (!identical(marked, index)) publish(marked);
    }
  }

  @override
  void privacyKnown(String relPath, {required bool private}) {
    if (private) {
      this.private.add(relPath);
    } else {
      this.private.remove(relPath);
    }
    for (final ClipIndex index in _snapshots.values.toList()) {
      final ClipIndex marked = index.withPrivacy(relPath, private: private);
      if (!identical(marked, index)) publish(marked);
    }
  }

  @override
  void clipTagsKnown(Map<String, List<String>> tagsByRelPath) {
    tags.addAll(tagsByRelPath);
    for (final ClipIndex index in _snapshots.values.toList()) {
      final ClipIndex tagged = index.withClipTags(tags);
      if (!identical(tagged, index)) publish(tagged);
    }
  }

  @override
  void tagsKnown(String relPath, List<String> tags) {
    if (tags.isEmpty) {
      this.tags.remove(relPath);
    } else {
      this.tags[relPath] = tags;
    }
    for (final ClipIndex index in _snapshots.values.toList()) {
      final ClipIndex tagged = index.withTags(relPath, tags);
      if (!identical(tagged, index)) publish(tagged);
    }
  }

  @override
  void foreignClipsKnown(Iterable<String> relPaths) {
    foreign.addAll(relPaths);
    for (final ClipIndex index in _snapshots.values.toList()) {
      final ClipIndex marked = index.withForeign(foreign);
      if (!identical(marked, index)) publish(marked);
    }
  }

  @override
  void schemaKnown(String relPath, {required bool foreign}) {
    if (foreign) {
      this.foreign.add(relPath);
    } else {
      this.foreign.remove(relPath);
    }
    for (final ClipIndex index in _snapshots.values.toList()) {
      final ClipIndex marked = index.withSchema(relPath, foreign: foreign);
      if (!identical(marked, index)) publish(marked);
    }
  }

  Future<void> close() => _updates.close();
}
