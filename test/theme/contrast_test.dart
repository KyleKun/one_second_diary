import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

import 'support/wcag.dart';

typedef _Pick = Color Function(OsdColors c);

/// A foreground over one or more surfaces. A surface is a list of layers,
/// bottom first (a tint over BG is `[bg, tint]`).
typedef _Pair = ({
  String row,
  String use,
  _Pick fg,
  Map<String, List<_Pick>> on,
  double min,
});

Color _bg(OsdColors c) => c.bg;
Color _card(OsdColors c) => c.card;
Color _c2(OsdColors c) => c.c2;
Color _sh(OsdColors c) => c.sh;
Color _btn(OsdColors c) => c.btn;
Color _nav(OsdColors c) => c.nav;

final Map<String, List<_Pick>> _themeSurfaces = <String, List<_Pick>>{
  'BG': <_Pick>[_bg],
  'CARD': <_Pick>[_card],
  'C2': <_Pick>[_c2],
  'SH': <_Pick>[_sh],
  'BTN': <_Pick>[_btn],
  'NAV': <_Pick>[_nav],
};

/// Every pair that must pass, in both themes.
final List<_Pair> _pairs = <_Pair>[
  (
    row: '1',
    use: 'TX text',
    fg: (c) => c.tx,
    on: _themeSurfaces,
    min: Wcag.text,
  ),
  (
    row: '2',
    use: 'D2 text',
    fg: (c) => c.d2,
    on: _themeSurfaces,
    min: Wcag.text,
  ),
  (
    row: '3–4',
    use: 'MU text (nav labels, subtitles, counts)',
    fg: (c) => c.mu,
    on: _themeSurfaces,
    min: Wcag.text,
  ),
  (
    row: '5',
    use: 'SUB captions',
    fg: (c) => c.sub,
    on: <String, List<_Pick>>{
      'BG': <_Pick>[_bg],
      'SH': <_Pick>[_sh],
    },
    min: Wcag.text,
  ),
  (
    row: '8',
    use: 'FA unselected radio (state glyph)',
    fg: (c) => c.fa,
    on: <String, List<_Pick>>{
      'CARD': <_Pick>[_card],
      'BG': <_Pick>[_bg],
    },
    min: Wcag.largeTextOrUi,
  ),
  (
    row: '10',
    use: 'RED destructive text',
    fg: (c) => c.red,
    on: <String, List<_Pick>>{
      'SH': <_Pick>[_sh],
      'BG': <_Pick>[_bg],
      'CARD': <_Pick>[_card],
    },
    min: Wcag.text,
  ),
  (
    row: '11',
    use: 'BG label on a RED fill (D5 Delete)',
    fg: (c) => c.bg,
    on: <String, List<_Pick>>{
      'RED': <_Pick>[(c) => c.red],
    },
    min: Wcag.text,
  ),
  (
    row: '13',
    use: 'CO_INK text (MakeMovieChip, M6 percent)',
    fg: (c) => c.coInk,
    on: <String, List<_Pick>>{
      'BG': <_Pick>[_bg],
      'coTint14 over BG': <_Pick>[_bg, (_) => OsdTints.coTint14],
    },
    min: Wcag.text,
  ),
  (
    row: '14',
    use: 'CO non-text (record disc, today ring, M6 bar)',
    fg: (c) => c.co,
    on: <String, List<_Pick>>{
      'BG': <_Pick>[_bg],
    },
    min: Wcag.largeTextOrUi,
  ),
  (
    row: '15',
    use: 'YELLOW_INK warning text',
    fg: (c) => c.yellowInk,
    on: <String, List<_Pick>>{
      'yellowTint12 over BG': <_Pick>[_bg, (_) => OsdTints.yellowTint12],
    },
    min: Wcag.text,
  ),
  (
    row: '17',
    use: 'snackbar title and action',
    fg: (c) => c.snackbarText,
    on: <String, List<_Pick>>{
      'SNACK_BG': <_Pick>[(c) => c.snackbarBg],
      'action pill': <_Pick>[
        (c) => c.snackbarBg,
        (_) => OsdMedia.snackbarActionFill,
      ],
    },
    min: Wcag.text,
  ),
  (
    row: '17',
    use: 'snackbar sub-line',
    fg: (c) => c.snackbarSub,
    on: <String, List<_Pick>>{
      'SNACK_BG': <_Pick>[(c) => c.snackbarBg],
    },
    min: Wcag.text,
  ),
  (
    row: '18',
    use: 'snackbar success check',
    fg: (c) => c.snackbarSuccess,
    on: <String, List<_Pick>>{
      'greenTint20 over SNACK_BG': <_Pick>[
        (c) => c.snackbarBg,
        (_) => OsdTints.greenTint20,
      ],
    },
    min: Wcag.largeTextOrUi,
  ),
  (
    row: '23',
    use: 'OsdSwitch OFF thumb (MU) on CARD',
    fg: (c) => c.mu,
    on: <String, List<_Pick>>{
      'CARD': <_Pick>[_card],
    },
    min: Wcag.largeTextOrUi,
  ),
  (
    row: '12',
    use:
        'ON_CO label on the coral button fill (brand exception: large-text level only)',
    fg: (c) => c.onCo,
    on: <String, List<_Pick>>{
      'CO_FILL': <_Pick>[(c) => c.coFill],
    },
    min: Wcag.largeTextOrUi,
  ),
];

double _ratio(OsdColors colors, _Pick fg, List<_Pick> layers) => contrastRatio(
  fg(colors),
  composite(<Color>[for (final layer in layers) layer(colors)]),
);

void main() {
  // One table over both themes and every pair, plus the theme-invariant
  // pairs drawn over media.
  test('text and UI tokens pass WCAG AA in both themes (COMPONENTS §7.1)', () {
    final failures = <String>[
      for (final (name, colors) in <(String, OsdColors)>[
        ('dark', OsdColors.dark),
        ('light', OsdColors.light),
      ])
        for (final pair in _pairs)
          for (final MapEntry(key: surface, value: layers) in pair.on.entries)
            if (_ratio(colors, pair.fg, layers) < pair.min)
              '$name row ${pair.row}: ${pair.use} on $surface '
                  '${_ratio(colors, pair.fg, layers).toStringAsFixed(2)} < ${pair.min}',
    ];
    final invariant = <String, (Color, Color)>{
      'row 19: white on the SavedBadge scrim over a white frame': (
        OsdMedia.onMedia,
        composite(<Color>[const Color(0xFFFFFFFF), OsdMedia.scrim55]),
      ),
      'row 21: camera bubble text': (
        OsdCamera.bubbleText,
        composite(<Color>[OsdCamera.black, OsdCamera.bubble]),
      ),
      'row 21: viewer captions': (OsdViewer.caption, OsdViewer.background),
    };
    for (final MapEntry(key: use, value: (fg, bg)) in invariant.entries) {
      if (contrastRatio(fg, bg) < Wcag.text) failures.add(use);
    }

    expect(failures, isEmpty);
  });
}
