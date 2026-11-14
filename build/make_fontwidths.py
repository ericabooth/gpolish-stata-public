"""Build the character-width tables that gpolish embeds (ASCII 32-126, in ems).
Usage: python make_fontwidths.py > fontwidths.mata.txt"""
import sys, json, warnings
warnings.filterwarnings("ignore")
from matplotlib import font_manager as fm
from matplotlib.ft2font import FT2Font, LoadFlags
FONTS = ["Open Sans", "Helvetica", "Helvetica Neue", "Arial", "Arial Narrow", "Verdana", "Tahoma", "Trebuchet MS",
         "Calibri", "Lato", "Roboto", "Source Sans Pro", "Source Sans 3", "Inter", "Avenir", "Gill Sans",
         "Times New Roman", "Times", "Georgia", "Palatino", "EB Garamond", "Garamond", "Courier New", "Menlo"]
def widths(path):
    f = FT2Font(path); upm = f.units_per_EM
    return [round(f.load_char(c, flags=LoadFlags.NO_SCALE).horiAdvance / upm, 3) for c in range(32, 127)]
out = {}
for name in FONTS:
    try:
        reg = fm.findfont(fm.FontProperties(family=name, weight="regular"), fallback_to_default=False)
    except Exception:
        continue
    r = widths(reg)
    try:
        bp = fm.findfont(fm.FontProperties(family=name, weight="bold"), fallback_to_default=False)
        b = widths(bp) if bp != reg else [round(x * 1.06, 3) for x in r]
    except Exception:
        b = [round(x * 1.06, 3) for x in r]
    out[name.lower()] = (r, b)
json.dump(out, sys.stdout)
