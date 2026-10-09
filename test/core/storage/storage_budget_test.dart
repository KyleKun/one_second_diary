// Free space is checked before every save, movie, conversion and phone check: one policy,
// one floor of 200 MB kept, refused with the shortfall before any work. An unknown free
// space never refuses.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';

void main() {
  const ClipFormat legacy = ClipFormat.legacy(VideoOrientation.landscape);
  const ClipFormat ultra = ClipFormat(
    tier: ResolutionTier.p2160,
    orientation: VideoOrientation.landscape,
    codec: VideoCodec.hevc,
    fps: FrameRate.f60,
    channels: AudioChannels.stereo,
    range: DynamicRange.sdr,
  );

  test('check: ok when the needed bytes fit under the free space minus the '
      '200 MB floor, or when the free space is unknown; else short by what '
      'is missing', () {
    expect(
      StorageBudget.check(needed: 100, free: 300 * 1000 * 1000),
      const StorageOk(),
    );
    expect(StorageBudget.check(needed: 1 << 40, free: null), const StorageOk());
    expect(
      StorageBudget.check(needed: 1000, free: 200 * 1000 * 1000),
      const StorageShort(shortfallBytes: 1000),
    );
    expect(
      StorageBudget.check(needed: 0, free: 150 * 1000 * 1000),
      const StorageShort(shortfallBytes: 50 * 1000 * 1000),
    );
  });

  test('a clip weighs its duration at the format bitrate plus 256 kb/s of '
      'audio: 3 s of legacy 1080p is about 4.6 MB, of 4K60 HEVC about '
      '15.8 MB', () {
    // (12 000 000 + 256 000) / 8 × 3 = 4 596 000.
    expect(StorageBudget.clipBytes(format: legacy, durationMs: 3000), 4596000);
    // (28 000 000 × 1.5 + 256 000) / 8 × 3 = 15 846 000.
    expect(StorageBudget.clipBytes(format: ultra, durationMs: 3000), 15846000);
    expect(StorageBudget.clipBytes(format: legacy, durationMs: 0), 0);
  });

  test('the formulas per job: a save is the source copy plus twice the '
      'clip; a movie the normalised copies plus the movie twice; a '
      'conversion the clips at the target bitrate × 1.1; the check a few '
      'MB', () {
    expect(
      StorageBudget.saveBytes(
        format: legacy,
        durationMs: 3000,
        sourceCopyBytes: 1000,
      ),
      1000 + 2 * 4596000,
    );
    expect(
      const SaveSpaceEstimate(format: legacy, durationMs: 3000).neededBytes,
      2 * 4596000,
    );
    expect(StorageBudget.movieBytes(clipBytes: 1000), 2000);
    expect(
      StorageBudget.movieBytes(clipBytes: 1000, normalisedBytes: 300),
      2300,
    );
    expect(
      StorageBudget.convertBytes(format: legacy, totalDurationMs: 3000),
      (4596000 * 1.1).ceil(),
    );
    expect(StorageBudget.phoneCheckBytes, 8 * 1000 * 1000);
  });

  test('the normalised-copy cache cap is 10 % of the free space, clamped '
      'between 512 MiB and 8 GiB; the minimum when the free space is '
      'unknown', () {
    const int mib = 1024 * 1024;
    expect(StorageBudget.normalizedCacheCap(null), 512 * mib);
    expect(StorageBudget.normalizedCacheCap(1000 * mib), 512 * mib);
    expect(StorageBudget.normalizedCacheCap(20000 * mib), 2000 * mib);
    expect(StorageBudget.normalizedCacheCap(200000 * mib), 8192 * mib);
  });
}
