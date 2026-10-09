# Fonts

The app never downloads fonts at runtime (COMPONENTS.md §2.1). Everything it draws with is in `assets/fonts/`:

| pubspec family | Files | Role | Licence |
|---|---|---|---|
| `Rubik` | `Rubik-Regular.ttf` (400), `Rubik-Medium.ttf` (500), `Rubik-SemiBold.ttf` (600), `Rubik-Bold.ttf` (700) | all UI and display text; the video date and place stamps (Medium) | SIL OFL 1.1, `Rubik-OFL.txt` |
| `NotoSansSC` | `NotoSansSC-Medium.otf` (500) | the stamps Rubik can't draw (Chinese) | SIL OFL 1.1, `NotoSansSC-OFL.txt` |
| `Magic` | `YuseiMagic-Regular.ttf` (400) | the stamps of older versions, behind the "Legacy font in videos" preference | SIL OFL 1.1, `YuseiMagic-OFL.txt` |
| `MaterialSymbolsRounded` | `MaterialSymbolsRounded-Subset.ttf` (variable) | icons, see `tool/icons/README.md` | Apache 2.0, `MaterialSymbols-LICENSE.txt` |

Chinese UI text uses the platform's system fonts (Noto Sans CJK on Android, PingFang on iOS).

## Stamp fonts

ffmpeg's drawtext has no per-glyph fallback, so `StampFontPolicy` picks one font for a clip's date and place from
their text: Rubik, then Noto Sans SC; with the legacy preference, Yusei Magic first. It reads each font's coverage
from `lib/core/media/policy/stamp_font_coverage.g.dart`. After changing a stamp font:

```sh
python3 tool/fonts/make_stamp_coverage.py   # needs fontTools
```

then bump the version in its `StampFont.fileName` and pin the new checksum in
`test/core/media/policy/stamp_font_test.dart`.

Noto Sans SC is the region subset from the Noto CJK project:

```sh
curl -sSL -o assets/fonts/NotoSansSC-Medium.otf 'https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/SC/NotoSansSC-Medium.otf'
curl -sSL -o assets/fonts/NotoSansSC-OFL.txt 'https://github.com/notofonts/noto-cjk/raw/main/Sans/LICENSE'
```

## Rebuilding the Rubik weights

Flutter doesn't map `FontWeight` onto a variable font's `wght` axis on every platform, so the app ships static
instances of Google Fonts' variable Rubik:

```sh
curl -sSL -o /tmp/Rubik-VF.ttf 'https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf'
curl -sSL -o assets/fonts/Rubik-OFL.txt 'https://github.com/google/fonts/raw/main/ofl/rubik/OFL.txt'
python3 tool/fonts/make_rubik_statics.py /tmp/Rubik-VF.ttf   # needs fontTools: pip install --user fonttools
```

`test/theme/osd_fonts_test.dart` checks that every family and weight in `pubspec.yaml` points at a file whose
`OS/2` weight matches, and that Rubik covers Latin Extended and Cyrillic.

## Licences in the app

The OFL and Apache texts must appear under Settings › About › Licenses. Register them with `LicenseRegistry.addLicense`
at bootstrap (track 2C); `docs/v3/phase2/track_2a.md` lists the files.
