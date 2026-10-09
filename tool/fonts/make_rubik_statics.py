#!/usr/bin/env python3
"""Builds the four static Rubik weights the app bundles.

Flutter does not map FontWeight onto a variable font's `wght` axis on every
platform, so the app ships static instances:

    assets/fonts/Rubik-Regular.ttf   (400)
    assets/fonts/Rubik-Medium.ttf    (500)
    assets/fonts/Rubik-SemiBold.ttf  (600)
    assets/fonts/Rubik-Bold.ttf      (700)

Usage (from the repo root; needs fontTools, `pip install --user fonttools`):

    curl -sSL -o /tmp/Rubik-VF.ttf \
      'https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf'
    python3 tool/fonts/make_rubik_statics.py /tmp/Rubik-VF.ttf

The licence (SIL OFL 1.1) is `assets/fonts/Rubik-OFL.txt`, from
https://github.com/google/fonts/raw/main/ofl/rubik/OFL.txt.
"""

import os
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

WEIGHTS = {
    400: 'Regular',
    500: 'Medium',
    600: 'SemiBold',
    700: 'Bold',
}

OUT_DIR = os.path.join('assets', 'fonts')


def main(variable_font_path):
    for weight, style in WEIGHTS.items():
        font = TTFont(variable_font_path)
        static = instancer.instantiateVariableFont(
            font,
            {'wght': weight},
            updateFontNames=True,
        )
        # The instancer sets usWeightClass from the pinned axis; check it so a
        # broken source font can't ship the wrong weight under the right name.
        actual = static['OS/2'].usWeightClass
        if actual != weight:
            raise SystemExit(f'Rubik-{style}: usWeightClass {actual}, expected {weight}')
        out = os.path.join(OUT_DIR, f'Rubik-{style}.ttf')
        static.save(out)
        print(f'{out}: weight {weight}, {os.path.getsize(out)} bytes')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
