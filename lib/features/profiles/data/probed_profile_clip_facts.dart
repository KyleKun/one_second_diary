import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_of_probe.dart';
import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// [ProfileClipFacts] over the clip scanner (which lists any profile
/// folder, listed or not) and the media engine's probe.
///
/// A plain class (not final), so tests can fake it.
class ProbedProfileClipFacts implements ProfileClipFacts {
  ProbedProfileClipFacts({
    required this._scanner,
    required this._engine,
    required this._paths,
    required this._logger,
  });

  final ClipScanner _scanner;
  final MediaEngine _engine;
  final AppPaths _paths;
  final AppLogger _logger;

  static const String _tag = 'PROFILES';

  @override
  Future<List<ClipMeta>> newestOf(ProfileKey profile, {int count = 3}) async {
    final List<ClipMeta> facts = <ClipMeta>[];
    try {
      final ClipScan scan = await _scanner.scan(profile);
      for (final ClipRef ref in scan.index.newestFirst.take(count)) {
        final ClipProbe probe = await _engine.probe(
          _paths.absoluteFromVideos(ref.relPath),
        );
        facts.add(clipMetaOfProbe(probe, subtitleText: ''));
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not read the newest clips of "${profile.albumLabel}"',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return facts;
  }
}
