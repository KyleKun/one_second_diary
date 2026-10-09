import 'package:one_second_diary/theme/osd_space.dart';

/// How roomy Today is: compact when the tab is shorter than [compactBelow]
/// above the nav (a 360 × 640 phone), so the stage and the controls fit
/// before anything scrolls.
enum TodayDensity {
  regular(controlsBottomMargin: OsdSpace.s32),
  compact(controlsBottomMargin: OsdSpace.s24);

  const TodayDensity({required this.controlsBottomMargin});

  /// The tab height (below the status bar, above the nav) under which Today
  /// is compact.
  static const double compactBelow = 600;

  /// The space between the controls and the nav: the record halo's widest
  /// reach fits in it.
  final double controlsBottomMargin;

  bool get isCompact => this == compact;

  static TodayDensity forHeight(double height) =>
      height < compactBelow ? compact : regular;
}
