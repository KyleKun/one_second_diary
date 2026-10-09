import 'package:flutter/material.dart';

/// The colour tokens as a [ThemeExtension].
///
/// Custom widgets read colours from here, never from hex literals. Read it with
/// `context.colors` or [OsdColors.of]. The field names are the design token
/// names (BG → [bg], TX → [tx], …).
///
/// **Contrast.** Five light-theme tokens are darker than the designer's so text
/// meets WCAG AA: [mu] (muted text on C2/BTN/NAV), [sub] (13 px captions on
/// BG/SH), [fa] (unselected radio on CARD, needs 3:1), [red] (destructive text)
/// and [coInk] (coral text on BG). Coral *fills* ([co], [coFill]) stay the brand
/// #EF5558 in both themes; white on coral (3.44:1) is a brand exception.
///
/// Rules that keep text readable: FA is never essential text (use MU), and SUB
/// only sits on BG or SH (use MU on CARD and C2).
/// (use MU), and SUB only sits on BG or SH (use MU on CARD and C2).
@immutable
class OsdColors extends ThemeExtension<OsdColors> {
  const OsdColors({
    required this.bg,
    required this.tx,
    required this.card,
    required this.btn,
    required this.c2,
    required this.off,
    required this.mu,
    required this.fa,
    required this.d2,
    required this.ln,
    required this.co,
    required this.red,
    required this.sh,
    required this.nav,
    required this.dim,
    required this.sel,
    required this.pill,
    required this.dis,
    required this.handle,
    required this.outline,
    required this.sub,
    required this.thumbOff,
    required this.snackbarBg,
    required this.snackbarText,
    required this.snackbarSub,
    required this.onCo,
    required this.yellow,
    required this.green,
    required this.purple,
    required this.greenInk,
    required this.yellowInk,
    required this.coInk,
    required this.coFill,
  });

  /// BG: screen background; ink on TX fills (selected chips, badges).
  final Color bg;

  /// TX: primary text and icons. Also the "ink" of selection: selected
  /// borders and fills, switch ON track, outlined pill.
  final Color tx;

  /// CARD: grouped cards, stat tiles, info cards, missed day cell.
  final Color card;

  /// BTN: neutral buttons and chips on BG, profile chip, view-toggle track.
  final Color btn;

  /// C2: secondary surfaces on CARD, SH or dialogs (inputs, option tiles,
  /// neutral buttons inside cards and sheets).
  final Color c2;

  /// OFF: switch OFF track, avatar placeholder, progress tracks, inactive dots.
  final Color off;

  /// MU: muted text, leading icons, labels, hints and counters.
  final Color mu;

  /// FA: faint chevrons, unselected radios, dashed borders. Not for essential
  /// text.
  final Color fa;

  /// D2: secondary body text, content on C2 circles.
  final Color d2;

  /// LN: dividers, nav top border, the light-only CARD hairline. Translucent.
  final Color ln;

  /// CO: coral, for actions only (record, save, create, continue).
  final Color co;

  /// RED: destructive text, icons and fills.
  final Color red;

  /// SH: bottom sheets and dialogs.
  final Color sh;

  /// NAV: bottom navigation.
  final Color nav;

  /// DIM: scrim base, used at 70 % ([scrimModal]).
  final Color dim;

  /// SEL: selected fill and pressed/hover overlay. Translucent: paint it over
  /// the surface, and never use it as the only selection cue.
  final Color sel;

  /// PILL: active nav pill. Translucent.
  final Color pill;

  /// DIS: disabled glyphs and labels.
  final Color dis;

  /// HANDLE: sheet drag handle. Translucent.
  final Color handle;

  /// OUTLINE: flag hairline, dashed empty frames. Translucent.
  final Color outline;

  /// SUB: third grey between MU and FA, only on BG or SH (dark SUB on CARD is
  /// 4.4:1).
  final Color sub;

  /// THUMB_OFF: unselected orientation thumb on C2.
  final Color thumbOff;

  /// SNACK_BG: snackbar surface, dark in both themes.
  final Color snackbarBg;

  /// SNACK_TX: snackbar title and action.
  final Color snackbarText;

  /// SNACK_SUB: snackbar sub-line.
  final Color snackbarSub;

  /// ON_CO: label and icon on CO.
  final Color onCo;

  /// YELLOW: accent for streaks, tips, coffee, the Subtitles tab.
  final Color yellow;

  /// GREEN: accent for success and "This month".
  final Color green;

  /// PURPLE: accent for the Location tab, "Your life so far", Gallery.
  final Color purple;

  /// GREEN_INK: green glyphs on theme surfaces.
  final Color greenInk;

  /// YELLOW_INK: yellow text on theme surfaces.
  final Color yellowInk;

