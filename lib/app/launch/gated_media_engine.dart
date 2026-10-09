import 'package:one_second_diary/app/launch/media_start_gate.dart';
import 'package:one_second_diary/core/media/media_engine.dart';

/// The app's [MediaEngine]: [init], and so every job (each one awaits it),
/// waits for the launch to open [MediaStartGate].
///
/// Without it, a job the user starts in the first seconds after the first
/// frame would run `init()` itself, emptying the scratch folder while the
/// folder migration stages files there, and the orphan sweep that follows
/// would delete the job's own files.
class GatedMediaEngine extends MediaEngine {
  GatedMediaEngine({
    required this._gate,
    required super.ffmpeg,
    required super.paths,
    required super.logger,
    required super.clock,
    required super.loadAsset,
    required super.isIOS,
    super.freeSpace,
  });

  final MediaStartGate _gate;

  @override
  Future<void> init() async {
    await _gate.opened;
    return super.init();
  }
}
