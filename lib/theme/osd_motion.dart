import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How far a pressed surface scales, by component category.
enum OsdPressScale {
  /// Circular icon buttons, RecordButton, chips, calendar cells, ProfileChip,
  /// the nav icon.
  icon(.94),

  /// Viewer action tiles and QuickCutChip.
  actionTile(.96),

  /// Buttons and tiles.
  button(.97),

  /// Rows and profile tiles.
  row(.98),

  /// Info cards.
  infoCard(.99);

  const OsdPressScale(this.scale);

  /// The scale at full press.
  final double scale;
}

/// Motion tokens, recipes and reduced-motion helpers.
///
/// Motion is calm and quick: press feedback is a scale, not a ripple;
/// selection is a colour or border crossfade; only confirmations bounce.
///
/// Every widget reads durations through [d] and curves through [curve], so
/// `MediaQuery.disableAnimationsOf` turns every transition into a crossfade of
/// at most 150 ms. Progress indicators, the recording ring and the processing
/// bar keep progressing: they carry information.
abstract final class OsdMotion {
  /// Press scale in (pointer down).
  static const Duration pressIn = Duration(milliseconds: 100);
  static const Curve pressInCurve = Curves.easeOut;

  /// Press scale out (pointer up or cancel).
  static const Duration pressOut = Duration(milliseconds: 150);
  static const Curve pressOutCurve = Curves.easeOutBack;

  /// SEL pressed overlay in.
  static const Duration overlayIn = Duration(milliseconds: 60);

  /// SEL pressed overlay out.
  static const Duration overlayOut = Duration(milliseconds: 180);

  /// Opacity, colour, icon swaps and crossfades; the nav icon fill.
  static const Duration fast = Duration(milliseconds: 150);
  static const Curve fastCurve = Curves.easeOut;

  /// Fill, border and thumb changes; OsdSwitch.
  static const Duration selection = Duration(milliseconds: 180);
  static const Curve selectionCurve = Curves.easeOut;

  /// OsdSwitch thumb and track.
  static const Curve switchCurve = Curves.easeInOut;

  /// In-page layout: AnimatedSize, the segmented pill, chip width, grid height.
  static const Duration standard = Duration(milliseconds: 220);
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Hero and shared-element flights, the Today frame morph.
  static const Duration emphasized = Duration(milliseconds: 300);

  /// The orientation morph and viewer flights.
  static const Duration emphasizedLong = Duration(milliseconds: 320);
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;

  /// Media flights: clip → viewer (radius 20 → 0), movie → player, camera →
  /// clip editor.
  static const Duration mediaFlight = emphasizedLong;

  /// The nav pill fading in and widening 32 → 58.
  static const Duration navPill = Duration(milliseconds: 200);

  /// A check or badge landing (scale [badgeInScale] → 1).
  static const Duration badgeIn = Duration(milliseconds: 180);
  static const Curve badgeInCurve = Curves.easeOutBack;
  static const double badgeInScale = .6;

  /// Route replacements (camera → clip editor, the movie-making steps,
  /// onboarding → Today): out [fadeThroughOut], then in [fadeThroughIn] with
  /// scale [fadeThroughScale] → 1. Pushes use the platform transition.
  static const Duration fadeThrough = Duration(milliseconds: 300);
  static const Duration fadeThroughOut = Duration(milliseconds: 90);
  static const Duration fadeThroughIn = Duration(milliseconds: 210);
  static const double fadeThroughScale = .96;
  static const Curve fadeThroughCurve = Curves.easeOutCubic;

  /// Diary Calendar ↔ Memories: out [viewSwitchOut], in [viewSwitchIn] with
  /// scale [viewSwitchScale] → 1.
  static const Duration viewSwitch = Duration(milliseconds: 250);
  static const Duration viewSwitchOut = Duration(milliseconds: 90);
  static const Duration viewSwitchIn = Duration(milliseconds: 160);
  static const double viewSwitchScale = .92;

  /// Light ↔ dark theme crossfade (`MaterialApp.themeAnimationDuration`).
  static const Duration themeChange = Duration(milliseconds: 250);
  static const Curve themeChangeCurve = Curves.easeInOut;