  /// CO_INK: coral text and glyphs on theme surfaces.
  final Color coInk;

  /// CO_FILL: fill of coral buttons that carry text. The RecordButton disc,
  /// rings, dots and progress always use [co].
  final Color coFill;

  // Alpha bytes are CSS alpha × 255 rounded to nearest (.06 → 0x0F, .07 → 0x12,
  // .09 → 0x17, .12 → 0x1F, .14 → 0x24, .15 → 0x26, .18 → 0x2E, .20 → 0x33).

  /// The dark palette, the design's source of truth.
  static const OsdColors dark = OsdColors(
    bg: Color(0xFF151414),
    tx: Color(0xFFF4F1EE),
    card: Color(0xFF201F1E),
    btn: Color(0xFF201F1F),
    c2: Color(0xFF2B2928),
    off: Color(0xFF3A3736),
    mu: Color(0xFFA39E99),
    fa: Color(0xFF6E6965),
    d2: Color(0xFFD9D4CF),
    ln: Color(0x0FFFFFFF),
    co: Color(0xFFEF5558),
    red: Color(0xFFFF7C7F),
    sh: Color(0xFF1E1D1C),
    nav: Color(0xFF1B1A19),
    dim: Color(0xFF0C0B0B),
    sel: Color(0x12F4F1EE),
    pill: Color(0x1FF4F1EE),
    dis: Color(0xFF5E5955),
    handle: Color(0x33FFFFFF),
    outline: Color(0x24FFFFFF),
    sub: Color(0xFF8A837D),
    thumbOff: Color(0xFF4A4644),
    snackbarBg: Color(0xFF322F2D),
    snackbarText: Color(0xFFF5F2EF),
    snackbarSub: Color(0xFFB2ACA6),
    onCo: Color(0xFFFFFFFF),
    yellow: Color(0xFFE5B25D),
    green: Color(0xFF7AC74F),
    purple: Color(0xFF7D7ABC),
    greenInk: Color(0xFF7AC74F),
    yellowInk: Color(0xFFE5B25D),
    coInk: Color(0xFFEF5558),
    coFill: Color(0xFFEF5558),
  );

  /// The light palette, with the contrast defaults described on the class.
  static const OsdColors light = OsdColors(
    bg: Color(0xFFF4F1EA),
    tx: Color(0xFF2A2723),
    card: Color(0xFFFAF8F3),
    btn: Color(0xFFEAE6DD),
    c2: Color(0xFFECE8DF),
    off: Color(0xFFDCD6CB),
    mu: Color(0xFF6B665F),
    fa: Color(0xFF8C867E),
    d2: Color(0xFF4A4540),
    ln: Color(0x1F3C3228),
    co: Color(0xFFEF5558),
    red: Color(0xFFBF3539),
    sh: Color(0xFFFAF8F3),
    nav: Color(0xFFEAE6DD),
    dim: Color(0xFFA7A198),
    sel: Color(0x0F2A2723),
    pill: Color(0x172A2723),
    dis: Color(0xFFC0BAB0),
    handle: Color(0x26000000),
    outline: Color(0x2E3C3228),
    sub: Color(0xFF6F6A63),
    thumbOff: Color(0xFFDCD6CB),
    snackbarBg: Color(0xFF2A2723),
    snackbarText: Color(0xFFF4F1EA),
    snackbarSub: Color(0xFFBDB7AF),
    onCo: Color(0xFFFFFFFF),
    yellow: Color(0xFFE5B25D),
    green: Color(0xFF7AC74F),
    purple: Color(0xFF7D7ABC),
    greenInk: Color(0xFF5FAE34),
    yellowInk: Color(0xFF8A5A00),
    coInk: Color(0xFFB53034),
    coFill: Color(0xFFEF5558),
  );

  /// The snackbar is dark in both themes, so its error status always uses the
  /// dark RED.
  Color get snackbarError => OsdColors.dark.red;

  /// The snackbar success status: GREEN, the same in both themes.
  Color get snackbarSuccess => green;

  /// The barrier behind every app sheet and dialog: DIM at 70 %.
  Color get scrimModal => dim.withValues(alpha: .70);

  /// The palette of the nearest [Theme].
  ///
  /// Throws a [StateError] when the theme has no [OsdColors], which means the
  /// subtree is not under a theme built by `OsdTheme`.
  static OsdColors of(BuildContext context) {
    final colors = Theme.of(context).extension<OsdColors>();
    if (colors == null) {
      throw StateError(
        'No OsdColors in the theme. Build the MaterialApp theme with OsdTheme.dark()/light(), '
        'or wrap the subtree in OsdForcedDark.',
      );
    }
    return colors;
  }

