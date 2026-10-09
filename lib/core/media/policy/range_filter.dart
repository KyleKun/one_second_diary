import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/color_transfer.dart';

/// The dynamic-range conversion a render needs between its SOURCE (what
/// ffprobe says of its `color_transfer`) and its TARGET format's range
/// as a `-vf` fragment that goes before the canvas
/// and the stamps, so they work on frames already in the target's range
/// and bit depth. Nothing for SDR into SDR (the argv of earlier versions,
/// byte for byte) and for HLG into HLG (decoded 10-bit, stamped, encoded).
///
/// Every chain runs through libzimg (`zscale`, in ffmpeg-kit full):
/// - [hdrToSdr]: the tone map, for an HDR source (HLG or PQ) into
///   any SDR profile, the legacy one included (an HLG import
///   normalised into a legacy profile would otherwise come out High 10). The
///   chain ends in `format=yuv420p`, so the frames reach libx264 as 8-bit
///   whatever the encode settings say;
/// - [sdrToHlg]: an SDR source (every in-app recording, every photo) into
///   an HLG profile. Linear light (the input tagged BT.709, because an
///   untagged source, which most in-app recordings are, makes zimg refuse
///   with "no path between colorspaces"), the gain that puts SDR white at
///   HLG's reference white (BT.2408: 203 cd/m², 75 % signal on a 1000 nit
///   display; `exposure` is the one filter that scales float RGB, and
///   2^-2.3 = 0.203), BT.2020 primaries, then the HLG curve with the
///   BT.2020 non-constant matrix, limited range, into 10-bit planes;
/// - [pqToHlg]: a PQ (HDR10, HDR10+) source into an HLG profile: linear
///   light at a 1000 cd/m² nominal peak (anything brighter clips, as
///   BT.2408's PQ-to-HLG does), then the HLG curve at the same peak. The
///   primaries and matrix are BT.2020 already. A plain remap of PQ data
///   under HLG tags would show every such import flat and dark.
///
abstract final class RangeFilter {
  /// HDR (HLG or PQ) into SDR: tone-mapped with `hable`.
  static const String hdrToSdr =
      'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,'
      'tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p';

  /// SDR into HLG (see the class doc).
  static const String sdrToHlg =
      'zscale=pin=bt709:tin=bt709:min=bt709:t=linear:npl=100,'
      'format=gbrpf32le,exposure=exposure=-2.3,zscale=p=bt2020,'
      'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';

  /// PQ into HLG (see the class doc).
  static const String pqToHlg =
      'zscale=t=linear:npl=1000,format=gbrpf32le,'
      'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';

  /// The conversion from a source whose `color_transfer` is
  /// [sourceColorTransfer] (null: SDR, or unknown, which is never taken
  /// for HDR) into [range]; null when none is needed.
  static String? conversion({
    required String? sourceColorTransfer,
    required DynamicRange range,
  }) => switch (range) {
    DynamicRange.sdr =>
      ColorTransfer.isHdr(sourceColorTransfer) ? hdrToSdr : null,
    DynamicRange.hlg => switch (sourceColorTransfer) {
      ColorTransfer.hlg => null,
      ColorTransfer.pq => pqToHlg,
      _ => sdrToHlg,
    },
  };

  /// [conversion] for a render into [format].
  static String? conversionFor(
    ClipFormat format,
    String? sourceColorTransfer,
  ) =>
      conversion(sourceColorTransfer: sourceColorTransfer, range: format.range);

  /// [chain] with the conversion of [format] from [sourceColorTransfer]
  /// in front, comma-joined; [chain] alone without one.
  static String prefixed(
    ClipFormat format, {
    required String? sourceColorTransfer,
    required String chain,
  }) => switch (conversionFor(format, sourceColorTransfer)) {
    final String conversion => '$conversion,$chain',
    null => chain,
  };
}
