// GOLDEN: the three range conversion chains, letter for letter, and which one a render
// takes from the source's probed transfer into the target's range. SDR into SDR and HLG
// into HLG take none.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/range_filter.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/color_transfer.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

const ClipFormat _hlg = ClipFormat(
  tier: ResolutionTier.p1080,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f30,
  channels: AudioChannels.stereo,
  range: DynamicRange.hlg,
);

void main() {
  test('the chains: the plan\'s tone map (ending in yuv420p), SDR to HLG '
      'with the input tagged BT.709 and SDR white at 75 % HLG, PQ to HLG at '
      'a 1000 nit peak', () {
    expect(
      RangeFilter.hdrToSdr,
      'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,'
      'tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p',
    );
    expect(
      RangeFilter.sdrToHlg,
      'zscale=pin=bt709:tin=bt709:min=bt709:t=linear:npl=100,'
      'format=gbrpf32le,exposure=exposure=-2.3,zscale=p=bt2020,'
      'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le',
    );
    expect(
      RangeFilter.pqToHlg,
      'zscale=t=linear:npl=1000,format=gbrpf32le,'
      'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le',
    );
  });

  test('which conversion a source takes into each range: none for SDR '
      'into SDR (null, bt709, anything unknown) and for HLG into HLG', () {
    const List<(String?, DynamicRange, String?)> rows =
        <(String?, DynamicRange, String?)>[
          (null, DynamicRange.sdr, null),
          ('bt709', DynamicRange.sdr, null),
          ('smpte170m', DynamicRange.sdr, null),
          ('unknown', DynamicRange.sdr, null),
          ('arib-std-b67', DynamicRange.sdr, RangeFilter.hdrToSdr),
          ('smpte2084', DynamicRange.sdr, RangeFilter.hdrToSdr),
          (null, DynamicRange.hlg, RangeFilter.sdrToHlg),
          ('bt709', DynamicRange.hlg, RangeFilter.sdrToHlg),
          ('arib-std-b67', DynamicRange.hlg, null),
          ('smpte2084', DynamicRange.hlg, RangeFilter.pqToHlg),
        ];
    for (final (String? transfer, DynamicRange range, String? chain) in rows) {
      expect(
        RangeFilter.conversion(sourceColorTransfer: transfer, range: range),
        chain,
        reason: '$transfer into $range',
      );
    }
    expect(ColorTransfer.isHdr('arib-std-b67'), isTrue);
    expect(ColorTransfer.isHdr('smpte2084'), isTrue);
    expect(ColorTransfer.isHdr('bt709'), isFalse);
    expect(ColorTransfer.isHdr(null), isFalse);
  });

  test('prefixed: the conversion before the chain, comma-joined; the chain '
      'alone without one', () {
    const String canvas =
        'scale=1920:1080:force_original_aspect_ratio=decrease';
    expect(
      RangeFilter.prefixed(_hlg, sourceColorTransfer: 'bt709', chain: canvas),
      '${RangeFilter.sdrToHlg},$canvas',
    );
    expect(
      RangeFilter.prefixed(
        _hlg,
        sourceColorTransfer: 'arib-std-b67',
        chain: canvas,
      ),
      canvas,
    );
    expect(
      RangeFilter.prefixed(
        const ClipFormat.legacy(VideoOrientation.landscape),
        sourceColorTransfer: 'smpte2084',
        chain: canvas,
      ),
      '${RangeFilter.hdrToSdr},$canvas',
    );
    expect(
      RangeFilter.prefixed(
        const ClipFormat.legacy(VideoOrientation.landscape),
        sourceColorTransfer: null,
        chain: canvas,
      ),
      canvas,
    );
  });
}
