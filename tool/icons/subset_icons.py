#!/usr/bin/env python3
"""Rebuilds the vendored icon font and the OsdIcons constants from icons.txt.

Reads   tool/icons/icons.txt
Writes  assets/fonts/MaterialSymbolsRounded-Subset.ttf
        lib/theme/osd_icons.dart

The source font and the name -> code point table come from the
material_symbols_icons package in the pub cache. That package is not a
dependency of the app; fetch it once with
`dart pub cache add material_symbols_icons --version 4.2960.0`.

Run from the repo root (needs fontTools: `pip install --user fonttools`):

    python3 tool/icons/subset_icons.py [--package-dir <material_symbols_icons dir>]

The subset keeps every variation axis (FILL, GRAD, opsz, wght) and the GSUB
feature variations that swap in the filled glyphs at FILL 1, so
`Icon(OsdIcons.x, fill: 1)` keeps working. See README.md.
"""

import argparse
import glob
import keyword
import os
import re
import subprocess
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ICON_LIST = os.path.join('tool', 'icons', 'icons.txt')
FONT_OUT = os.path.join('assets', 'fonts', 'MaterialSymbolsRounded-Subset.ttf')
DART_OUT = os.path.join('lib', 'theme', 'osd_icons.dart')
FONT_FAMILY = 'MaterialSymbolsRounded'
EXPECTED_AXES = ['FILL', 'GRAD', 'opsz', 'wght']

# Words a generated Dart identifier must not collide with.
DART_RESERVED = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', 'catch', 'class',
    'const', 'continue', 'covariant', 'default', 'deferred', 'do', 'dynamic', 'else', 'enum',
    'export', 'extends', 'extension', 'external', 'factory', 'false', 'final', 'finally', 'for',
    'function', 'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is', 'late',
    'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this', 'throw',
    'true', 'try', 'type', 'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
    'all', 'fontFamily', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod',
}


def find_package_dir():
    pattern = os.path.expanduser('~/.pub-cache/hosted/pub.dev/material_symbols_icons-*')
    candidates = sorted(glob.glob(pattern))
    if not candidates:
        raise SystemExit(
            'material_symbols_icons is not in the pub cache. Run '
            '`dart pub cache add material_symbols_icons` or pass --package-dir.'
        )
    return candidates[-1]


def read_icon_list():
    icons = []
    with open(ICON_LIST, encoding='utf-8') as f:
        for number, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            name = parts[0]
            flags = set(parts[1:])
            unknown = flags - {'rtl'}
            if unknown:
                raise SystemExit(f'{ICON_LIST}:{number}: unknown flag(s) {sorted(unknown)}')
            icons.append((name, 'rtl' in flags))
    names = [name for name, _ in icons]
    duplicates = sorted({n for n in names if names.count(n) > 1})
    if duplicates:
        raise SystemExit(f'{ICON_LIST}: duplicate names {duplicates}')
    return sorted(icons)


def read_codepoints(package_dir):
    path = os.path.join(package_dir, 'lib', 'iconname_to_unicode_map.dart')
    table = {}
    with open(path, encoding='utf-8') as f:
        for match in re.finditer(r"'([a-z0-9_]+)': 0x([0-9a-fA-F]+)", f.read()):
            table[match.group(1)] = int(match.group(2), 16)
    return table


def dart_name(icon_name):
    head, *tail = icon_name.split('_')
    name = head + ''.join(part[:1].upper() + part[1:] for part in tail)
    if not re.match(r'^[a-z][A-Za-z0-9]*$', name) or name in DART_RESERVED or keyword.iskeyword(name):
        name = f'{name}Icon'
    return name


def subset_font(source_font, codepoints):
    options = subset.Options()
    options.layout_features = ['*']  # keeps rclt/rlig and the FILL feature variations
    options.name_IDs = ['*']  # keeps the fvar/STAT axis and instance names
    options.name_languages = ['*']
    options.notdef_outline = True
    font = subset.load_font(source_font, options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=sorted(codepoints))
    subsetter.subset(font)
    subset.save_font(font, FONT_OUT, options)