  /// OsdSheet slide-up, about 300 ms.
  static const SpringDescription sheetSpring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 38,
  );

  /// Sheet dismiss.
  static const Duration sheetClose = Duration(milliseconds: 220);
  static const Curve sheetCloseCurve = Curves.easeInCubic;

  /// Scrim fade to 70 %.
  static const Duration barrier = Duration(milliseconds: 200);

  /// Dialog in: fade + scale [dialogScaleIn] → 1.
  static const Duration dialogIn = Duration(milliseconds: 220);
  static const Curve dialogInCurve = Curves.easeOutCubic;
  static const double dialogScaleIn = .94;

  /// Dialog out: fade + scale → [dialogScaleOut].
  static const Duration dialogOut = Duration(milliseconds: 150);
  static const Curve dialogOutCurve = Curves.easeIn;
  static const double dialogScaleOut = .96;

  /// Snackbar in: rise [snackInOffset] px and fade.
  static const Duration snackIn = Duration(milliseconds: 240);
  static const Curve snackInCurve = Curves.easeOutCubic;
  static const double snackInOffset = 24;

  /// Snackbar out: fade and drop [snackOutOffset] px.
  static const Duration snackOut = Duration(milliseconds: 180);
  static const Curve snackOutCurve = Curves.easeInCubic;
  static const double snackOutOffset = 12;

  /// First appearance of a list or grid: fade + rise [entranceRise] px, once
  /// per session, the first [entranceMaxItems] items [entranceStagger] apart.
  /// Use [entranceDelay].
  static const Duration entrance = Duration(milliseconds: 240);
  static const Duration entranceStagger = Duration(milliseconds: 40);
  static const int entranceMaxItems = 6;
  static const double entranceRise = 8;

  /// Stat count-ups, [countUpStagger] apart.
  static const Duration countUp = Duration(milliseconds: 700);
  static const Duration countUpStagger = Duration(milliseconds: 60);

  /// Diary month count; "Movies made" +1.
  static const Duration countUpShort = Duration(milliseconds: 400);

  /// Incremental number change: slide [countTickSlide] px and fade.
  static const Duration countTick = Duration(milliseconds: 150);
  static const double countTickSlide = 6;

  /// Reminder time change: only changed digits roll ±[digitRollSlide] px,
  /// [digitRollStagger] apart.
  static const Duration digitRoll = Duration(milliseconds: 260);
  static const Duration digitRollStagger = Duration(milliseconds: 30);
  static const double digitRollSlide = 12;

  /// RecordButton outer halo breathing (spread 22 ↔ 25, alpha .06 ↔ .10).
  static const Duration idleBreath = Duration(milliseconds: 2400);
  static const Curve idleBreathCurve = Curves.easeInOutSine;

  /// Rec dot opacity 1 ↔ .35.
  static const Duration recPulse = Duration(milliseconds: 1000);

  /// Skeleton shimmer (linear).
  static const Duration shimmer = Duration(milliseconds: 1200);

  /// Filmstrip placeholder opacity .55 ↔ 1 (reverse loop).
  static const Duration pulse = Duration(milliseconds: 900);

  /// ProcessingThumb states and progress width (the design's `.35s ease`).
  static const Duration processing = Duration(milliseconds: 350);
  static const Curve processingCurve = Curves.ease;

  /// Carousel snap.
  static const SpringDescription carouselSpring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 40,
  );

  /// Shutter release.
  static const SpringDescription shutterSpring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 22,
  );

  /// Long-press release.
  static const SpringDescription longPressReleaseSpring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 20,
  );

  /// Viewer drag-to-dismiss return.
  static const SpringDescription dragDismissSpring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 30,
  );

  /// Spinners and loading visuals appear only after this, to avoid a flash.
  static const Duration loadingDelay = Duration(milliseconds: 150);

  /// A route push that follows a sheet close waits for the sheet's exit.
  static const Duration afterSheetClose = Duration(milliseconds: 200);

  /// The longest any transition runs under reduced motion.
  static const Duration reducedMax = Duration(milliseconds: 150);

  static const double _reducedPressScale = .97;

  /// Whether the platform asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [normal], capped at 150 ms under reduced motion.
  static Duration d(BuildContext context, Duration normal) =>
      reduced(context) && normal > reducedMax ? reducedMax : normal;

  /// [normal], or a linear crossfade under reduced motion.
  static Curve curve(BuildContext context, Curve normal) =>
      reduced(context) ? Curves.linear : normal;

  /// The press scale for [category]. Under reduced motion it never goes below
  /// 0.97: press feedback is direct manipulation, so a small scale stays.
  static double pressScale(BuildContext context, OsdPressScale category) =>
      reduced(context)
      ? math.max(category.scale, _reducedPressScale)
      : category.scale;

  /// The entrance delay of list item [index], or null when the item appears
  /// without an entrance: past the first [entranceMaxItems], or under reduced
  /// motion.
  static Duration? entranceDelay(BuildContext context, int index) {
    if (reduced(context) || index >= entranceMaxItems) return null;
    return entranceStagger * index;
  }

  /// Whether idle loops (record halo, rec dot, marquee, shimmer) may run.
  /// Under reduced motion they render static.
  static bool loopsEnabled(BuildContext context) => !reduced(context);
}