  @override
  OsdColors copyWith({
    Color? bg,
    Color? tx,
    Color? card,
    Color? btn,
    Color? c2,
    Color? off,
    Color? mu,
    Color? fa,
    Color? d2,
    Color? ln,
    Color? co,
    Color? red,
    Color? sh,
    Color? nav,
    Color? dim,
    Color? sel,
    Color? pill,
    Color? dis,
    Color? handle,
    Color? outline,
    Color? sub,
    Color? thumbOff,
    Color? snackbarBg,
    Color? snackbarText,
    Color? snackbarSub,
    Color? onCo,
    Color? yellow,
    Color? green,
    Color? purple,
    Color? greenInk,
    Color? yellowInk,
    Color? coInk,
    Color? coFill,
  }) {
    return OsdColors(
      bg: bg ?? this.bg,
      tx: tx ?? this.tx,
      card: card ?? this.card,
      btn: btn ?? this.btn,
      c2: c2 ?? this.c2,
      off: off ?? this.off,
      mu: mu ?? this.mu,
      fa: fa ?? this.fa,
      d2: d2 ?? this.d2,
      ln: ln ?? this.ln,
      co: co ?? this.co,
      red: red ?? this.red,
      sh: sh ?? this.sh,
      nav: nav ?? this.nav,
      dim: dim ?? this.dim,
      sel: sel ?? this.sel,
      pill: pill ?? this.pill,
      dis: dis ?? this.dis,
      handle: handle ?? this.handle,
      outline: outline ?? this.outline,
      sub: sub ?? this.sub,
      thumbOff: thumbOff ?? this.thumbOff,
      snackbarBg: snackbarBg ?? this.snackbarBg,
      snackbarText: snackbarText ?? this.snackbarText,
      snackbarSub: snackbarSub ?? this.snackbarSub,
      onCo: onCo ?? this.onCo,
      yellow: yellow ?? this.yellow,
      green: green ?? this.green,
      purple: purple ?? this.purple,
      greenInk: greenInk ?? this.greenInk,
      yellowInk: yellowInk ?? this.yellowInk,
      coInk: coInk ?? this.coInk,
      coFill: coFill ?? this.coFill,
    );
  }

  /// Interpolates every token, so `MaterialApp`'s theme animation recolours
  /// custom widgets too.
  @override
  OsdColors lerp(covariant ThemeExtension<OsdColors>? other, double t) {
    if (other is! OsdColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return OsdColors(
      bg: mix(bg, other.bg),
      tx: mix(tx, other.tx),
      card: mix(card, other.card),
      btn: mix(btn, other.btn),
      c2: mix(c2, other.c2),
      off: mix(off, other.off),
      mu: mix(mu, other.mu),
      fa: mix(fa, other.fa),
      d2: mix(d2, other.d2),
      ln: mix(ln, other.ln),
      co: mix(co, other.co),
      red: mix(red, other.red),
      sh: mix(sh, other.sh),
      nav: mix(nav, other.nav),
      dim: mix(dim, other.dim),
      sel: mix(sel, other.sel),
      pill: mix(pill, other.pill),
      dis: mix(dis, other.dis),
      handle: mix(handle, other.handle),
      outline: mix(outline, other.outline),
      sub: mix(sub, other.sub),
      thumbOff: mix(thumbOff, other.thumbOff),
      snackbarBg: mix(snackbarBg, other.snackbarBg),
      snackbarText: mix(snackbarText, other.snackbarText),
      snackbarSub: mix(snackbarSub, other.snackbarSub),
      onCo: mix(onCo, other.onCo),
      yellow: mix(yellow, other.yellow),
      green: mix(green, other.green),
      purple: mix(purple, other.purple),
      greenInk: mix(greenInk, other.greenInk),
      yellowInk: mix(yellowInk, other.yellowInk),
      coInk: mix(coInk, other.coInk),
      coFill: mix(coFill, other.coFill),
    );
  }

  List<Color> get _tokens => <Color>[
    bg,
    tx,
    card,
    btn,
    c2,
    off,
    mu,
    fa,
    d2,
    ln,
    co,
    red,
    sh,
    nav,
    dim,
    sel,
    pill,
    dis,
    handle,
    outline,
    sub,
    thumbOff,
    snackbarBg,
    snackbarText,
    snackbarSub,
    onCo,
    yellow,
    green,
    purple,
    greenInk,
    yellowInk,
    coInk,
    coFill,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OsdColors) return false;
    final mine = _tokens;
    final theirs = other._tokens;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_tokens);
}

/// `context.colors`: the [OsdColors] of the nearest theme.
extension OsdColorsContext on BuildContext {
  OsdColors get colors => OsdColors.of(this);
}
