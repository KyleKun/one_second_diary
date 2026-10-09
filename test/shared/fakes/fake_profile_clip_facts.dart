import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A [ProfileClipFacts] answering [facts] per profile (newest first);
/// a profile without an entry has no readable clips.
final class FakeProfileClipFacts implements ProfileClipFacts {
  FakeProfileClipFacts({Map<ProfileKey, List<ClipMeta>>? facts})
    : facts = facts ?? <ProfileKey, List<ClipMeta>>{};

  final Map<ProfileKey, List<ClipMeta>> facts;

  /// Every profile asked about, in order.
  final List<ProfileKey> asked = <ProfileKey>[];

  @override
  Future<List<ClipMeta>> newestOf(ProfileKey profile, {int count = 3}) async {
    asked.add(profile);
    return (facts[profile] ?? const <ClipMeta>[]).take(count).toList();
  }
}

/// The facts of a clip saved at [width]×[height] with [codec], for
/// inference tests.
ClipMeta clipFacts({
  int width = 1920,
  int height = 1080,
  String codec = 'h264',
  double fps = 30,
  int channels = 1,
  String? colorTransfer,
}) => ClipMeta(
  width: width,
  height: height,
  codec: codec,
  fps: fps,
  channels: channels,
  colorTransfer: colorTransfer,
);
