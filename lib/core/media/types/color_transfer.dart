/// The colour transfer characteristics ffprobe names (`color_transfer`)
/// that tell an HDR video from an SDR one.
///
/// A probe reports one of these on an HDR source; an SDR phone recording
/// says `bt709` or nothing at all. Null is SDR: most SDR recordings carry
/// no tag, and an unknown value is never a guess at HDR.
abstract final class ColorTransfer {
  /// Hybrid log-gamma (BT.2100): what iPhones and most Android flagships
  /// record, and what an HLG profile writes.
  static const String hlg = 'arib-std-b67';

  /// PQ (SMPTE ST 2084, BT.2100): HDR10 and HDR10+ recordings (Samsung).
  static const String pq = 'smpte2084';

  /// The two HDR transfers.
  static const Set<String> hdr = <String>{hlg, pq};

  /// Whether a stream whose `color_transfer` is [colorTransfer] is HDR.
  static bool isHdr(String? colorTransfer) =>
      colorTransfer != null && hdr.contains(colorTransfer);
}
