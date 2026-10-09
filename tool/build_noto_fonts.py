"""Instantiate bundled regular/bold Noto Sans JP from Google's variable font.
Requires fontTools. Usage: python tool/build_noto_fonts.py 'NotoSansJP[wght].ttf' assets/fonts
Source: https://github.com/google/fonts/tree/main/ofl/notosansjp
Keep the original OFL alongside the generated font files.
"""
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
for weight, name in [(400, 'Regular'), (700, 'Bold')]:
    font = instantiateVariableFont(TTFont(args.source), {'wght': weight}, inplace=True)
    font.save(args.output / f'NotoSansJP-{name}.ttf')
