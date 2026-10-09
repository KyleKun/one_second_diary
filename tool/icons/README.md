# Icons

The app draws its icons from **Material Symbols Rounded** (COMPONENTS.md §5), vendored as a subset:

| File | What it is |
|---|---|
| `tool/icons/icons.txt` | The icon names the app uses. **Edit this list.** |
| `tool/icons/subset_icons.py` | Rebuilds the font and the Dart constants from the list. |
| `assets/fonts/MaterialSymbolsRounded-Subset.ttf` | Generated. The variable font cut down to the listed glyphs. It keeps the `FILL`, `GRAD`, `opsz` and `wght` axes and the GSUB feature variations that swap in the filled glyphs at `FILL` 1. |
| `assets/fonts/MaterialSymbols-LICENSE.txt` | Apache License 2.0, which covers the font. |
| `lib/theme/osd_icons.dart` | Generated. One `const IconData` per icon, in `OsdIcons`. |

The app does **not** depend on the `material_symbols_icons` package (decision X1 in `docs/v3/decisions.md`): it bundles
three whole variable fonts (Outlined 10.6 MB, Rounded 15.1 MB, Sharp 8.8 MB), and Flutter's icon tree shaker only
subsets families referenced through a const `IconData`. The subset is about 0.26 MB.

## Use an icon

```dart
Icon(OsdIcons.movie, size: 22, fill: 1, weight: 400, grade: 0, opticalSize: 22)
```

- `fill` is 0 (outlined, the default) or 1 (filled). Values in between animate the fill.
- `OsdIcons.arrowBack`, `arrowForward`, `chevronLeft`, `chevronRight` and `openInNew` set `matchTextDirection`, so
  `Icon` mirrors them in right-to-left layouts. Never mirror media, orientation or rotation glyphs.
- Always use the `OsdIcons` constants. Never build an `IconData` at runtime: the release build's icon tree shaking
  needs every `IconData` to be a constant.

## Add an icon

1. Find the name on [fonts.google.com/icons](https://fonts.google.com/icons?icon.style=Rounded) (for example
   `photo_camera_front`).
2. Add it to `tool/icons/icons.txt`. Add ` rtl` after the name if the glyph points left or right and must mirror in
   right-to-left layouts.
3. Make sure the package's source font is in the pub cache (it is not an app dependency):

   ```sh
   dart pub cache add material_symbols_icons --version 4.2960.0
   ```

4. Rebuild the font and the constants from the repo root. The script needs fontTools
   (`pip install --user fonttools`):

   ```sh
   python3 tool/icons/subset_icons.py
   # or: python3 tool/icons/subset_icons.py --package-dir <path to material_symbols_icons-x.y.z>
   ```

   It stops if a name is unknown, if a code point is missing from the subset, or if the variation axes or the
   filled-glyph substitutions were dropped. It formats `lib/theme/osd_icons.dart` with `dart format`.

5. Run `flutter test test/theme`. `osd_icons_test.dart` reads the bundled font's `cmap` and fails if any `OsdIcons`
   code point has no glyph, and `icon_fill_axis_test.dart` checks that `fill` still changes the drawing.
6. Commit `icons.txt`, the font and `osd_icons.dart` together.

To update to a newer Material Symbols release, pass the newer package with `--package-dir` and commit the regenerated
files; the header of `osd_icons.dart` records which package version they came from.

## Notes

- Some Material Symbols names are aliases of one glyph. `smartphone` and `stay_current_portrait` share `0xe7ba`, so
  the subset has one code point fewer than `icons.txt` has names.
- The script uses the package's `lib/fonts/MaterialSymbolsRounded.ttf`, not Google's raw font: the package fixes the
  vertical metrics so glyphs sit centred in Flutter's `Icon` box.

## The reminders' notification icon (Android)

`android/app/src/main/res/drawable/ic_notification.xml` is the small icon the reminders show in the status bar
(`reminderSmallIcon` in `lib/core/di/injection_container.dart`). Android draws it from its alpha only, so it is the
app logo as a white silhouette on transparent, 24 dp. `tool/icons/notification_icon.py` generates it from shapes
traced from `assets/images/app_logo.png`; edit the shapes there and run it from the repository root
(`python3 tool/icons/notification_icon.py preview.png` also saves a large preview, which needs Pillow).
`android/app/src/main/res/raw/keep.xml` keeps the drawable through resource shrinking, because the plugin looks it
up by name.