def verify_font(codepoints):
    font = TTFont(FONT_OUT)
    axes = sorted(axis.axisTag for axis in font['fvar'].axes)
    if axes != sorted(EXPECTED_AXES):
        raise SystemExit(f'{FONT_OUT}: axes {axes}, expected {sorted(EXPECTED_AXES)}')
    cmap = font.getBestCmap()
    missing = sorted(hex(cp) for cp in codepoints if cp not in cmap)
    if missing:
        raise SystemExit(f'{FONT_OUT}: code points missing after subsetting: {missing}')
    if getattr(font['GSUB'].table, 'FeatureVariations', None) is None:
        raise SystemExit(f'{FONT_OUT}: the GSUB feature variations (filled glyphs) were dropped')
    return len(cmap), font['maxp'].numGlyphs


def write_dart(icons, table, package_dir):
    package = os.path.basename(package_dir.rstrip(os.sep))
    lines = [
        '// GENERATED FILE. DO NOT EDIT BY HAND.',
        '//',
        f'// Built by tool/icons/subset_icons.py from tool/icons/icons.txt and the',
        f'// MaterialSymbolsRounded.ttf of {package}.',
        '// To add an icon, follow tool/icons/README.md.',
        '',
        "import 'package:flutter/widgets.dart';",
        '',
        '/// The Material Symbols Rounded glyphs the app uses.',
        '///',
        '/// They draw from `assets/fonts/MaterialSymbolsRounded-Subset.ttf`, a subset of',
        '/// the variable font that keeps the FILL, GRAD, opsz and wght axes, so',
        '/// `Icon(OsdIcons.movie, fill: 1, weight: 400, opticalSize: 24)` works. Only',
        '/// the icons listed here are in the font. Glyphs marked "mirrors in RTL" set',
        '/// [IconData.matchTextDirection], so [Icon] flips them in right-to-left',
        '/// layouts.',
        'abstract final class OsdIcons {',
        '  /// The font family registered in `pubspec.yaml`.',
        f"  static const String fontFamily = '{FONT_FAMILY}';",
        '',
    ]
    for name, rtl in icons:
        codepoint = table[name]
        suffix = ' Mirrors in RTL.' if rtl else ''
        mirror = ', matchTextDirection: true' if rtl else ''
        lines.append(f'  /// `{name}`.{suffix}')
        lines.append(
            f'  static const IconData {dart_name(name)} = IconData('
            f'0x{codepoint:04x}, fontFamily: fontFamily{mirror});'
        )
        lines.append('')
    lines.append('  /// Every icon above, keyed by its Material Symbols name.')
    lines.append('  static const Map<String, IconData> all = <String, IconData>{')
    for name, _ in icons:
        lines.append(f"    '{name}': {dart_name(name)},")
    lines.append('  };')
    lines.append('}')
    with open(DART_OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    try:
        subprocess.run(['dart', 'format', DART_OUT], check=True, capture_output=True)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'warning: could not run `dart format {DART_OUT}`: {error}', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--package-dir', help='material_symbols_icons package directory')
    args = parser.parse_args()
    package_dir = args.package_dir or find_package_dir()
    source_font = os.path.join(package_dir, 'lib', 'fonts', 'MaterialSymbolsRounded.ttf')

    icons = read_icon_list()
    table = read_codepoints(package_dir)
    unknown = [name for name, _ in icons if name not in table]
    if unknown:
        raise SystemExit(f'Not Material Symbols names: {unknown}')
    codepoints = {table[name] for name, _ in icons}

    subset_font(source_font, codepoints)
    mapped, glyphs = verify_font(codepoints)
    write_dart(icons, table, package_dir)
    print(
        f'{FONT_OUT}: {len(icons)} icons, {mapped} mapped code points, {glyphs} glyphs, '
        f'{os.path.getsize(FONT_OUT)} bytes (source {os.path.getsize(source_font)} bytes)'
    )
    print(f'{DART_OUT}: {len(icons)} constants')


if __name__ == '__main__':
    main()
