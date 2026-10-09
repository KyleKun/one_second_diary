import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/shared/widgets/identity/flag_image.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';

/// ffmpeg-kit's `full-gpl` build, which the app links: its GPL parts put the
/// whole build under the GPL 3.0. The text is the plugin's `LICENSE.GPLv3`.
const String ffmpegKitGplLicenseAsset = 'assets/licenses/ffmpeg-kit-GPLv3.txt';

/// The licence of every bundled font (`OsdFonts.licenses`), of the flag
/// artwork (`FlagImage.licenseAsset`) and of ffmpeg-kit's GPL build
/// ([ffmpegKitGplLicenseAsset]), read from [bundle] when the licences page
/// asks. Bootstrap registers it with `LicenseRegistry.addLicense`.
///
/// Pub packages' licences are collected by Flutter, but only from a
/// package's `LICENSE`: the fonts and flags are files of the app itself, and
/// ffmpeg_kit_flutter_new's `LICENSE` is the LGPL of its own code.
Stream<LicenseEntry> bundledLicenses(AssetBundle bundle) async* {
  for (final OsdFontLicense license in OsdFonts.licenses) {
    yield LicenseEntryWithLineBreaks(<String>[
      license.name,
    ], await bundle.loadString(license.asset));
  }
  yield LicenseEntryWithLineBreaks(<String>[
    'flag-icons',
  ], await bundle.loadString(FlagImage.licenseAsset));
  yield LicenseEntryWithLineBreaks(<String>[
    'ffmpeg-kit (full-gpl): FFmpeg, x264, x265, xvidcore, vid.stab',
  ], await bundle.loadString(ffmpegKitGplLicenseAsset));
}
