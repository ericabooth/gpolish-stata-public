#!/usr/bin/env python
"""gr2mpl_render.py: draw a Stata graph spec (written by gr2mpl.ado) with matplotlib.

Usage:
    python gr2mpl_render.py /path/to/spec.json
    python gr2mpl_render.py --doctor [fontname]

Needs matplotlib and numpy only. Works as a shell script or through Stata's
embedded Python (`python script gr2mpl_render.py, args(spec.json)`).
"""
import csv
import datetime as dt
import html
import json
import logging
import math
import os
import re
import sys

import numpy as np

import matplotlib

matplotlib.use("Agg")
# fallback fonts without a bold face are reported once per text; that is expected
logging.getLogger("matplotlib.font_manager").setLevel(logging.ERROR)
import matplotlib.pyplot as plt  # noqa: E402
import matplotlib.patheffects as pe  # noqa: E402
from matplotlib import font_manager  # noqa: E402
from matplotlib.colors import to_rgba  # noqa: E402
from matplotlib.transforms import Bbox  # noqa: E402
from matplotlib.offsetbox import AnnotationBbox, DrawingArea  # noqa: E402
from matplotlib.patches import FancyBboxPatch, Polygon, Rectangle  # noqa: E402

# Stata draws a marker of size s about 4/pi times wider than s in points; this factor
# makes matplotlib's marker diameter match Stata's at msscale(1)
MSTATA = 4.0 / math.pi

# oldest matplotlib the renderer supports: Axes.legend(alignment=) arrived in 3.6
MIN_MPL = (3, 6)
# a plot-region margin wider than this (Stata's relative units) is kept exactly;
# narrower ones, which include the default margins of Stata's schemes and of
# pypolish (3 or less), give way to gr2mpl's own padding
MARGIN_KEEP = 4.0
INK = "#1F2328"
MUTED = "#6B7280"
GRID = "#E5E7EB"
AXIS = "#9CA3AF"
HOUSE = ["#1F6FB2", "#D1495B", "#2E9E6B", "#E0A100", "#6C4AB6", "#00A0B0",
         "#C2571A", "#7A7F87"]
FONT_FALLBACKS = ["Open Sans", "Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans"]
# fonts tried, glyph by glyph, for characters the main font lacks (CJK and symbols)
GLYPH_FALLBACKS = ["Hiragino Sans", "Hiragino Sans GB", "PingFang SC", "Apple SD Gothic Neo",
                   "Noto Sans CJK JP", "Noto Sans CJK SC", "Microsoft YaHei", "Yu Gothic",
                   "Malgun Gothic", "Arial Unicode MS", "DejaVu Sans"]
STATA_NAMED = {
    "black": "#000000", "white": "#FFFFFF", "red": "#FF0000", "blue": "#0000FF",
    "green": "#008000", "navy": "#1A476F", "maroon": "#90353B", "gray": "#808080",
    "grey": "#808080", "orange": "#FFA500", "teal": "#6E8E84", "cranberry": "#C10534",
    "dkgreen": "#55752F", "dknavy": "#0B2D52", "ltblue": "#ADD8E6", "gold": "#FFD200",
    "forest_green": "#228B22", "dkorange": "#E37E00", "purple": "#800080",
    "yellow": "#FFFF00", "cyan": "#00FFFF", "magenta": "#FF00FF", "brown": "#9C8847",
}
MARKERS = {
    "circle": "o", "smcircle": "o", "circle_hollow": "o", "smcircle_hollow": "o",
    "diamond": "D", "smdiamond": "D", "diamond_hollow": "D", "smdiamond_hollow": "D",
    "triangle": "^", "smtriangle": "^", "triangle_hollow": "^", "smtriangle_hollow": "^",
    "square": "s", "smsquare": "s", "square_hollow": "s", "smsquare_hollow": "s",
    "plus": "P", "smplus": "P", "x": "X", "smx": "X", "point": ".",
    "arrow": ">", "arrowf": ">", "pipe": "|", "v": "v", "smv": "v",
}
DASHES = {
    "solid": "-", "dash": (0, (5, 3)), "longdash": (0, (9, 3)), "shortdash": (0, (3, 2)),
    "dot": (0, (1, 2)), "dash_dot": (0, (5, 2, 1, 2)), "longdash_dot": (0, (9, 2, 1, 2)),
    "shortdash_dot": (0, (3, 2, 1, 2)), "tight_dot": (0, (1, 1)), "blank": "None",
}
LINE_TYPES = {"line", "connected"}
# connect() styles drawn as steps
STEPS = {"stairstep": "steps-post", "j": "steps-post", "stepstair": "steps-pre"}
PC_TYPES = {"pcspike", "pcarrow", "pcbarrow", "pccapsym", "pcscatter", "pcbarrowi",
            "pcarrowi", "pci"}
SUPPORTED = {"line", "connected", "scatter", "bar", "area", "spike", "dropline", "dot",
             "rarea", "rbar", "rcap", "rspike", "rline", "rconnected", "rscatter",
             "rcapsym"} | PC_TYPES
ALIGN = {
    "east": ("left", "center"), "west": ("right", "center"),
    "north": ("center", "bottom"), "south": ("center", "top"),
    "center": ("center", "center"), "": ("center", "center"),
    "neast": ("left", "bottom"), "nwest": ("right", "bottom"),
    "seast": ("left", "top"), "swest": ("right", "top"),
    "ne": ("left", "bottom"), "nw": ("right", "bottom"),
    "se": ("left", "top"), "sw": ("right", "top"),
    "e": ("left", "center"), "w": ("right", "center"),
    "n": ("center", "bottom"), "s": ("center", "top"), "c": ("center", "center"),
}
ANGLES = {"horizontal": 0.0, "vertical": 90.0, "rvertical": 270.0, "rhorizontal": 180.0,
          "default": 0.0, "": 0.0}


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def num(v, default=None):
    try:
        if v is None or v == "" or v == ".":
            return default
        f = float(v)
        return default if math.isnan(f) else f
    except (TypeError, ValueError):
        return default


def stata_color(s, default=None):
    """'26 133 255 %100', 'gs12', 'navy%50', 'none' -> rgba tuple or default."""
    if s is None:
        return default
    s = str(s).strip()
    if s == "" or s == ".":
        return default
    opacity = 1.0
    m = re.search(r"%\s*(\d+(\.\d+)?)", s)
    if m:
        opacity = float(m.group(1)) / 100.0
        s = s[: m.start()].strip()
    inten = 1.0
    m = re.search(r"\*\s*(\d*\.?\d+)", s)
    if m:
        inten = float(m.group(1))
        s = s[: m.start()].strip()
    if s in ("none", "bg", "background"):
        return (1, 1, 1, 0) if s == "none" else (1, 1, 1, 1)
    parts = s.split()
    if len(parts) == 3 and all(p.replace(".", "").isdigit() for p in parts):
        rgb = tuple(min(255.0, float(p)) / 255.0 for p in parts)
    elif re.fullmatch(r"gs\d+", s):
        g = int(s[2:]) / 16.0
        rgb = (g, g, g)
    elif s in STATA_NAMED:
        rgb = to_rgba(STATA_NAMED[s])[:3]
    else:
        try:
            rgb = to_rgba(s)[:3]
        except ValueError:
            return default
    if inten != 1.0:
        if inten < 1:
            rgb = tuple(1 - (1 - c) * inten for c in rgb)
        else:
            rgb = tuple(max(0.0, c * (2 - inten)) for c in rgb)
    return (rgb[0], rgb[1], rgb[2], opacity)


SUPER = dict(zip("0123456789+-=()niabcdefghijklmoprstuvwxyzABDEGHIJKLMNOPRTUVW",
                 "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼"
                 "⁽⁾ⁿⁱᵃᵇᶜᵈᵉᶠᵍʰⁱ"
                 "ʲᵏˡᵐᵒᵖʳˢᵗᵘᵛʷˣ"
                 "ʸᶻᴬᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹ"
                 "ᴺᴼᴾᴿᵀᵁⱽᵂ"))
SUB = dict(zip("0123456789+-=()aehijklmnoprstuvx",
               "₀₁₂₃₄₅₆₇₈₉₊₋₌"
               "₍₎ₐₑₕᵢⱼₖₗₘₙₒₚ"
               "ᵣₛₜᵤᵥₓ"))
# Stata names that are not HTML entity names
STATA_ENTITIES = {"Inf": "∞", "inf": "∞", "minus": "−"}


def _entity(m):
    name = m.group(1)
    if name in STATA_ENTITIES:
        return STATA_ENTITIES[name]
    ch = html.unescape("&" + name + ";")
    return ch if ch != "&" + name + ";" else name


def _script(m):
    table = SUPER if m.group(1) == "sup" else SUB
    txt = m.group(2)
    if all(c in table or c == " " for c in txt):
        return "".join(table.get(c, c) for c in txt)
    return txt


def _char(m):
    v = m.group(1)
    try:
        return chr(int(v, 16) if v.lower().startswith("0x") else int(v))
    except (ValueError, OverflowError):
        return m.group(0)


_TOGGLES = r"\{(bf|it|sf|rm|stSerif|stSans|stMono|stSymbol)\}"


def _bold_toggles(s):
    """Rewrite SMCL toggle tags as {bf:...} runs: {bf} turns bold on until the next
    {sf}, {rm} or {it}; the other toggles are dropped (italic is drawn upright)."""
    if not re.search(_TOGGLES, s):
        return s
    out, bold = [], False
    for k, part in enumerate(re.split(_TOGGLES, s)):
        if k % 2 == 1:
            if part == "bf":
                bold = True
            elif part in ("sf", "rm", "it"):
                bold = False
            continue
        if not part:
            continue
        if not bold:
            out.append(part)
            continue
        # inside a bold run an explicit {bf:...} is already bold: unwrap it so the run
        # stays one bold segment; text with a literal brace is left as typed
        for piece in re.split(r"\{bf:([^}]*)\}", part):
            if piece:
                out.append("{bf:" + piece + "}" if "}" not in piece and "{" not in piece else piece)
    return "".join(out)


def _strip_tags(s):
    s = re.sub(r"\{c (0[xX][0-9a-fA-F]+|\d+)\}", _char, s)
    s = re.sub(r"\{&([a-zA-Z]+[0-9]*)\}", _entity, s)
    s = re.sub(r"\{(sup|sub):([^}]*)\}", _script, s)
    s = re.sub(r"\{(it|bind|stSerif|stSans|stMono|stSymbol):([^}]*)\}", r"\2", s)
    s = re.sub(r"\{fontface [^:}]*:([^}]*)\}", r"\1", s)
    return s


def tick_text(s):
    """A tick label given as compound-quoted lines ("Line A" "Line B") -> two lines."""
    s = s or ""
    parts = re.findall(r'"([^"]*)"', s)
    if len(parts) >= 2 and re.fullmatch(r'\s*("[^"]*"\s*)+', s):
        return "\n".join(clean_text(x) for x in parts)
    return clean_text(s)


def stata_format(v, fmt):
    """A number shown with a Stata display format (%9.0g, %4.1f, %9.2fc, %8.0e)."""
    fmt = (fmt or "").strip()
    m = re.fullmatch(r"%-?0?(\d*)\.(\d+)(f|g|e)(c?)", fmt)
    if m and m.group(3) == "f":
        out = f"{v:,.{int(m.group(2))}f}" if m.group(4) else f"{v:.{int(m.group(2))}f}"
        return out
    if m and m.group(3) == "e":
        return f"{v:.{int(m.group(2))}e}"
    # %g and anything else: drop the float noise a Stata float carries
    out = f"{float(np.float32(v)):.7g}" if abs(v) < 1e7 else f"{v:.10g}"
    if m and m.group(4):
        try:
            f = float(out)
            if f == int(f) and "e" not in out:
                out = f"{int(f):,}"
        except ValueError:
            pass
    return out


def clean_text(s):
    """Plain text: SMCL tags dropped, dollar signs escaped (not math)."""
    if not s:
        return ""
    s = re.sub(r"\{bf:([^}]*)\}", r"\1", _bold_toggles(_strip_tags(s)))
    return s.replace("$", r"\$")


def rich_segments(s):
    """One line -> [(text, is_bold), ...] honouring {bf:...}."""
    parts = re.split(r"\{bf:([^}]*)\}", _bold_toggles(_strip_tags(s or "")))
    return [(part.replace("$", r"\$"), k % 2 == 1) for k, part in enumerate(parts) if part]


def join_lines(lines):
    return "\n".join(clean_text(x) for x in (lines or []) if x is not None).strip()


def pick_font(want):
    names = {f.name for f in font_manager.fontManager.ttflist}
    for cand in [want] + FONT_FALLBACKS:
        if cand and cand in names:
            return cand
    return "DejaVu Sans"


def luminance(rgba):
    r, g, b = rgba[:3]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def darken_for_text(rgba, floor=0.62):
    """Light series colours (yellow) are unreadable as text; darken them."""
    lum = luminance(rgba)
    if lum <= floor:
        return rgba
    k = floor / lum
    return (rgba[0] * k, rgba[1] * k, rgba[2] * k, 1)


def repel_1d(pos, sep, lo, hi):
    """Push 1-D positions apart to a minimum separation, keeping their order."""
    pos = np.asarray(pos, dtype=float)
    order = np.argsort(pos)
    g = pos[order].copy()
    n = len(g)
    for _ in range(600):
        moved = False
        for i in range(n - 1):
            d = sep - (g[i + 1] - g[i])
            if d > 1e-9:
                g[i] -= d / 2
                g[i + 1] += d / 2
                moved = True
        if n and g[0] < lo:
            g[0] = lo
        if n and g[-1] > hi:
            g[-1] = hi
        if not moved:
            break
    out = np.empty(n)
    out[order] = g
    return out


def legend_perm(n, ncol, colfirst=False):
    """Indices of n legend keys in the order matplotlib places them, so that a
    legend with ncol columns reads row by row, as Stata fills it. matplotlib fills
    column by column; with colfirst (Stata's legend(colfirst)) no change is made."""
    ncol = max(1, min(ncol, n))
    if colfirst or ncol == 1:
        return list(range(n))
    rows = -(-n // ncol)
    return [r * ncol + c for c in range(ncol) for r in range(rows) if r * ncol + c < n]


def legend_reading(leg, r):
    """Legend texts in reading order (top row first, then left to right)."""
    ts = []
    for t in leg.get_texts():
        b = t.get_window_extent(r)
        # rows are told apart by the text anchor, which descenders do not move
        y = t.get_transform().transform(t.get_position())[1]
        ts.append((-round(y / 3.0), b.x0, t.get_text()))
    ts.sort(key=lambda e: (e[0], e[1]))
    return [e[2] for e in ts]


def read_csv_columns(path):
    """CSV -> list of columns (lists of strings), addressed by position."""
    with open(path, newline="", encoding="utf-8") as fh:
        rows = list(csv.reader(fh))
    if not rows:
        return []
    ncol = len(rows[0])
    body = rows[1:]
    return [[(r[c] if c < len(r) else "") for r in body] for c in range(ncol)]


def to_float(col):
    out = np.empty(len(col))
    for k, v in enumerate(col):
        try:
            out[k] = float(v) if v not in ("", ".") else np.nan
        except ValueError:
            out[k] = np.nan
    return out


def parse_angle(t):
    for key in ("angle", "orientation"):
        v = str(t.get(key, "")).strip().lower()
        if v in ANGLES:
            if ANGLES[v]:
                return ANGLES[v]
            continue
        f = num(v)
        if f:
            return f
    return 0.0


def nice_dates(pos, labs, fmt=""):
    """Stata's default %td labels (01jan2001) read better as 'Jan 2001'. Labels are
    rewritten only on a daily-date axis and only when every label is the %td
    rendering of its own tick position; custom label text is kept."""
    if not labs or not all(re.fullmatch(r"\d{2}[a-z]{3}\d{4}", l or "") for l in labs):
        return labs
    fmt = (fmt or "").strip().lower()
    if fmt and not (fmt.startswith("%td") or fmt.startswith("%d") or fmt.startswith("%-td")):
        return labs
    base = dt.date(1960, 1, 1)
    try:
        dates = [base + dt.timedelta(days=int(round(p))) for p in pos]
    except (OverflowError, ValueError):
        return labs
    if any(d.strftime("%d%b%Y").lower() != l for d, l in zip(dates, labs)):
        return labs
    if all(d.day == 1 for d in dates):
        out = []
        for k, d in enumerate(dates):
            show_year = k == 0 or d.year != dates[k - 1].year
            out.append(d.strftime("%b %Y") if show_year else d.strftime("%b"))
        return out
    return [f"{d.strftime('%b')} {d.day}, {d.year}" for d in dates]


# --------------------------------------------------------------------------
# one panel: a twoway or bar-family graph drawn on one Axes
# --------------------------------------------------------------------------
class Panel:
    def __init__(self, fig, spec, ax, index):
        self.f = fig
        self.s = spec
        self.ax = ax
        self.ax2 = None
        self.index = index
        self.infos = []
        self.horizontal = False
        self.has_legend = False
        self.axis_off = set()
        self._slots = {}
        self._margins = []
        self.leg = None
        self._leg_args = None
        # text sizes Stata used for this panel; graph combine shrinks its members
        self.gmult = num(spec.get("gmult"), 1.0) or 1.0
        if spec.get("family") == "bar":
            gx, gy = spec.get("gtick_size"), spec.get("stick_size")
            if spec.get("horizontal") == "yes":
                gx, gy = gy, gx
        else:
            gx = (spec.get("xaxis") or {}).get("ticksize")
            gy = (spec.get("yaxis") or {}).get("ticksize")
        self.xtickfs = fig.tsize(gx, fig.tickfs0, self.gmult)
        self.ytickfs = fig.tsize(gy, fig.tickfs0, self.gmult)
        self.tickfs = self.xtickfs
        self.style_axes(ax)

    # ---- small accessors ---------------------------------------------------
    def pts(self, v):
        return v * self.f.unit

    def text_fs(self, t):
        """Font size of a text box in points. graph combine and by() shrink the text
        of their panels (gmult), text() and gr_edit text included."""
        size = num(t.get("size"))
        return (self.pts(size) if size else 9.0 * self.f.k) * self.gmult

    def lw(self, p, key="lwidth", floor=0.6):
        v = num(p.get(key))
        if v is None:
            return max(floor, 1.2)
        return max(floor, self.pts(v) * self.f.lwscale)

    def ms(self, p, floor=2.0):
        v = num(p.get("msize"))
        if v is None:
            return 5.0 * MSTATA * self.f.k * self.f.msscale * self.gmult
        return max(floor, self.pts(v) * MSTATA * self.f.msscale * self.gmult)

    def skip(self, msg):
        where = f"panel {self.index + 1}: " if self.f.multi else ""
        self.f.skipped.append(where + msg)

    def style_axes(self, ax):
        for side in ("top", "right", "left"):
            ax.spines[side].set_visible(False)
        ax.spines["bottom"].set_color(AXIS)
        ax.spines["bottom"].set_linewidth(0.9)
        ax.tick_params(axis="x", length=0, labelsize=self.xtickfs, pad=5 * self.f.k)
        ax.tick_params(axis="y", length=0, labelsize=self.ytickfs, pad=5 * self.f.k)
        ax.set_axisbelow(True)

    def col(self, cols, p, key):
        i = int(num(p.get(key + "i"), 0) or 0)
        if 1 <= i <= len(cols):
            return cols[i - 1]
        return None

    def plot_color(self, p, key, i, fallback=None):
        c = stata_color(p.get(key), None)
        if self.f.palette == "house" and c is not None and c[3] > 0:
            r, g, b = c[:3]
            if max(r, g, b) - min(r, g, b) > 0.08:  # keep greys grey
                slot_key = " ".join(str(p.get("lcolor", "")).split()[:3])
                if slot_key not in self._slots:
                    self._slots[slot_key] = len(self._slots)
                h = to_rgba(HOUSE[self._slots[slot_key] % len(HOUSE)])
                c = (h[0], h[1], h[2], c[3])
        if c is None:
            c = fallback if fallback is not None else to_rgba(HOUSE[i % len(HOUSE)])
        return c

    def halo(self, artist):
        if not self.f.nohalo:
            artist.set_path_effects([pe.withStroke(linewidth=1.6, foreground="white",
                                                   alpha=0.9)])

    # ---- twoway -------------------------------------------------------------
    def draw_twoway(self):
        s = self.s
        # yaxis(1 2) puts no plot on the second axis but still draws it
        if s.get("y2axis") and (s["y2axis"].get("shared") or any(
                str(p.get("yaxis")) == "2" and str(p.get("xaxis", "1") or "1") == "1"
                for p in s.get("plots", []))):
            self.ax2 = self.ax.twinx()
            self.style_axes(self.ax2)
            self.ax2.spines["bottom"].set_visible(False)
            # filled layers on the second axis go behind the first axis
            fills = {"bar", "rbar", "area", "rarea", "spike"}
            plots = s.get("plots", [])
            on2 = [j for j, p in enumerate(plots) if str(p.get("yaxis")) == "2"]
            fills1 = [j for j, p in enumerate(plots) if str(p.get("yaxis")) != "2"
                      and p.get("type") in fills]
            # Stata draws plots in command order: put axis 2 behind only when its
            # fills come before every axis-1 fill
            behind = (bool(on2) and all(plots[j].get("type") in fills for j in on2)
                      and (not fills1 or max(on2) < min(fills1)))
            if behind:
                self.ax2.set_zorder(self.ax.get_zorder() - 1)
                self.ax.patch.set_visible(False)
            else:
                self.ax2.set_zorder(self.ax.get_zorder() + 1)
                self.ax2.patch.set_visible(False)
        for i, p in enumerate(s.get("plots", [])):
            info = self.draw_plot(p, i)
            if info:
                self.infos.append(info)
        self.apply_axes()
        self.reflines()
        for t in s.get("textboxes", []):
            ax = self.axis_for(t, "text()")
            if ax is not None:
                self.draw_text(t, keep_color=False, ax=ax)
        # gpolish adds its objects to Stata's first plot region, which belongs to the
        # second y axis when plot 1 is on yaxis(2)
        added = [t for t in s.get("added_text", []) if t.get("draw") != "no"]
        any_added = added or any(o.get("draw") != "no" for o in
                                 s.get("added_lines", []) + s.get("added_markers", []))
        added_ax = self.axis_for({"yaxis": s.get("added_yaxis", "1"),
                                  "xaxis": s.get("added_xaxis", "1")},
                                 "added text, lines and markers") if any_added else None
        if added_ax is not None:
            self.pair_end_values(added, added_ax)
            for t in added:
                self.draw_text(t, keep_color=True, ax=added_ax)
            self.added_shapes(added_ax)

    def axis_for(self, obj, what):
        """The Axes an object on yaxis(#)/xaxis(#) belongs to, or None (skipped)."""
        xa = str(obj.get("xaxis", "1") or "1").strip()
        ya = str(obj.get("yaxis", "1") or "1").strip()
        if xa != "1":
            self.skip(f"{what} on a second x axis")
            return None
        if ya == "2" and self.ax2 is not None:
            return self.ax2
        if ya not in ("1", "2"):
            self.skip(f"{what} on y axis {ya}")
            return None
        return self.ax

    def draw_plot(self, p, i):
        t = p.get("type", "")
        if p.get("draw") == "no":
            return None
        if t not in SUPPORTED:
            self.skip(f"plot {p.get('index')} (type {t})")
            return None
        xa = str(p.get("xaxis", "1") or "1").strip()
        ya = str(p.get("yaxis", "1") or "1").strip()
        if xa != "1":
            self.skip(f"plot {p.get('index')} (type {t}): second x axis")
            return None
        if ya not in ("1", "2"):
            self.skip(f"plot {p.get('index')} (type {t}): y axis {ya}")
            return None
        path = os.path.join(self.f.dir, p.get("csv", ""))
        if not os.path.exists(path):
            self.skip(f"plot {p.get('index')} (type {t}): no serset data")
            return None
        cols = self.f.data(path)
        xc, yc = self.col(cols, p, "x"), self.col(cols, p, "y")
        if xc is None or yc is None:
            self.skip(f"plot {p.get('index')} (type {t}): variables not found")
            return None
        x, y = to_float(xc), to_float(yc)
        y2c, x2c = self.col(cols, p, "y2"), self.col(cols, p, "x2")
        y2 = to_float(y2c) if y2c is not None else None
        x2 = to_float(x2c) if x2c is not None else None
        ax = self.ax2 if (self.ax2 is not None and str(p.get("yaxis")) == "2") else self.ax
        # Stata records `horizontal` only as bar_drop_to = y
        horizontal = str(p.get("dropto", "")).strip().lower() == "y"

        lc = self.plot_color(p, "lcolor", i)
        mfill = self.plot_color(p, "mfill", i, lc)
        mline = self.plot_color(p, "mline", i, lc)
        afill = self.plot_color(p, "afill", i, lc)
        dash = DASHES.get(p.get("lpattern", "solid"), "-")
        sym = str(p.get("msymbol", "circle"))
        marker = MARKERS.get(sym, "o")
        hollow = "hollow" in sym
        nomarker = sym in ("none", "i", "")
        z = 2 + i * 0.01
        steps = STEPS.get(str(p.get("connect", "")).strip().lower())
        bridge = str(p.get("cmissing", "")).strip().lower() not in ("no", "n")

        def joined(a, b):
            """Stata's default cmissing(y) draws the line across missing values."""
            if not bridge:
                return a, b
            ok = ~(np.isnan(a) | np.isnan(b))
            return a[ok], b[ok]

        line_kw = dict(drawstyle=steps) if steps else {}
        info = {"type": t, "color": lc, "x": x, "y": y, "handle": None, "p": p,
                "ax": ax}

        def marker_kw():
            if nomarker:
                return dict(marker="None")
            same = tuple(mline[:3]) == tuple(mfill[:3])
            mlw = num(p.get("mlwidth"))
            if mfill[3] == 0:
                # mcolor(none) or mfcolor(none): a hollow marker, outlined only when
                # the outline colour is visible, as Stata draws it
                edge = mline if mline[3] > 0 else "none"
                return dict(marker=marker, ms=self.ms(p), mfc="none", mec=edge,
                            mew=max(1.0, self.pts(mlw)) if mlw else 1.2)
            if hollow:
                return dict(marker=marker, ms=self.ms(p), mfc="white", mec=mline,
                            mew=max(1.0, self.pts(mlw)) if mlw else 1.2)
            size = self.ms(p)
            if same and (self.s.get("role") == "matrix" or size < 4.5 * MSTATA):
                # a white rim would eat a small marker; draw it solid instead
                return dict(marker=marker, ms=size, mfc=mfill, mec=mfill, mew=0.0)
            return dict(marker=marker, ms=size, mfc=mfill,
                        mec=mline if not same else "white",
                        mew=self.pts(mlw) if (mlw is not None and not same) else 0.6)

        if t == "line":
            (h,) = ax.plot(*joined(x, y), color=lc, lw=self.lw(p), ls=dash, zorder=z + 1,
                           solid_capstyle="round", solid_joinstyle="round", **line_kw)
            info["handle"] = h
        elif t in ("connected", "scatter"):
            ls = dash if t == "connected" else "None"
            if t == "connected":
                (h,) = ax.plot(*joined(x, y), color=lc, lw=self.lw(p), ls=ls, zorder=z + 1.5,
                               **line_kw, **marker_kw())
            else:
                (h,) = ax.plot(x, y, color=lc, lw=self.lw(p), ls=ls, zorder=z + 1.5,
                               **marker_kw())
            info["handle"] = h
            info["color"] = lc if t == "connected" else (
                mline if (hollow or mfill[3] == 0) else mfill)
            self.point_labels(ax, cols, x, y, p)
        elif t in ("bar", "rbar"):
            width = num(p.get("barsize"), 0.8) or 0.8
            base = num(p.get("base"), 0.0)
            lo = y2 if (t == "rbar" and y2 is not None) else np.full_like(y, base)
            # white separators suit bars that are a few pixels wide; narrow bars
            # (a default barwidth on a wide continuous axis) are outlined in their
            # own colour, as Stata does, so they still draw as at least a hairline
            fx = x[np.isfinite(x)] if len(x) else x
            span = float(np.nanmax(fx) - np.nanmin(fx)) if len(fx) > 1 else 0.0
            narrow = span > 0 and width / (span + width) < 0.005
            edge = afill if narrow else "white"
            if afill[3] == 0:
                # fcolor(none): no fill, as Stata draws it; keep only a visible outline
                aline = self.plot_color(p, "aline", i, lc)
                edge = aline if aline[3] > 0 else "none"
            kw = dict(color=afill, lw=0.6, edgecolor=edge, zorder=z)
            if horizontal:
                h = ax.barh(x, y - lo, left=lo, height=width, **kw)
            else:
                h = ax.bar(x, y - lo, bottom=lo, width=width, **kw)
            info.update(handle=h, color=afill, bars=True, horizontal=horizontal,
                        barwidth=width, outlined=afill[3] == 0,
                        base=float(np.nanmin(lo)) if len(lo) else base)
        elif t == "area" and str(p.get("dropbase", "")).strip() == "no":
            # nodropbase areas are closed polygons separated by missing rows
            # (heatplot cells, hexagons, map-like shapes)
            col = afill
            first = None
            start = 0
            pts_x, pts_y = list(x) + [np.nan], list(y) + [np.nan]
            for k in range(len(pts_x)):
                if np.isnan(pts_x[k]) or np.isnan(pts_y[k]):
                    if k - start >= 3:
                        poly = Polygon(np.column_stack([pts_x[start:k], pts_y[start:k]]),
                                       closed=True, facecolor=col, edgecolor=col,
                                       linewidth=0.3, zorder=z)
                        ax.add_patch(poly)
                        first = first or poly
                    start = k + 1
            info.update(handle=Rectangle((0, 0), 1, 1, facecolor=col, edgecolor="none"),
                        color=afill, poly=True)
        elif t == "area":
            base = num(p.get("base"))
            if base is None:
                base = num(p.get("drawnbase"), 0.0) or 0.0
            col = afill if afill[3] < 1 else (afill[0], afill[1], afill[2], 0.85)
            edge = afill[:3]
            if afill[3] == 0:
                # color(none): no fill; the outline takes lcolor(), as in Stata
                aline = self.plot_color(p, "aline", i, lc)
                edge = aline if aline[3] > 0 else None
            if horizontal:
                h = ax.fill_betweenx(x, base, y, color=col, lw=0, zorder=z)
                if edge is not None:
                    ax.plot(y, x, color=edge, lw=1.2, zorder=z + 0.5)
            else:
                h = ax.fill_between(x, base, y, color=col, lw=0, zorder=z)
                if edge is not None:
                    ax.plot(x, y, color=edge, lw=1.2, zorder=z + 0.5)
            if afill[3] == 0 and edge is not None:
                # the legend key is an outlined box, as the area is drawn
                h = Rectangle((0, 0), 1, 1, facecolor="none", edgecolor=edge, lw=1.2)
            info.update(handle=h, color=afill if edge is None or afill[3] > 0 else edge,
                        horizontal=horizontal)
        elif t == "rarea":
            if y2 is None:
                return None
            col = afill
            if col[3] >= 1:
                col = (col[0], col[1], col[2], 0.55 if luminance(col) > 0.75 else 0.28)
            if horizontal:
                h = ax.fill_betweenx(x, y, y2, color=col, lw=0, zorder=1.5)
            else:
                h = ax.fill_between(x, y, y2, color=col, lw=0, zorder=1.5)
            shown = afill
            if afill[3] == 0:
                # color(none): no fill; both edges are drawn in lcolor() when it is
                # visible, as Stata outlines the band
                aline = self.plot_color(p, "aline", i, lc)
                if aline[3] > 0:
                    lw = self.lw(p, floor=0.8)
                    for edge_y in (y, y2):
                        if horizontal:
                            ax.plot(edge_y, x, color=aline, lw=lw, zorder=1.6)
                        else:
                            ax.plot(x, edge_y, color=aline, lw=lw, zorder=1.6)
                    shown = aline
                    h = Rectangle((0, 0), 1, 1, facecolor="none", edgecolor=aline, lw=lw)
            info.update(handle=h, color=shown, band=True, narrow_horizontal=horizontal)
        elif t in ("rcap", "rspike", "rcapsym"):
            if y2 is None:
                return None
            lw = self.lw(p, floor=0.9)
            if horizontal:
                h = ax.hlines(x, y, y2, color=lc, lw=lw, zorder=z + 1, capstyle="round")
            else:
                h = ax.vlines(x, y, y2, color=lc, lw=lw, zorder=z + 1, capstyle="round")
            cap = num(p.get("msize"), 0.0) or 0.0
            if t == "rcap" and cap > 0:
                kw = dict(ls="None", marker="|" if horizontal else "_", ms=self.pts(cap) * 1.6,
                          mew=lw, mec=lc, zorder=z + 1)
                if horizontal:
                    ax.plot(np.r_[y, y2], np.r_[x, x], **kw)
                else:
                    ax.plot(np.r_[x, x], np.r_[y, y2], **kw)
            info.update(handle=h, band=True, horizontal=horizontal)
        elif t in ("rline", "rconnected", "rscatter"):
            if y2 is None:
                return None
            ls = "None" if t == "rscatter" else dash
            mk = marker_kw() if t != "rline" else {}
            kw = dict(color=lc, lw=self.lw(p, floor=0.8), ls=ls, zorder=z + 1, **mk)
            if t != "rscatter":
                kw.update(line_kw)
            if horizontal:
                (h,) = ax.plot(*joined(y, x), **kw)
                ax.plot(*joined(y2, x), **kw)
            else:
                (h,) = ax.plot(*joined(x, y), **kw)
                ax.plot(*joined(x, y2), **kw)
            info.update(handle=h, band=True, horizontal=horizontal)
        elif t in ("spike", "dropline", "dot"):
            base = num(p.get("base"))
            if base is None:
                base = num(p.get("drawnbase"), 0.0) or 0.0
            if t != "dot":
                if horizontal:
                    ax.hlines(x, base, y, color=lc, lw=self.lw(p, floor=0.9), zorder=z)
                else:
                    ax.vlines(x, base, y, color=lc, lw=self.lw(p, floor=0.9), zorder=z)
            if t in ("dropline", "dot"):
                mx, my = (y, x) if horizontal else (x, y)
                (h,) = ax.plot(mx, my, ls="None", zorder=z + 1, **marker_kw())
                info["handle"] = h
            else:
                info["handle"] = plt.Line2D([], [], color=lc, lw=1.5)
            info["horizontal"] = horizontal
            if t in ("dropline", "dot"):
                self.point_labels(ax, cols, *((y, x) if horizontal else (x, y)), p)
        elif t in PC_TYPES:
            if y2 is None or x2 is None:
                self.skip(f"plot {p.get('index')} (type {t}): second coordinates not found")
                return None
            labcols = (x, y)  # marker labels sit at the start point
            if horizontal:  # stored unswapped; Stata swaps the axes when drawing
                x, y, x2, y2 = y, x, y2, x2
                info["horizontal"] = True
                labcols = (x, y)
            lw = self.lw(p, floor=0.9)
            arrow = {"pcarrow": "-|>", "pcarrowi": "-|>", "pcbarrow": "<|-|>",
                     "pcbarrowi": "<|-|>"}.get(t)
            for a, b, c, d in zip(x, y, x2, y2):
                if any(np.isnan(v) for v in (a, b, c, d)):
                    continue
                if arrow:
                    ax.annotate("", xy=(c, d), xytext=(a, b), zorder=z + 1,
                                arrowprops=dict(arrowstyle=arrow, color=lc, lw=lw,
                                                shrinkA=0, shrinkB=0, mutation_scale=9))
                elif t != "pcscatter":
                    ax.plot([a, c], [b, d], color=lc, lw=lw, ls=dash, zorder=z + 1,
                            solid_capstyle="round")
            if t in ("pccapsym", "pcscatter"):
                kw = marker_kw()
                ax.plot(np.r_[x, x2], np.r_[y, y2], ls="None", zorder=z + 1.5, **kw)
            self.point_labels(ax, cols, labcols[0], labcols[1], p)
            info["handle"] = plt.Line2D([], [], color=lc, lw=lw)
            info["x"] = np.r_[x, x2]
            info["y"] = np.r_[y, y2]
        return info

    def point_labels(self, ax, cols, x, y, p):
        """Marker labels of a plot: mlabel() text, mlabvposition() positions."""
        labs = self.col(cols, p, "label")
        if labs is None:
            return
        lmap = p.get("labelmap") or {}
        fmt = str(p.get("labfmt", "") or "").strip() or str(p.get("labelvarfmt", "") or "")
        is_str = bool(re.fullmatch(r"%-?~?\d*s", str(p.get("labelvarfmt", "")).strip()))
        out = []
        for v in labs:
            if lmap and (v in lmap or v.split(".")[0] in lmap):
                out.append(lmap.get(v, lmap.get(v.split(".")[0], v)))
                continue
            f = None if is_str else num(v)
            out.append(stata_format(f, fmt) if f is not None else v)
        posc = self.col(cols, p, "pos")
        pos = to_float(posc) if posc is not None else None
        self.marker_labels(ax, x, y, out, p, pos)

    def marker_labels(self, ax, x, y, labs, p, pos_each=None):
        pos = str(p.get("labpos", "3")).strip()
        offsets = {"12": (0, 6, "center", "bottom"), "6": (0, -6, "center", "top"),
                   "3": (6, 0, "left", "center"), "9": (-6, 0, "right", "center"),
                   "0": (0, 0, "center", "center"),
                   "1": (5, 5, "left", "bottom"), "2": (5, 5, "left", "bottom"),
                   "4": (5, -5, "left", "top"), "5": (5, -5, "left", "top"),
                   "7": (-5, -5, "right", "top"), "8": (-5, -5, "right", "top"),
                   "10": (-5, 5, "right", "bottom"), "11": (-5, 5, "right", "bottom")}
        size = num(p.get("labsize"))
        fs = max(4.0, self.pts(size) * self.gmult) if size else 7.5 * self.f.k
        col = stata_color(p.get("labcolor"), to_rgba(MUTED))
        if col[:3] == (0, 0, 0):
            col = to_rgba(INK)
        angle = parse_angle({"angle": p.get("labangle", "")})
        kk = fs / 7.5  # offsets grow with the text
        for k, (xi, yi, lab) in enumerate(zip(x, y, labs)):
            if lab in ("nan", "", ".") or np.isnan(xi) or np.isnan(yi):
                continue
            pk = pos
            if pos_each is not None and k < len(pos_each) and not np.isnan(pos_each[k]):
                pk = str(int(pos_each[k]))
            dx, dy, ha, va = offsets.get(pk, offsets["3"])
            ax.annotate(clean_text(lab), (xi, yi), xytext=(dx * kk, dy * kk),
                        textcoords="offset points", ha=ha, va=va, fontsize=fs,
                        color=col, zorder=5, rotation=angle,
                        rotation_mode="anchor" if angle else "default")

    def bar_width(self):
        for i in self.infos:
            if i.get("bars"):
                return num(i["p"].get("barsize"), 0.8) or 0.8
        return 0.8

    def axis_format(self, key):
        """Display format of an axis: its label format, else the first plot's variable."""
        a = self.s.get(key) or {}
        fmt = str(a.get("format", "") or "").strip()
        if not fmt:
            for p in self.s.get("plots", []):
                fmt = str(p.get("yformat" if key != "xaxis" else "xformat", "") or "").strip()
                if fmt:
                    break
        return fmt

    def set_ticks(self, ax, which, ticks, fmt="", angle=0.0):
        pos = [t[0] for t in ticks]
        labs = nice_dates(pos, [t[1] for t in ticks], fmt)
        if which == "x":
            ax.set_xticks(pos)
            ax.set_xticklabels(labs)
        else:
            ax.set_yticks(pos)
            ax.set_yticklabels(labs)
        self.rotate_ticks(ax, which, angle)

    def minor_ticks(self, ax, which, raw):
        """xmlabel() / ymlabel(): labelled minor ticks, drawn in a smaller font."""
        ticks = [(num(t[0]), tick_text(t[1])) for t in (raw or [])]
        ticks = [t for t in ticks if t[0] is not None]
        if not ticks:
            return
        pos = [t[0] for t in ticks]
        labs = [t[1] for t in ticks]
        (ax.set_xticks if which == "x" else ax.set_yticks)(pos, labs, minor=True)
        ax.tick_params(axis=which, which="minor", labelsize=(self.xtickfs if which == "x" else self.ytickfs) * 0.8,
                       length=2.5, width=0.7, color=AXIS, labelcolor=MUTED)

    def rotate_ticks(self, ax, which, angle):
        """Tick-label angle set in Stata (xlabel(, angle())). The y axis keeps the
        house style (horizontal labels) unless the angle is a diagonal one."""
        angle = float(angle or 0.0) % 360
        if which == "y" and angle in (0.0, 90.0, 270.0):
            return
        if angle == 0.0:
            return
        labels = ax.get_xticklabels() if which == "x" else ax.get_yticklabels()
        for t in labels:
            t.set_rotation(angle)
            t.set_rotation_mode("anchor")
            if which == "x":
                if angle in (90.0, 270.0):
                    t.set_ha("right" if angle == 90.0 else "left")
                    t.set_va("center")
                else:
                    t.set_ha("right" if angle < 180 else "left")
                    t.set_va("top" if angle < 180 else "bottom")
            else:
                t.set_ha("right")
                t.set_va("center")
        if which == "x":
            self._rotated = True  # an explicit angle is not undone by fix_tick_overlap

    def apply_axes(self):
        s = self.s
        infos = self.infos
        bars = [i for i in infos if i.get("bars")]
        horizontal_bars = any(i.get("horizontal") for i in bars)
        horizontal_any = horizontal_bars or (
            any(i.get("horizontal") for i in infos)
            and not any(i["type"] in LINE_TYPES for i in infos))
        self.horizontal = horizontal_any
        for which, key, ax in (("x", "xaxis", self.ax), ("y", "yaxis", self.ax),
                               ("y", "y2axis", self.ax2)):
            if ax is None:
                continue
            a = s.get(key, {}) or {}
            lo, hi = num(a.get("min")), num(a.get("max"))
            ticks = [(num(t[0]), tick_text(t[1])) for t in a.get("ticks", [])]
            ticks = [t for t in ticks if t[0] is not None]
            is_log = a.get("transform", "") in ("log", "ln", "log10")
            if is_log:
                (ax.set_xscale if which == "x" else ax.set_yscale)("log")
                ax.minorticks_off()
            if lo is not None and hi is not None and hi > lo:
                pad = 0.025 * (hi - lo)
                lo2, hi2 = lo - pad, hi + pad
                if is_log and lo > 0:
                    f = (hi / lo) ** 0.025
                    lo2, hi2 = lo / f, hi * f
                if lo == 0 and which == "y" and a.get("reverse") != "yes":
                    lo2 = 0
                axbars = bars if which == "x" else [b for b in bars if b["ax"] is ax]
                if axbars:
                    value_axis = "x" if horizontal_bars else "y"
                    if which == value_axis:
                        base = min(b.get("base", 0.0) for b in axbars)
                        if base <= lo and not is_log:  # bars must show their base
                            lo2 = base
                            if len(ticks) >= 2:
                                step = ticks[1][0] - ticks[0][0]
                                t0 = ticks[0][0]
                                extra = []
                                while step > 0 and t0 - step >= base - 1e-9 and len(extra) < 20:
                                    t0 -= step
                                    extra.append((t0, f"{t0:g}"))
                                ticks = extra[::-1] + ticks
                    else:
                        w = self.bar_width()
                        lo2, hi2 = lo - 0.75 * w, hi + 0.75 * w
                (ax.set_xlim if which == "x" else ax.set_ylim)(lo2, hi2)
                # a wide plot-region margin (gpolish endlabel makes room this way when a
                # y axis is on the labelled side) is applied once the axes size is known
                mlo, mhi = num(a.get("mlo"), 0.0) or 0.0, num(a.get("mhi"), 0.0) or 0.0
                if max(mlo, mhi) > MARGIN_KEEP and self.s.get("role") != "matrix":
                    self._margins.append(dict(ax=ax, which=which, lo=lo, hi=hi, lo2=lo2,
                                              hi2=hi2, log=is_log and lo > 0,
                                              rev=a.get("reverse") == "yes",
                                              mlo=mlo, mhi=mhi))
            if ticks:
                self.set_ticks(ax, which, ticks, self.axis_format(key if key != "y2axis" else key),
                               parse_angle({"angle": a.get("tickangle", "")}))
            elif a.get("ticks_none"):
                # xlabel(none) / ylabel(none): no major ticks, labels or gridlines
                (ax.set_xticks if which == "x" else ax.set_yticks)([])
            self.minor_ticks(ax, which, a.get("ticks_minor"))
            if is_log:
                ax.tick_params(axis=which, which="minor", length=0, labelbottom=False,
                               labelleft=False)
            if a.get("reverse") == "yes":
                (ax.invert_xaxis if which == "x" else ax.invert_yaxis)()
            if a.get("draw") == "no":
                if which == "y":
                    ax.tick_params(axis="y", labelleft=False)
                else:
                    ax.tick_params(axis="x", labelbottom=False)
                if not self.f.multi and key != "y2axis":
                    self.axis_off.add(which)  # xscale(off) / yscale(off)
        ax = self.ax
        is_matrix = self.s.get("role") == "matrix"
        if "x" in self.axis_off:
            ax.spines["bottom"].set_visible(False)
        grid_on = not self.f.nogrid and not is_matrix
        gkey = "xaxis" if horizontal_any else "yaxis"
        if grid_on and (("x" if horizontal_any else "y") in self.axis_off
                        or (s.get(gkey) or {}).get("grid") == "no"):
            grid_on = False
        if (s.get("xaxis") or {}).get("noline"):
            ax.spines["bottom"].set_visible(False)
            self.axis_off.add("xline")
        if is_matrix:
            for side in ("top", "right", "left", "bottom"):
                ax.spines[side].set_visible(True)
                ax.spines[side].set_color(GRID)
                ax.spines[side].set_linewidth(0.9)
        if grid_on:
            if horizontal_any:
                ax.grid(axis="x", color=GRID, lw=0.9)
                ax.spines["bottom"].set_visible(False)
                if horizontal_bars:
                    ax.spines["left"].set_visible(True)
                    ax.spines["left"].set_color(AXIS)
            else:
                ax.grid(axis="y", color=GRID, lw=0.9)
        if (not horizontal_any and not self.f.noticks and "x" not in self.axis_off
                and "xline" not in self.axis_off and not is_matrix):
            ax.tick_params(axis="x", length=3.5, width=0.9, color=AXIS, direction="out")
        ylo, yhi = ax.get_ylim()
        if (min(ylo, yhi) < 0 < max(ylo, yhi) and not horizontal_any
                and "y" not in self.axis_off and not is_matrix):
            ax.axhline(0, color=AXIS, lw=0.9, zorder=1.8)
        # the side Stata drew each y axis on: yscale(alt) moves it, and with two y
        # axes the axis of the first plot goes on the left
        self.yside = "right" if (s.get("yaxis") or {}).get("position") == "right" else "left"
        self.y2side = None
        if self.ax2 is not None:
            self.y2side = "left" if (s.get("y2axis") or {}).get("position") == "left" else "right"
            if self.y2side == self.yside:
                # Stata stacks two axes on one side (with a third y axis, for example);
                # here the second goes on the other side so the labels do not overprint
                self.y2side = "right" if self.yside == "left" else "left"
        if self.yside == "right":
            ax.yaxis.tick_right()
            ax.yaxis.set_label_position("right")
            ax.tick_params(axis="y", labelleft=False,
                           labelright=(s.get("yaxis") or {}).get("draw") != "no")
        if self.ax2 is not None:
            r2 = self.y2side == "right"
            if not r2:
                self.ax2.yaxis.tick_left()
                self.ax2.yaxis.set_label_position("left")
            self.ax2.tick_params(axis="y", labelright=r2, labelleft=not r2,
                                 labelcolor=MUTED)
            self.ax2.grid(False)

    def apply_margins(self):
        """Keep a wide plot-region margin: the data range is drawn that many points
        inside the axes edge, as in Stata. Called by the layout once the axes size
        is known. The other side keeps the padding set by apply_axes()."""
        if not self._margins:
            return
        pos = self.ax.get_position()
        W, H = pos.width * self.f.xs * 72.0, pos.height * self.f.ys * 72.0
        for m in self._margins:
            A = W if m["which"] == "x" else H
            f = (lambda v: math.log(v)) if m["log"] else (lambda v: v)
            lo, hi, lo2, hi2 = f(m["lo"]), f(m["hi"]), f(m["lo2"]), f(m["hi2"])
            if not (hi > lo and hi2 > lo2 and A > 0):
                continue
            # padding now in points at the low and high data ends
            p_lo = (lo - lo2) / (hi2 - lo2) * A
            p_hi = (hi2 - hi) / (hi2 - lo2) * A
            # screen sides: a reversed axis puts the high data end on the low side
            s_lo, s_hi = (m["mhi"], m["mlo"]) if m["rev"] else (m["mlo"], m["mhi"])
            unit = self.f.unit * self.gmult
            if s_lo > MARGIN_KEEP:
                p_lo = max(p_lo, s_lo * unit)
            if s_hi > MARGIN_KEEP:
                p_hi = max(p_hi, s_hi * unit)
            if p_lo + p_hi >= 0.85 * A:  # leave the data at least 15% of the axis
                k = 0.85 * A / (p_lo + p_hi)
                p_lo, p_hi = p_lo * k, p_hi * k
            per = (hi - lo) / (A - p_lo - p_hi)
            a0, a1 = lo - p_lo * per, hi + p_hi * per
            if m["log"]:
                a0, a1 = math.exp(a0), math.exp(a1)
            if m["rev"]:
                a0, a1 = a1, a0
            (m["ax"].set_xlim if m["which"] == "x" else m["ax"].set_ylim)(a0, a1)

    def reflines(self):
        for r in self.s.get("reflines", []):
            z = num(r.get("z"))
            if z is None:
                continue
            ax = self.axis_for(r, "xline()" if r.get("ord") == "x" else "yline()")
            if ax is None:
                continue
            col = stata_color(r.get("color"), to_rgba(MUTED))
            if col[:3] == (0, 0, 0):
                col = to_rgba(MUTED)
            dash = DASHES.get(r.get("pattern", "solid"), "-")
            if dash == "-":
                dash = (0, (4, 3))
            w = num(r.get("lw"))
            kw = dict(color=col, lw=max(0.8, self.pts(w)) if w else 1.0, ls=dash, zorder=1.9)
            if r.get("ord") == "x":
                ax.axvline(z, **kw)
            else:
                ax.axhline(z, **kw)

    def text_width(self, t):
        """Width in points of the widest line of a text object."""
        lines = [rich_segments(l) for l in (t.get("text") or [])]
        lines = [l for l in lines if l]
        if not lines:
            return 0.0
        fs = self.text_fs(t)
        fig = self.f.fig
        r = fig.canvas.get_renderer()
        out = 0.0
        for line in lines:
            w = 0.0
            for txt, bold in line:
                tmp = fig.text(0, 0, txt, fontsize=fs, fontweight="bold" if bold else "normal")
                w += tmp.get_window_extent(r).width * 72.0 / fig.dpi
                tmp.remove()
            out = max(out, w)
        return out

    def pair_end_values(self, added, ax=None):
        """gpolish endlabel, values: a label (placed east of the line end) and a
        value (placed west of a point further right on screen) on the same line.
        Stata spaced them for its own text widths; here the value column is set
        from the widths measured with matplotlib, so the two never overprint.
        Pairs are matched on screen x, so a reversed x axis pairs the same way."""
        ax = ax if ax is not None else self.ax
        sgn = -1.0 if ax.xaxis_inverted() else 1.0
        def is_value(t):
            txt = " ".join(t.get("text") or []).strip()
            return bool(re.fullmatch(r"[-+\u2212]?[\d.,]+%?", txt.replace("$", "").replace("\\", "")))
        groups = {}
        for t in added:
            place = str(t.get("place", "")).strip().lower()
            if place not in ("east", "west") or t.get("draw") == "no":
                continue
            if num(t.get("x")) is None or num(t.get("y")) is None:
                continue
            groups.setdefault(round(num(t.get("y")), 9), []).append(t)
        pairs = []
        for items in groups.values():
            labs = [t for t in items if not is_value(t)]
            vals = [t for t in items if is_value(t)]
            for v in vals:
                vx = num(v.get("x"))
                vplace = str(v.get("place", "")).strip().lower()
                for lab in labs:
                    lplace = str(lab.get("place", "")).strip().lower()
                    lx = num(lab.get("x"))
                    if lplace == vplace:
                        continue
                    # right side: label east of x, value west of a point to its right
                    # on screen (and mirrored)
                    d = sgn * (vx - lx)
                    if (lplace == "east" and d > 0) or (lplace == "west" and d < 0):
                        pairs.append((lab, v))
                        break
        self._end_pairs = pairs
        if not pairs:
            return
        wl = max(self.text_width(lab) for lab, _ in pairs)
        wv = max(self.text_width(v) for _, v in pairs)
        for lab, v in pairs:
            fs = self.text_fs(lab)
            side = 1.0 if str(lab.get("place", "")).strip().lower() == "east" else -1.0
            # the value's outer edge sits one column (widest label + gap + widest value)
            # beyond the label's anchor
            v["_anchor"] = (num(lab.get("x")), num(v.get("y")))
            v["_dx"] = side * (0.12 * fs + wl + 0.9 * fs + wv)

    def draw_text(self, t, keep_color, ax=None):
        """Text box anchored to a data point. Each {bf:} run is its own artist,
        placed with point offsets (rotated about the anchor when an angle is set)."""
        if t.get("draw") == "no":
            return
        ax = ax if ax is not None else self.ax
        x, y = num(t.get("x")), num(t.get("y"))
        if t.get("_anchor"):
            x, y = t["_anchor"]
        lines = [rich_segments(l) for l in (t.get("text") or [])]
        lines = [l for l in lines if l]
        if x is None or y is None or not lines:
            return
        col = stata_color(t.get("color"), to_rgba(INK))
        if not keep_color and col[:3] == (0, 0, 0):
            col = to_rgba(INK)
        ha, va = ALIGN.get(str(t.get("place", "")).strip().lower(), ("center", "center"))
        fs = self.text_fs(t)
        ml = {"left": "left", "right": "right", "center": "center"}.get(
            str(t.get("horizontal", "")).strip().lower(), ha)
        theta = parse_angle(t)
        ct, st = math.cos(math.radians(theta)), math.sin(math.radians(theta))
        fig = self.f.fig
        r = fig.canvas.get_renderer()
        px2pt = 72.0 / fig.dpi

        def width(txt, bold):
            tmp = fig.text(0, 0, txt, fontsize=fs, fontweight="bold" if bold else "normal")
            w = tmp.get_window_extent(r).width * px2pt
            tmp.remove()
            return w

        widths = [[width(txt, b) for txt, b in line] for line in lines]
        lw_ = [sum(w) for w in widths]
        W = max(lw_)
        lh = fs * 1.28
        H = lh * len(lines)
        gap = 0.12 * fs
        # a drawn box: filled and/or outlined rectangle behind the text. A white fill
        # with no outline is the gpolish halo and is drawn as the thin stroke instead.
        box = None
        if str(t.get("drawbox", "")).strip() == "yes":
            fill = stata_color(t.get("boxfill"), (1, 1, 1, 0))
            blw = num(t.get("boxlw"), 0.0) or 0.0
            edge = stata_color(t.get("boxline"), (1, 1, 1, 0)) if blw > 0 else (1, 1, 1, 0)
            white = min(fill[:3]) > 0.97
            if not (white and edge[3] == 0) and (fill[3] > 0 or edge[3] > 0):
                pads = [self.pts((num(t.get("bm" + k), 0.0) or 0.0)
                                 + (num(t.get("m" + k), 0.0) or 0.0)) * self.gmult
                        for k in ("l", "r", "b", "t")]
                box = dict(fill=fill, edge=edge, lw=max(0.5, self.pts(blw)) if blw > 0 else 0,
                           pads=pads)
                theta, ct, st = 0.0, 1.0, 0.0
        padl, padr, padb, padt = box["pads"] if box else (0.0, 0.0, 0.0, 0.0)
        Wb, Hb = W + padl + padr, H + padb + padt
        # the block is rotated about its centre, then its bounding box is placed
        # against the anchor the way Stata's placement() does (in screen space)
        hw = (Wb * abs(ct) + Hb * abs(st)) / 2
        hh = (Wb * abs(st) + Hb * abs(ct)) / 2
        cx = {"left": hw + gap, "center": 0.0, "right": -hw - gap}[ha]
        cy = {"bottom": hh + gap, "center": 0.0, "top": -hh - gap}[va]
        if t.get("_dx"):
            # a paired end-label value: its outer edge sits _dx points from the anchor
            cx = t["_dx"] - (hw if t["_dx"] > 0 else -hw)
        if box:
            da = DrawingArea(Wb, Hb, 0, 0, clip=False)
            if self.f.roundbox:
                r_ = min(0.35 * fs, Hb / 2.2)
                patch = FancyBboxPatch((r_, r_), Wb - 2 * r_, Hb - 2 * r_,
                                       boxstyle=f"round,pad={r_}", facecolor=box["fill"],
                                       edgecolor=box["edge"], linewidth=box["lw"])
            else:
                patch = Rectangle((0, 0), Wb, Hb, facecolor=box["fill"],
                                  edgecolor=box["edge"], linewidth=box["lw"])
            da.add_artist(patch)
            ab = AnnotationBbox(da, (x, y), xybox=(cx, cy), xycoords="data",
                                boxcoords="offset points", box_alignment=(0.5, 0.5),
                                frameon=False, pad=0, annotation_clip=False, zorder=7.8)
            ax.add_artist(ab)
            cx += (padl - padr) / 2
            cy += (padb - padt) / 2
        for k, line in enumerate(lines):
            lx = -W / 2 + {"left": 0, "center": (W - lw_[k]) / 2, "right": W - lw_[k]}[ml]
            ly = H / 2 - (k + 0.5) * lh
            for (txt, bold), w in zip(line, widths[k]):
                a = ax.annotate(txt, xy=(x, y),
                                     xytext=(cx + lx * ct - ly * st, cy + lx * st + ly * ct),
                                     textcoords="offset points", ha="left", va="center",
                                     rotation=theta, rotation_mode="anchor",
                                     fontsize=fs, color=col,
                                     fontweight="bold" if bold else "normal",
                                     annotation_clip=False, zorder=8)
                if not box:
                    self.halo(a)
                t.setdefault("_artists", []).append(a)
                lx += w

    def added_shapes(self, ax=None):
        ax = ax if ax is not None else self.ax
        for l in self.s.get("added_lines", []):
            if l.get("draw") == "no":
                continue
            c = [num(l.get(k)) for k in ("x0", "y0", "x1", "y1")]
            if None in c:
                continue
            col = stata_color(l.get("color"), to_rgba(MUTED))
            w = num(l.get("lw"))
            lw = max(0.5, self.pts(w)) if w else 0.8
            dash = DASHES.get(l.get("pattern", "solid"), "-")
            head = str(l.get("head", "")).strip().lower()
            if head in ("", "neither", "none", "no"):
                ax.plot([c[0], c[2]], [c[1], c[3]], color=col, lw=lw, ls=dash, zorder=7,
                        solid_capstyle="round", clip_on=False)
            else:
                style = {"head": "-|>", "tail": "<|-", "both": "<|-|>"}.get(head, "-|>")
                hs = num(l.get("headsize"))
                ax.annotate("", xy=(c[2], c[3]), xytext=(c[0], c[1]), zorder=7,
                            annotation_clip=False,
                            arrowprops=dict(arrowstyle=style, color=col, lw=lw,
                                            shrinkA=0, shrinkB=0,
                                            mutation_scale=max(6.0, self.pts(hs) * 2.2)
                                            if hs else 8.0))
        for m in self.s.get("added_markers", []):
            if m.get("draw") == "no":
                continue
            x, y = num(m.get("x")), num(m.get("y"))
            if x is None or y is None:
                continue
            fill = stata_color(m.get("fill"), to_rgba(INK))
            line = stata_color(m.get("line"), fill)
            sz = num(m.get("size"))
            sym = str(m.get("symbol", "circle"))
            mlw = num(m.get("mlwidth"))
            ax.plot([x], [y], ls="None", marker=MARKERS.get(sym, "o"),
                    ms=self.pts(sz) if sz else 5.0,
                    mfc="white" if "hollow" in sym else fill, mec=line,
                    mew=self.pts(mlw) if mlw else 0.6, zorder=7.5, clip_on=False)

    # ---- legend / end labels -------------------------------------------------
    def series_labels(self, leg=None):
        """The first legend label of each plot: {plot index: label}."""
        out = {}
        for k, lab, _col, _bold in self.legend_entries(leg):
            if k > 0 and k not in out:
                out[k] = lab
        return out

    def legend_entries(self, leg=None):
        """Legend entries in the order of Stata's legend map, as (plot index, label,
        label colour, bold). A text-only entry ("-" in order()) has index 0; a plot
        listed twice keeps both entries."""
        leg = leg if leg is not None else self.s.get("legend", {})
        out = []
        if leg.get("draw") != "no":
            for e in leg.get("entries", []):
                k = num(e[0])
                if k is None or not e[1]:
                    continue
                col = stata_color(e[2], None) if len(e) > 2 else None
                bold = bool(re.fullmatch(r"\s*\{bf:[^}]*\}\s*", e[1]))
                out.append((int(k), clean_text(e[1]), col, bold))
        return out

    def legend_items(self, entries):
        """One key per legend entry, in legend order. Repeated plots and repeated
        label text are kept; a text-only entry gets an empty key."""
        by_idx = {i["p"]["index"]: i for i in self.infos}
        handles, texts, self._legend_styles = [], [], []
        self._legend_plots = []
        nplot = 0
        for k, lab, col, bold in entries:
            if not lab:
                continue
            if k == 0:
                h = Rectangle((0, 0), 1, 1, fill=False, edgecolor="none", visible=False)
            else:
                info = by_idx.get(k)
                if info is None or info["handle"] is None:
                    continue
                h = info["handle"]
                nplot += 1
            handles.append(h)
            texts.append(lab)
            self._legend_styles.append((col, bold))
            self._legend_plots.append(k)
        forced = self.s.get("legend", {}).get("draw") == "yes"
        if nplot == 0 or (len(handles) == 1 and len(self.infos) == 1 and not forced):
            return [], []
        return handles, texts

    def restyle_legend(self, leg):
        styles = getattr(self, "_legend_styles", [])
        perm = getattr(leg, "_g2m_perm", None)
        for k, txt in enumerate(leg.get_texts()):
            if perm is not None and k < len(perm):
                k = perm[k]
            col, bold = styles[k] if k < len(styles) else (None, False)
            if col is not None and col[:3] != (0, 0, 0) and col[3] > 0:
                txt.set_color(col)
            if bold:
                txt.set_fontweight("bold")

    def ramp_legend(self, labels):
        """Many filled polygons with a legend (heatplot): a stepped colour bar."""
        by_idx = {i["p"]["index"]: i for i in self.infos}
        steps = [(k, labels[k], by_idx[k]["color"]) for k in sorted(labels) if k in by_idx]
        vals = [num(st_[1].replace(",", "")) for st_ in steps]
        if all(v is not None for v in vals):  # low to high, whatever the plot order
            steps = [st_ for _, st_ in sorted(zip(vals, steps), key=lambda q: q[0])]
        n = len(steps)
        leg = self.s.get("legend", {})
        side = str(leg.get("position", "")).strip() in ("2", "3", "4")
        if side and num(leg.get("rows")) != 1:
            # key at the right in Stata: a vertical ramp, low values at the bottom
            cax = self.ax.inset_axes([1.03, 0.22, 0.035, 0.62])
            for k, (_, _, col) in enumerate(steps):
                cax.add_patch(Rectangle((0, k), 1, 1, facecolor=col, edgecolor="none"))
            cax.set_xlim(0, 1)
            cax.set_ylim(0, n)
            show = sorted({0, n // 4, n // 2, (3 * n) // 4, n - 1})
            cax.set_yticks([k + 0.5 for k in show])
            cax.set_yticklabels([steps[k][1] for k in show])
            cax.set_xticks([])
            cax.tick_params(axis="y", length=0, labelsize=7.5 * self.f.k, pad=3 * self.f.k, left=False, right=True,
                            labelleft=False, labelright=True, labelcolor=MUTED)
            for sp in cax.spines.values():
                sp.set_visible(False)
            title = clean_text(leg.get("title", ""))
            if title:
                cax.set_title(title, fontsize=8.5 * self.f.k, color=MUTED, loc="left",
                              pad=4 * self.f.k)
            return True
        cax = self.ax.inset_axes([0.0, 1.035, 0.46, 0.035])
        for k, (_, _, col) in enumerate(steps):
            cax.add_patch(Rectangle((k, 0), 1, 1, facecolor=col, edgecolor="none"))
        cax.set_xlim(0, n)
        cax.set_ylim(0, 1)
        show = sorted({0, n // 4, n // 2, (3 * n) // 4, n - 1})
        cax.set_xticks([k + 0.5 for k in show])
        cax.set_xticklabels([steps[k][1] for k in show])
        cax.set_yticks([])
        cax.tick_params(axis="x", length=0, labelsize=7.5 * self.f.k, pad=2 * self.f.k, top=True, bottom=False,
                        labeltop=True, labelbottom=False, labelcolor=MUTED)
        for sp in cax.spines.values():
            sp.set_visible(False)
        title = clean_text(self.s.get("legend", {}).get("title", ""))
        if title:
            cax.text(1.03, 0.5, title, transform=cax.transAxes, fontsize=8.5 * self.f.k, color=MUTED,
                     ha="left", va="center")
        self.has_legend = True
        return True

    def legend(self):
        labels = self.series_labels()
        polys = [i for i in self.infos if i.get("poly") and i["p"]["index"] in labels]
        if len(polys) >= 5 and len(polys) == len(labels):
            return self.ramp_legend(labels)
        handles, texts = self.legend_items(self.legend_entries())
        if not handles:
            return False
        leg = self.s.get("legend", {})
        one_row = num(leg.get("rows")) == 1 or len(handles) <= 6
        title = clean_text(leg.get("title", ""))
        self._leg_args = dict(handles=handles, texts=texts, title=title,
                              fs=self.f.tsize(leg.get("size"), 9.0, self.gmult),
                              colfirst=leg.get("colfirst") == "yes")
        self.make_legend(len(handles) if one_row else 4)
        self.has_legend = True
        return True

    def make_legend(self, ncol):
        a = self._leg_args
        if self.leg is not None:
            self.leg.remove()
        k = self.f.k
        n = len(a["handles"])
        perm = legend_perm(n, max(1, ncol), a.get("colfirst", False))
        leg = self.ax.legend([a["handles"][i] for i in perm], [a["texts"][i] for i in perm],
                             loc="lower left", bbox_to_anchor=(0, 1.0),
                             ncol=max(1, ncol), frameon=False, fontsize=a["fs"],
                             handlelength=1.6, handletextpad=0.5, columnspacing=1.4,
                             borderaxespad=0.2, labelcolor=INK, title=a["title"] or None,
                             title_fontsize=a["fs"], alignment="left")
        leg._g2m_perm = perm
        if a["title"]:
            leg.get_title().set_color(MUTED)
        # the legend widens the figure only through its rows: it is left out of the
        # panel-width solve, and fit_legend() wraps it to fit the figure width
        leg.set_in_layout(False)
        self.restyle_legend(leg)
        self.leg = leg
        self._leg_ncol = max(1, ncol)
        return leg

    def fit_legend(self):
        """Drop legend columns until the legend fits inside the figure. Returns True
        if it changed the legend."""
        if self.leg is None or self._leg_args is None:
            return False
        fig = self.f.fig
        r = fig.canvas.get_renderer()
        right = fig.bbox.width * (1 - self.f.padx / (self.f.xs * 72.0))
        changed = False
        while self._leg_ncol > 1 and self.leg.get_window_extent(r).x1 > right + 0.5:
            self.make_legend(self._leg_ncol - 1)
            changed = True
        return changed

    def end_labels(self):
        ax, fig = self.ax, self.f.fig
        labels = self.series_labels()
        cands = []
        for info in self.infos:
            if info["type"] not in LINE_TYPES or info["ax"] is not ax:
                continue
            idx = info["p"]["index"]
            lab = labels.get(idx) or clean_text(info["p"].get("ylabel")) or f"series {idx}"
            x, y = info["x"], info["y"]
            ok = ~(np.isnan(x) | np.isnan(y))
            if not ok.any():
                continue
            cands.append((x, y, ok, lab, info["color"]))
        if not cands:
            return False
        fig.canvas.draw()
        # the line end is the point furthest right on screen (a reversed x axis
        # puts the largest x value on the left)
        ends = []
        self._end_series = []
        for x, y, ok, lab, col in cands:
            sx = ax.transData.transform(np.column_stack([x[ok], y[ok]]))[:, 0]
            j = np.where(ok)[0][np.argmax(sx)]
            ends.append((x[j], y[j], lab, col))
            self._end_series.append((lab, np.column_stack([x[ok], y[ok]])))
        cands = ends
        ypix = np.array([ax.transData.transform((c[0], c[1]))[1] for c in cands])
        fs = self.tickfs
        sep = fs * 1.28 * fig.dpi / 72.0
        ext = ax.get_window_extent()
        newpix = repel_1d(ypix, sep, ext.y0, ext.y1)
        inv = ax.transData.inverted()
        for (cx, cy, lab, col), py_new in zip(cands, newpix):
            px = ax.transData.transform((cx, cy))[0]
            ynew = inv.transform((px, py_new))[1]
            ax.annotate(lab, xy=(cx, ynew), xytext=(8 * self.f.k, 0), textcoords="offset points",
                        ha="left", va="center", fontsize=fs, fontweight="bold",
                        color=darken_for_text(col), annotation_clip=False, zorder=7)
            ax.plot([cx], [cy], marker="o", ms=4.5, mfc=col, mec="white", mew=0.8,
                    ls="None", zorder=6, clip_on=False)
        return True

    # ---- bar family: redraw Stata's own objects ---------------------------------
    def draw_bar(self):
        s = self.s
        ax = self.ax
        horizontal = s.get("horizontal") == "yes"
        is_dot = s.get("dotplot") == "yes"
        is_box = s.get("boxplot") == "yes"
        self.horizontal = horizontal
        seen = {}

        def colour(raw):
            key = " ".join(str(raw or "").split())
            if key not in seen:
                seen[key] = len(seen)
            if self.f.palette == "house":
                return to_rgba(HOUSE[seen[key] % len(HOUSE)])
            return stata_color(raw, to_rgba(HOUSE[seen[key] % len(HOUSE)]))

        for b in s.get("bars", []):
            if b.get("draw") == "no":
                continue
            x0, y0, x1, y1 = (num(b.get(k)) for k in ("x0", "y0", "x1", "y1"))
            if None in (x0, y0, x1, y1):
                continue
            if is_dot:  # in graph dot the "bars" are the dotted guide lines
                ax.plot([x0, x1], [y0, y1], color=AXIS, lw=0.8, ls=(0, (1, 3)), zorder=1.5)
                continue
            ax.add_patch(plt.Rectangle((min(x0, x1), min(y0, y1)), abs(x1 - x0),
                                       abs(y1 - y0), facecolor=colour(b.get("color")),
                                       edgecolor="white", linewidth=0.6, zorder=2))
        for b in s.get("boxes", []):
            if b.get("draw") == "no":
                continue
            v = {k: num(b.get(k)) for k in ("z", "p25", "p50", "p75", "adjl", "adjh", "width2")}
            # a group with few observations has no whiskers (adjl/adjh missing);
            # its box and median are still drawn
            if any(v[k] is None for k in ("z", "p25", "p50", "p75", "width2")):
                continue
            c = colour(b.get("color"))
            face = (c[0], c[1], c[2], 0.35)
            hz = (num(b.get("horizontal"), 0) or 0) != 0 or horizontal
            z, w = v["z"], v["width2"]

            def seg(a0, b0, a1, b1, **kw):
                if hz:
                    ax.plot([b0, b1], [a0, a1], **kw)
                else:
                    ax.plot([a0, a1], [b0, b1], **kw)

            if hz:
                ax.add_patch(plt.Rectangle((v["p25"], z - w), v["p75"] - v["p25"], 2 * w,
                                           facecolor=face, edgecolor=c[:3], linewidth=1.2,
                                           zorder=2))
            else:
                ax.add_patch(plt.Rectangle((z - w, v["p25"]), 2 * w, v["p75"] - v["p25"],
                                           facecolor=face, edgecolor=c[:3], linewidth=1.2,
                                           zorder=2))
            seg(z - w, v["p50"], z + w, v["p50"], color=c[:3], lw=2.2, zorder=3,
                solid_capstyle="butt")
            if v["adjl"] is not None:
                seg(z, v["adjl"], z, v["p25"], color=c[:3], lw=1.2, zorder=2)
            if v["adjh"] is not None:
                seg(z, v["p75"], z, v["adjh"], color=c[:3], lw=1.2, zorder=2)
        for arr, size in (("outsides", 3.6), ("points", 6.0)):
            for m in s.get(arr, []):
                if m.get("draw") == "no":
                    continue
                x, y = num(m.get("x")), num(m.get("y"))
                if x is None or y is None:
                    continue
                c = colour(m.get("color"))
                sz = num(m.get("size"))
                if arr == "points":
                    self._dotms = getattr(self, "_dotms", []) + [self.bar_ms(sz, size, True)]
                ax.plot([x], [y], ls="None", marker=MARKERS.get(str(m.get("symbol")), "o"),
                        ms=self.bar_ms(sz, size, arr == "points"),
                        mfc=c if arr == "points" else "white", mec=c if arr == "outsides" else "white",
                        mew=1.0 if arr == "outsides" else 0.6, zorder=3)
        self.bar_seen = seen
        sticks = [(num(t[0]), tick_text(t[1])) for t in s.get("scaleaxis", [])]
        gticks = [(num(t[0]), tick_text(t[1])) for t in s.get("grpaxis", [])]
        ax.autoscale_view()
        lo, hi = num(s.get("smin")), num(s.get("smax"))
        if horizontal:
            ax.set_ylim(0, 100)
            if is_box or is_dot:
                xlo, xhi = num(s.get("xmin")), num(s.get("xmax"))
                if xlo is not None and xhi is not None and xhi > xlo:
                    pad = 0.02 * (xhi - xlo)
                    ax.set_xlim(xlo - (pad if xlo != 0 else 0), xhi + pad)
            ax.set_yticks([t[0] for t in gticks])
            ax.set_yticklabels([t[1] for t in gticks])
            if sticks:
                ax.set_xticks([t[0] for t in sticks])
                ax.set_xticklabels([t[1] for t in sticks])
            elif s.get("scaleaxis_none"):
                ax.set_xticks([])
            self.minor_ticks(ax, "x", s.get("scaleaxis_minor"))
            if not self.f.nogrid:
                ax.grid(axis="x", color=GRID, lw=0.9)
            ax.spines["bottom"].set_visible(False)
            if not (is_box or is_dot):
                ax.spines["left"].set_visible(True)
                ax.spines["left"].set_color(AXIS)
        else:
            ax.set_xlim(0, 100)
            if (is_box or is_dot) and lo is not None and hi is not None and hi > lo:
                pad = 0.02 * (hi - lo)
                ax.set_ylim(lo - (pad if lo != 0 else 0), hi + pad)
            ax.set_xticks([t[0] for t in gticks])
            ax.set_xticklabels([t[1] for t in gticks])
            self.rotate_ticks(ax, "x", parse_angle({"angle": s.get("gtickangle", "")}))
            if sticks:
                ax.set_yticks([t[0] for t in sticks])
                ax.set_yticklabels([t[1] for t in sticks])
            elif s.get("scaleaxis_none"):
                ax.set_yticks([])
            self.minor_ticks(ax, "y", s.get("scaleaxis_minor"))
            if not self.f.nogrid:
                ax.grid(axis="y", color=GRID, lw=0.9)

    def bar_extras(self):
        """blabel() texts and the second-level over() labels."""
        s, ax = self.s, self.ax
        for b in s.get("barlabels", []):
            if b.get("draw") == "no":
                continue
            x, y = num(b.get("x")), num(b.get("y"))
            txt = join_lines(b.get("text"))
            if x is None or y is None or not txt:
                continue
            ha, va = ALIGN.get(str(b.get("place", "")).strip().lower(), ("center", "center"))
            k = self.f.k
            off = ({"left": 3, "right": -3, "center": 0}[ha] * k,
                   {"bottom": 3, "top": -3, "center": 0}[va] * k)
            size = num(b.get("size"))
            fs = max(4.0, self.pts(size) * self.gmult) if size else max(4.0, self.tickfs - 1.5)
            ax.annotate(txt, (x, y), xytext=off, textcoords="offset points", ha=ha, va=va,
                        fontsize=fs, color=INK, zorder=4, annotation_clip=False)
        sup = [(num(t[0]), clean_text(t[1])) for t in s.get("supaxis", [])]
        sup = [t for t in sup if t[0] is not None and t[1]]
        if not sup:
            return
        fig = self.f.fig
        fig.canvas.draw()
        r = fig.canvas.get_renderer()
        px2pt = 72.0 / fig.dpi
        fs = self.tickfs
        if self.horizontal:
            wmax = max([t.get_window_extent(r).width for t in ax.get_yticklabels()] or [0])
            for pos, lab in sup:
                ax.annotate(lab, xy=(0, pos), xycoords=("axes fraction", "data"),
                            xytext=(-(wmax * px2pt + 16), 0), textcoords="offset points",
                            ha="right", va="center", fontsize=fs, fontweight="bold",
                            color="#374151", annotation_clip=False)
        else:
            self._sup = []
            for pos, lab in sup:
                self._sup.append(ax.annotate(
                    lab, xy=(pos, 0), xycoords=("data", "axes fraction"), xytext=(0, -14),
                    textcoords="offset points", ha="center", va="top", fontsize=fs,
                    fontweight="bold", color="#374151", annotation_clip=False))
            self.place_sup()

    def place_sup(self):
        """Put the second over() row below the lowest edge of the inner category
        labels, rotated or not, so the two rows never overprint."""
        sup = getattr(self, "_sup", None)
        if not sup:
            return
        ax, fig = self.ax, self.f.fig
        fig.canvas.draw()
        r = fig.canvas.get_renderer()
        px2pt = 72.0 / fig.dpi
        y_axis = ax.get_window_extent(r).y0
        lows = [t.get_window_extent(r).y0 for t in ax.get_xticklabels()
                if t.get_text() and t.get_visible()]
        depth = max(0.0, y_axis - min(lows)) if lows else 0.0
        off = -(depth * px2pt + 6 * self.f.k)
        for a in sup:
            a.xyann = (0, off)

    def bar_ms(self, sz, size, dot=False):
        """Marker diameter for graph dot points and box-plot outside values. Dot
        markers use Stata's marker scale (as twoway markers do)."""
        if not sz:
            return size
        if dot:
            return max(2.0, self.pts(sz) * MSTATA * self.f.msscale * self.gmult)
        return max(size * 0.6, self.pts(sz) * self.f.msscale * self.gmult)

    def bar_legend(self):
        leg = self.s.get("legend", {})
        entries = [e for e in leg.get("entries", []) if e[1]]
        if leg.get("draw") == "no" or len(entries) < 2:
            return False
        handles = []
        is_marker = self.s.get("dotplot") == "yes"
        for k, e in enumerate(entries):
            key = " ".join(str(e[0]).split())
            c = stata_color(e[0], to_rgba(HOUSE[k % len(HOUSE)]))
            if self.f.palette == "house":
                c = to_rgba(HOUSE[self.bar_seen.get(key, k) % len(HOUSE)])
            if is_marker:
                # the key copies the plotted marker of series k (marker(#, ...))
                mc = e[2] if len(e) > 2 else ""
                mk = " ".join(str(mc).split())
                if self.f.palette == "house":
                    c = to_rgba(HOUSE[self.bar_seen.get(mk, k) % len(HOUSE)]) if mk else c
                elif mc:
                    c = stata_color(mc, c)
                sym = MARKERS.get(str(e[3]), "o") if len(e) > 3 else "o"
                sz = num(e[4]) if len(e) > 4 else None
                kms = self.bar_ms(sz, 6.0, True)
                handles.append(plt.Line2D([], [], ls="None", marker=sym, ms=kms, mfc=c,
                                          mec="white", mew=0.6))
                self._dotkeys = getattr(self, "_dotkeys", []) + [
                    "%02x%02x%02x:%.2f" % (*(round(255 * v) for v in c[:3]), kms)]
            else:
                handles.append(plt.Rectangle((0, 0), 1, 1, facecolor=c, edgecolor="none"))
        texts = [clean_text(e[1]) for e in entries]
        self._legend_styles = []
        self._leg_args = dict(handles=handles, texts=texts, title="",
                              fs=self.f.tsize(leg.get("size"), 9.0, self.gmult),
                              colfirst=leg.get("colfirst") == "yes")
        self.make_legend(min(len(handles), 4))
        self.has_legend = True
        return True

    # ---- shared -------------------------------------------------------------
    def fix_tick_overlap(self):
        """Rotate x tick labels when they collide. Returns True if it changed them."""
        ax, fig = self.ax, self.f.fig
        r = fig.canvas.get_renderer()
        boxes = [t.get_window_extent(r) for t in ax.get_xticklabels()
                 if t.get_text() and t.get_visible()]
        boxes = sorted(boxes, key=lambda b: b.x0)
        clash = any(boxes[k].x1 + 4 > boxes[k + 1].x0 for k in range(len(boxes) - 1))
        if clash and not getattr(self, "_rotated", False):
            self._rotated = True
            for t in ax.get_xticklabels():
                t.set_rotation(38)
                t.set_ha("right")
                t.set_rotation_mode("anchor")
            self.place_sup()
            return True
        return False

    def tightbbox(self, r):
        boxes = [self.ax.get_tightbbox(r)]
        if self.ax2 is not None:
            boxes.append(self.ax2.get_tightbbox(r))
        boxes = [b for b in boxes if b is not None]
        bb = Bbox.union(boxes)
        if self.leg is not None and self.leg.get_visible():
            # the legend adds height only; its width is handled by fit_legend()
            lb = self.leg.get_window_extent(r)
            bb = Bbox.from_extents(bb.x0, min(bb.y0, lb.y0), bb.x1, max(bb.y1, lb.y1))
        return bb.transformed(self.f.fig.transFigure.inverted())

    def panel_note(self, text, fs):
        """A combine member's note() and caption(), left-aligned under its own
        x axis (tick labels and axis title), as Stata draws them in the cell."""
        ax, ax2 = self.ax, self.ax2

        def under(r):
            boxes = [a.get_tightbbox(r, bbox_extra_artists=[]) for a in (ax, ax2)
                     if a is not None]
            bb = Bbox.union([b for b in boxes if b is not None])
            x0 = ax.get_window_extent(r).x0
            return Bbox.from_extents(x0, bb.y0, x0 + 1, bb.y0 + 1)

        self.note_artist = ax.annotate(text, xy=(0, 0), xycoords=under,
                                       xytext=(0, -3 * self.f.k), textcoords="offset points",
                                       ha="left", va="top", fontsize=fs, color=MUTED,
                                       linespacing=1.3, annotation_clip=False)

    def set_position(self, rect):
        self.ax.set_position(rect)
        if self.ax2 is not None:
            self.ax2.set_position(rect)

    def axis_title_size(self, which):
        if self.s.get("family") == "bar":
            gm = self.s.get("stitle_size")
        else:
            gm = (self.s.get({"x": "xaxis", "y": "yaxis", "y2": "y2axis"}[which]) or {}).get("tsize")
        return self.f.tsize(gm, 9.5, self.gmult)

    def axis_title(self, which):
        key = {"x": "xaxis", "y": "yaxis", "y2": "y2axis"}[which]
        if self.s.get("family") == "bar":
            return join_lines(self.s.get("scaletitle")) if which == "y" else ""
        a = self.s.get(key) or {}
        if a.get("draw") == "no" and not self.f.multi:
            return ""
        return join_lines(a.get("title"))


# --------------------------------------------------------------------------
# the figure: titles, panels, layout
# --------------------------------------------------------------------------
class Figure:
    def __init__(self, spec):
        self.s = spec
        self.dir = spec.get("specdir") or "."
        self.skipped = []
        self._csv = {}
        self.notes = []
        self.font = pick_font(spec.get("font") or "")
        want = spec.get("font") or ""
        if want and self.font != want:
            self.notes.append(f"font {want} is not installed; gr2mpl used {self.font}")
        self.xs = num(spec.get("xsize"), 5.5) or 5.5
        self.ys = num(spec.get("ysize"), 4.0) or 4.0
        # Stata's relative size unit is 1/100 of the shorter side of the graph
        self.unit = min(self.xs, self.ys) * 72.0 / 100.0  # relative size unit -> points
        # fixed sizes (paddings, gaps, fallbacks) were set for a 5.5 x 4 inch graph
        self.k = min(max(min(self.xs, self.ys) / 4.0, 0.35), 3.0)
        self.padx, self.pady = 14.0 * self.k, 12.0 * self.k
        w = num(spec.get("width"), 0) or 0
        self.dpi = (w / self.xs) if w > 0 else (num(spec.get("dpi"), 200) or 200)
        self.palette = (spec.get("palette") or "").strip().lower()
        self.lwscale = num(spec.get("lwscale"), 1.0) or 1.0
        self.msscale = num(spec.get("msscale"), 1.0) or 1.0
        self.nohalo = bool(spec.get("nohalo"))
        self.roundbox = bool(spec.get("roundbox"))
        self.nogrid = bool(spec.get("nogrid"))
        self.noticks = bool(spec.get("noticks"))
        self.pspecs = spec.get("panels", [])
        self.multi = len(self.pspecs) > 1 or spec.get("family") in ("by", "combine", "matrix")
        self.tickfs0 = 8.5 if len(self.pspecs) > 2 else 9.5
        self.tickfs = self.tsize(None, self.tickfs0)

    def tsize(self, gm, default, mult=1.0):
        """A Stata text size (relative units, as stored in .gmval) in points; when
        the graph does not record it, the default (points on a 5.5 x 4 graph) scaled
        to this graph."""
        v = num(gm)
        if v is not None and v > 0:
            return max(3.0, v * self.unit * mult)
        return max(3.0, default * self.k * mult)

    def data(self, path):
        if path not in self._csv:
            self._csv[path] = read_csv_columns(path)
        return self._csv[path]

    def grid_shape(self):
        n = len(self.pspecs)
        rows = int(num(self.s.get("rows"), 0) or 0)
        cols = int(num(self.s.get("cols"), 0) or 0)
        if cols < 1 and rows >= 1:
            cols = math.ceil(n / rows)
        if cols < 1:
            cols = math.ceil(math.sqrt(n))
        rows = max(rows, math.ceil(n / cols))
        return rows, cols

    def render(self):
        s = self.s
        names = {f.name for f in font_manager.fontManager.ttflist}
        family = [self.font] + [f for f in GLYPH_FALLBACKS if f in names and f != self.font]
        plt.rcParams.update({
            "font.family": family, "font.size": 10 * self.k, "text.color": INK,
            "axes.labelcolor": MUTED, "axes.edgecolor": AXIS, "xtick.color": INK,
            "ytick.color": INK, "axes.unicode_minus": True,
        })
        self.fig = plt.figure(figsize=(self.xs, self.ys), dpi=self.dpi)
        self.fig.patch.set_facecolor("white")
        rows, cols = self.grid_shape()
        self.rows, self.cols = rows, cols
        self.panels = []
        for k, ps in enumerate(self.pspecs):
            ax = self.fig.add_subplot(rows, cols, k + 1)
            p = Panel(self, ps, ax, k)
            fam = ps.get("family")
            if fam == "twoway":
                p.draw_twoway()
            elif fam == "bar":
                p.draw_bar()
                p.bar_extras()
            elif fam == "diag":  # graph matrix: variable name on the diagonal
                ax.set_xticks([])
                ax.set_yticks([])
                for sp in ax.spines.values():
                    sp.set_visible(True)
                    sp.set_color(GRID)
                ax.text(0.5, 0.5, join_lines(ps.get("ptitle")), transform=ax.transAxes,
                        ha="center", va="center", fontsize=self.tickfs * 1.15,
                        fontweight="bold", color="#374151", wrap=True)
            elif fam == "blank":
                ax.set_axis_off()
            else:
                cls = str(ps.get("classname", ""))
                what = {"bygraph_g": "a by() graph inside graph combine",
                        "combinegraph_g": "a graph combine inside graph combine"}.get(
                            cls, f"a sub-graph of family {fam}")
                p.skip(f"{what} (not drawn)")
                ax.set_axis_off()
            self.panels.append(p)
        self.share_bar_scale()
        asp = num(s.get("aspect"), 0.0) or 0.0
        if asp > 0 and not self.multi and self.panels:
            # aspectratio(): Stata's ratio is plot-region height over width
            for a in (self.panels[0].ax, self.panels[0].ax2):
                if a is not None:
                    a.set_box_aspect(asp)

        # titles shared by all panels, taken from the panels when they agree
        xt = {p.axis_title("x") for p in self.panels}
        yt = {p.axis_title("y") for p in self.panels}
        self.xtitle = xt.pop() if len(xt) == 1 else ""
        self.ytitle = yt.pop() if len(yt) == 1 else ""
        if not self.xtitle and self.multi:
            self.xtitle = join_lines(s.get("b1title"))
        two_axes = any(p.ax2 is not None for p in self.panels)
        for p in self.panels:
            if not self.xtitle and p.axis_title("x"):
                p.ax.set_xlabel(p.axis_title("x"), fontsize=p.axis_title_size("x"), color=MUTED,
                                labelpad=6 * self.k)
            if (not self.ytitle or two_axes) and p.axis_title("y"):
                p.ax.set_ylabel(p.axis_title("y"), fontsize=p.axis_title_size("y"), color=MUTED,
                                labelpad=6 * self.k)
            if p.ax2 is not None and p.axis_title("y2"):
                right = getattr(p, "y2side", "right") != "left"
                p.ax2.set_ylabel(p.axis_title("y2"), fontsize=p.axis_title_size("y2"), color=MUTED,
                                 rotation=270 if right else 90,
                                 labelpad=(14 if right else 6) * self.k)
        if two_axes:
            self.ytitle = ""

        # legends and panel titles
        self.fig_legend = None
        single = not self.multi
        used_end = False
        if single:
            p = self.panels[0]
            if p.s.get("family") == "bar":
                if not s.get("nolegend"):
                    p.bar_legend()
            else:
                if s.get("endlabels") and any(i["type"] in LINE_TYPES for i in p.infos):
                    self.layout()
                    used_end = p.end_labels()
                if not used_end and not s.get("nolegend"):
                    p.legend()
        else:
            is_by = s.get("family") == "by"
            for p in ([] if s.get("family") == "matrix" else self.panels):
                if not is_by and not s.get("nolegend"):
                    if p.s.get("family") == "bar":
                        p.bar_legend()
                    else:
                        p.legend()
                title = join_lines(p.s.get("ptitle"))
                sub = join_lines(p.s.get("psubtitle")) if not is_by else ""
                pad = (24 if p.has_legend else 7) * self.k
                if sub:
                    fs_s = self.tsize(p.s.get("psubtitle_size"), self.tickfs0, p.gmult)
                    p.sub_artist = p.ax.annotate(sub, xy=(0, 1), xycoords="axes fraction",
                                  xytext=(0, pad), textcoords="offset points",
                                  ha="left", va="bottom", fontsize=fs_s, color=MUTED,
                                  linespacing=1.2, annotation_clip=False)
                    pad += fs_s * 1.3 * (sub.count("\n") + 1) + 2 * self.k
                if title:
                    p.ax.set_title(title, loc="left",
                                   fontsize=self.tsize(p.s.get("ptitle_size"), self.tickfs0 + 1,
                                                       p.gmult),
                                   fontweight="bold", color="#374151", pad=pad)
                pnote = "\n".join(x for x in [join_lines(p.s.get("pnote")),
                                              join_lines(p.s.get("pcaption"))] if x)
                if pnote and not is_by:
                    p.panel_note(pnote, self.tsize(p.s.get("pnote_size"), 8.0, p.gmult))
            if is_by and not s.get("nolegend") and self.panels:
                p0 = self.panels[0]
                handles, texts = p0.legend_items(p0.legend_entries(s.get("legend", {})))
                if len(handles) > 1:
                    self.fig_legend = (handles, texts, p0)
        self.layout()
        for _ in range(3):
            changed = False
            for p in self.panels:
                changed = p.fit_legend() or changed
                if not p.horizontal:
                    changed = p.fix_tick_overlap() or changed
            if not changed:
                break
            self.layout()
        self.save()

    def share_bar_scale(self):
        """by() panels of graph bar/hbar/box/dot share one scale axis in Stata
        (unless the y axis is rescaled per panel), so every panel gets the range
        Stata used, not its own autoscaled one."""
        s = self.s
        if s.get("family") != "by" or s.get("indiv_yrescale") == "yes":
            return
        bars = [p for p in self.panels if p.s.get("family") == "bar"]
        if len(bars) < 2:
            return
        horizontal = bars[0].horizontal
        lk, hk = ("xmin", "xmax") if horizontal else ("smin", "smax")
        los = [num(p.s.get(lk)) for p in bars]
        his = [num(p.s.get(hk)) for p in bars]
        if any(v is None for v in los + his):
            # fall back on the union of the ranges matplotlib chose
            get = (lambda p: p.ax.get_xlim()) if horizontal else (lambda p: p.ax.get_ylim())
            lims = [get(p) for p in bars]
            lo, hi = min(l[0] for l in lims), max(l[1] for l in lims)
        else:
            lo, hi = min(los), max(his)
            if hi <= lo:
                return
            pad = 0.02 * (hi - lo)
            lo, hi = lo - (pad if lo != 0 else 0), hi + pad
        for p in bars:
            (p.ax.set_xlim if horizontal else p.ax.set_ylim)(lo, hi)

    def layout(self):
        """Place titles, then solve the panel grid so that every tick label, end
        label and legend fits inside the figure."""
        fig, s = self.fig, self.s
        for a in getattr(self, "_title_artists", []):
            a.remove()
        self._title_artists = arts = []
        title = join_lines(s.get("title"))
        subtitle = join_lines(s.get("subtitle"))
        ytitle = self.ytitle
        note = "\n".join(x for x in [join_lines(s.get("note")), join_lines(s.get("caption"))] if x)
        sub_is_ytitle = False
        if ytitle and not subtitle:
            subtitle, ytitle, sub_is_ytitle = ytitle, "", True
        H, W = self.ys * 72.0, self.xs * 72.0
        k = self.k
        padx, pady = self.padx, self.pady
        ycur = H - pady
        left = padx / W
        p0 = self.panels[0] if self.panels else None
        fs_title = self.tsize(s.get("title_size"), 14.0)
        fs_sub = self.tsize(s.get("subtitle_size"), 10.5)
        fs_note = self.tsize(s.get("note_size"), 8.0)
        fs_y = p0.axis_title_size("y") if p0 is not None else self.tsize(None, 9.5)
        fs_x = p0.axis_title_size("x") if p0 is not None else self.tsize(None, 9.5)
        if sub_is_ytitle:
            fs_sub = fs_y
        # the y-axis title goes above the plot on the side of the y axis: on the
        # right with yscale(alt) or a y axis Stata drew on the right (in by() graphs
        # Stata keeps the shared title on the left)
        yt_right = (bool(self.ytitle) and not self.multi and p0 is not None
                    and getattr(p0, "yside", "left") == "right")
        self._ytitle_artist = None
        self._ytitle_any = None
        if title:
            arts.append(fig.text(left, ycur / H, title, fontsize=fs_title, fontweight="bold",
                                 color=INK, ha="left", va="top", linespacing=1.15))
            ycur -= fs_title * 1.22 * (title.count("\n") + 1) + 3 * k
        if subtitle:
            right = sub_is_ytitle and yt_right
            a = fig.text(1 - left if right else left, ycur / H, subtitle, fontsize=fs_sub,
                         color=MUTED, ha="right" if right else "left", va="top",
                         linespacing=1.2)
            arts.append(a)
            if right:
                self._ytitle_artist = a
            if sub_is_ytitle:
                self._ytitle_any = a
            ycur -= fs_sub * 1.3 * (subtitle.count("\n") + 1) + 2 * k
        if ytitle:
            a = fig.text(1 - left if yt_right else left, ycur / H, ytitle, fontsize=fs_y,
                         color=MUTED, ha="right" if yt_right else "left", va="top")
            arts.append(a)
            self._ytitle_any = a
            if yt_right:
                self._ytitle_artist = a
            ycur -= fs_y * 1.35
        if self.fig_legend:
            handles, texts, lp = self.fig_legend
            ycur -= 4 * k
            fs_leg = self.tsize((s.get("legend") or {}).get("size"), 9.0)
            rr = fig.canvas.get_renderer()
            ncol = min(len(handles), 5)
            colfirst = (s.get("legend") or {}).get("colfirst") == "yes"
            while True:
                perm = legend_perm(len(handles), ncol, colfirst)
                leg = fig.legend([handles[i] for i in perm], [texts[i] for i in perm],
                                 loc="upper left",
                                 bbox_to_anchor=(left - 4 * k / W, ycur / H), ncol=ncol,
                                 frameon=False, fontsize=fs_leg, handlelength=1.6,
                                 handletextpad=0.5, columnspacing=1.4, borderaxespad=0.0,
                                 borderpad=0.1)
                if ncol <= 1 or leg.get_window_extent(rr).x1 <= fig.bbox.width * (1 - left) + 0.5:
                    break
                leg.remove()
                ncol -= 1
            leg._g2m_perm = perm
            self._fig_leg_artist = leg
            lp.restyle_legend(leg)
            arts.append(leg)
            ycur -= leg.get_window_extent(rr).height * 72.0 / fig.dpi + 2 * k
        ycur -= 8 * k
        bottom = pady
        if note:
            arts.append(fig.text(left, pady / H, note, fontsize=fs_note, color=MUTED, ha="left",
                                 va="bottom", linespacing=1.3))
            bottom += fs_note * 1.35 * (note.count("\n") + 1) + 6 * k
        if self.xtitle:
            xt = fig.text(0.5, bottom / H, self.xtitle, fontsize=fs_x, color=MUTED,
                          ha="center", va="bottom")
            arts.append(xt)
            self._xtitle_artist = xt
            bottom += fs_x * 1.3 + 5 * k
        else:
            self._xtitle_artist = None

        L, B, R, T = padx / W, bottom / H, 1 - padx / W, ycur / H
        rows, cols = self.rows, self.cols
        tight = s.get("family") == "matrix"
        gapx = ((5.0 if tight else 16.0) * k / W) if cols > 1 else 0.0
        gapy = ((5.0 if tight else 14.0) * k / H) if rows > 1 else 0.0
        dl, dr = [0.0] * cols, [0.0] * cols
        dt_, db = [0.0] * rows, [0.0] * rows
        # graph combine gives each member an equal cell and does not line up the
        # members' axes: a member's plot is its cell less its own tick labels, end
        # labels and titles. by() panels share one plot width.
        percell = s.get("family") == "combine"
        n = len(self.panels)
        pl, pr_ = [0.0] * n, [0.0] * n
        rects = {}
        for _ in range(4):
            w = ((R - L) - sum(dl) - sum(dr) - gapx * (cols - 1)) / cols
            h = ((T - B) - sum(dt_) - sum(db) - gapy * (rows - 1)) / rows
            if w < 0.08 or h < 0.08:
                w, h = max(w, 0.08), max(h, 0.08)
            cw = ((R - L) - gapx * (cols - 1)) / cols
            for k, p in enumerate(self.panels):
                r_, c_ = divmod(k, cols)
                y1 = T - sum(dt_[j] + h + db[j] + gapy for j in range(r_)) - dt_[r_]
                if percell:
                    wk = max(cw - pl[k] - pr_[k], 0.08)
                    x0 = L + c_ * (cw + gapx) + pl[k]
                    rects[k] = [x0, y1 - h, wk, h]
                else:
                    x0 = L + sum(dl[j] + w + dr[j] + gapx for j in range(c_)) + dl[c_]
                    rects[k] = [x0, y1 - h, w, h]
                p.set_position(rects[k])
                p.apply_margins()
            fig.canvas.draw()
            rr = fig.canvas.get_renderer()
            ndl, ndr = [0.0] * cols, [0.0] * cols
            ndt, ndb = [0.0] * rows, [0.0] * rows
            for k, p in enumerate(self.panels):
                r_, c_ = divmod(k, cols)
                bb = p.tightbbox(rr)
                x0, y0, w0, h0 = rects[k]
                pl[k], pr_[k] = x0 - bb.x0, bb.x1 - (x0 + w0)
                ndl[c_] = max(ndl[c_], pl[k])
                ndr[c_] = max(ndr[c_], pr_[k])
                ndb[r_] = max(ndb[r_], y0 - bb.y0)
                ndt[r_] = max(ndt[r_], bb.y1 - (y0 + h0))
            dl, dr, dt_, db = ndl, ndr, ndt, ndb
        if self._xtitle_artist is not None and self.panels:
            xs = [rects[k][0] for k in rects] + [rects[k][0] + rects[k][2] for k in rects]
            self._xtitle_artist.set_x((min(xs) + max(xs)) / 2)
        if self._ytitle_artist is not None and self.panels:
            # right-aligned with the outer edge of the y-axis tick labels
            fig.canvas.draw()
            rr = fig.canvas.get_renderer()
            self._ytitle_artist.set_x(max(p.tightbbox(rr).x1 for p in self.panels))
        self.aspect_titles()

    def aspect_titles(self):
        """aspectratio() in a single graph shrinks and centres the plot region; the
        axis titles move with it, as Stata keeps them beside the axes."""
        asp = num(self.s.get("aspect"), 0.0) or 0.0
        if asp <= 0 or self.multi or len(self.panels) != 1:
            return
        fig, p = self.fig, self.panels[0]
        fig.canvas.draw()
        rr = fig.canvas.get_renderer()
        pos = p.ax.get_position()  # the active (shrunk) box after drawing
        bb = p.tightbbox(rr)  # figure fraction, tick labels included
        gap = 6 * self.k / (self.ys * 72.0)
        xt = self._xtitle_artist
        if xt is not None:
            xt.set_x((pos.x0 + pos.x1) / 2)
            xt.set_va("top")
            xt.set_y(bb.y0 - gap)
        yt = self._ytitle_any
        if yt is not None:
            # house style: the y title sits above the plot, flush with its tick labels
            yt.set_va("bottom")
            yt.set_y(pos.y1 + gap)
            yt.set_x(bb.x1 if yt is self._ytitle_artist else bb.x0)

    def info_lines(self):
        """A plain-text record of what was drawn (render_info.txt in the spec
        folder; kept with keepspec). The test battery reads it."""
        out = []
        fig = self.fig
        r = fig.canvas.get_renderer()
        out.append(f"family={self.s.get('family', '')}")
        fl = getattr(self, "fig_legend", None)
        if fl:
            out.append("fig_legend=" + "|".join(str(t) for t in fl[1]))
            fa = getattr(self, "_fig_leg_artist", None)
            if fa is not None:
                out.append("fig_legend_read=" + "|".join(legend_reading(fa, r)))
            out.append("fig_legend_plots=" + "|".join(
                str(k) for k in getattr(fl[2], "_legend_plots", [])))
        arts = getattr(self, "_title_artists", [])
        texts = [a for a in arts if isinstance(a, matplotlib.text.Text)]
        if texts and self.s.get("title"):
            out.append(f"title={texts[0].get_text()}")
            out.append(f"title_fs={texts[0].get_fontsize():.2f}")
        for a in texts:
            out.append(f"figtext={a.get_text()}|{a.get_fontsize():.2f}")
        # where the axis titles sit relative to the first panel's drawn plot box
        # (figure fraction): x title gap below the box, y title gap above it
        if self.panels:
            pos0 = self.panels[0].ax.get_position()
            xa = getattr(self, "_xtitle_artist", None)
            if xa is not None:
                xb = xa.get_window_extent(r).transformed(fig.transFigure.inverted())
                out.append(f"xtitle_gap={pos0.y0 - xb.y1:.3f}")
            ya_ = getattr(self, "_ytitle_any", None)
            if ya_ is not None:
                yb = ya_.get_window_extent(r).transformed(fig.transFigure.inverted())
                out.append(f"ytitle_gap={yb.y0 - pos0.y1:.3f}")
        ya = getattr(self, "_ytitle_artist", None)
        if self.ytitle:
            out.append("ytitle_side=" + ("right" if ya is not None else "left"))
        out.append("font_family=" + ",".join(plt.rcParams["font.family"]))
        out.append("glyphs_missing=" + self.missing_glyphs())
        for k, p in enumerate(self.panels):
            ax, tag = p.ax, f"panel{k + 1}"
            pos = ax.get_position()
            axbb = ax.get_window_extent(r)
            out.append(f"{tag}.axes={pos.x0:.3f},{pos.y0:.3f},{pos.width:.3f},{pos.height:.3f}")
            if p.s.get("family") == "bar":
                vlo, vhi = sorted(ax.get_xlim() if p.horizontal else ax.get_ylim())
                out.append(f"{tag}.barscale={vlo:.4g},{vhi:.4g}")
                sup = getattr(p, "_sup", None) or []
                if sup:
                    inner = [t.get_window_extent(r) for t in ax.get_xticklabels()
                             if t.get_text() and t.get_visible()]
                    sb = [a.get_window_extent(r) for a in sup]
                    sov = sum(1 for a in sb for b in inner
                              if min(a.x1, b.x1) - max(a.x0, b.x0) > 0.5
                              and min(a.y1, b.y1) - max(a.y0, b.y0) > 0.5)
                    out.append(f"{tag}.sup_overlaps={sov}")
                    out.append(f"{tag}.sup_below={int(max(a.y1 for a in sb) <= min(b.y0 for b in inner) + 0.5)}")
            pt = ax.get_title(loc="left")
            if pt:
                out.append(f"{tag}.ptitle={pt}")
            t = getattr(p, "sub_artist", None)
            if t is not None:
                out.append(f"{tag}.psubtitle={t.get_text()}")
                tb = t.get_window_extent(r)
                if ax.get_title(loc="left"):
                    lt = ax._left_title.get_window_extent(r)
                    out.append(f"{tag}.psubtitle_below_title={int(tb.y1 <= lt.y0 + 0.5)}")
            na = getattr(p, "note_artist", None)
            if na is not None:
                out.append(f"{tag}.pnote=" + na.get_text().replace("\n", "/"))
                nb = na.get_window_extent(r)
                xl = ax.xaxis.get_tightbbox(r)
                out.append(f"{tag}.pnote_below_xaxis={int(xl is None or nb.y1 <= xl.y0 + 0.5)}")
                out.append(f"{tag}.pnote_inside={int(nb.y0 >= -0.5 and nb.x1 <= fig.bbox.width + 0.5)}")
            yl = ax.get_ylabel()
            if yl:
                out.append(f"{tag}.ylabel={yl}")
            for info in p.infos:
                which = "y2" if (p.ax2 is not None and info["ax"] is p.ax2) else "y1"
                out.append(f"{tag}.plot{info['p'].get('index')}.axis={which}")
            xt = [t.get_text().replace("\n", "/") for t in ax.get_xticklabels()]
            out.append(f"{tag}.xticks=" + "|".join(xt))
            out.append(f"{tag}.yticks=" + "|".join(t.get_text() for t in ax.get_yticklabels()))
            out.append(f"{tag}.xminor=" + "|".join(t.get_text() for t in ax.get_xticklabels(minor=True)))
            out.append(f"{tag}.yminor=" + "|".join(t.get_text() for t in ax.get_yticklabels(minor=True)))
            ba = ax.get_box_aspect()
            out.append(f"{tag}.box_aspect={0 if ba is None else ba:g}")
            rot = [t.get_rotation() for t in ax.get_xticklabels()]
            out.append(f"{tag}.xtickangle={rot[0] if rot else 0:g}")
            fs = [t.get_fontsize() for t in ax.get_xticklabels()]
            out.append(f"{tag}.xtickfs={fs[0] if fs else 0:.2f}")
            out.append(f"{tag}.xlabel={ax.get_xlabel()}")
            out.append(f"{tag}.ylabel={ax.get_ylabel()}")
            out.append(f"{tag}.ygrid={int(any(g.get_visible() for g in ax.yaxis.get_gridlines()))}")
            if p.ax2 is not None:
                out.append(f"{tag}.y2ticks=" + "|".join(t.get_text() for t in p.ax2.get_yticklabels()))
                out.append(f"{tag}.y2label={p.ax2.get_ylabel()}")
            if p.leg is not None:
                lb = p.leg.get_window_extent(r)
                out.append(f"{tag}.legend=" + "|".join(legend_reading(p.leg, r)))
                out.append(f"{tag}.legend_plots=" + "|".join(
                    str(k) for k in getattr(p, "_legend_plots", [])))
                out.append(f"{tag}.legend_title={p.leg.get_title().get_text()}")
                out.append(f"{tag}.legend_inside={int(lb.x0 >= -0.5 and lb.x1 <= fig.bbox.width + 0.5)}")
            anns = []
            for a_ax, which in ((ax, "y1"), (p.ax2, "y2")):
                if a_ax is None:
                    continue
                for c in a_ax.texts:
                    if not c.get_text() or c is getattr(p, "sub_artist", None) \
                            or c is getattr(p, "note_artist", None):
                        continue
                    bb = c.get_window_extent(r)
                    side = ("right" if bb.x0 >= axbb.x1 - 1 else
                            "left" if bb.x1 <= axbb.x0 + 1 else "in")
                    anns.append(bb)
                    out.append(f"{tag}.ann={c.get_text()}|{c.get_ha()}|{c.get_rotation():g}|"
                               f"{which}|{side}")
            over = sum(1 for m in range(len(anns)) for n in range(m + 1, len(anns))
                       if anns[m].overlaps(anns[n]) and anns[m].width > 0 and anns[n].width > 0
                       and min(anns[m].x1, anns[n].x1) - max(anns[m].x0, anns[n].x0) > 1
                       and min(anns[m].y1, anns[n].y1) - max(anns[m].y0, anns[n].y0) > 1)
            out.append(f"{tag}.ann_overlaps={over}")
            # text that runs into tick labels (an end label over a y axis drawn on its side)
            ticks = []
            for t_ax in (ax, p.ax2):
                if t_ax is None:
                    continue
                for t in t_ax.get_yticklabels() + t_ax.get_xticklabels():
                    if t.get_visible() and t.get_text():
                        ticks.append(t.get_window_extent(r))
            tover = sum(1 for a in anns for b in ticks
                        if min(a.x1, b.x1) - max(a.x0, b.x0) > 1
                        and min(a.y1, b.y1) - max(a.y0, b.y0) > 1)
            out.append(f"{tag}.ann_tick_overlaps={tover}")
            out.append(f"{tag}.yside={getattr(p, 'yside', 'left')}")
            ylo, yhi = sorted(ax.get_ylim())
            out.append(f"{tag}.ylim={ylo:g},{yhi:g}")
            if p.ax2 is not None:
                out.append(f"{tag}.y2side={p.y2side}")
            # gpolish endlabel, values: the gap (points) between each label and its value
            gaps = []
            for lab, v in getattr(p, "_end_pairs", []):
                la, va = lab.get("_artists", []), v.get("_artists", [])
                if not la or not va:
                    continue
                lb = Bbox.union([a.get_window_extent(r) for a in la])
                vb = Bbox.union([a.get_window_extent(r) for a in va])
                g = (vb.x0 - lb.x1) if vb.x0 >= lb.x0 else (lb.x0 - vb.x1)
                gaps.append(g * 72.0 / fig.dpi)
            if gaps:
                out.append(f"{tag}.endpair_mingap={min(gaps):.1f}")
            # where the data range sits inside the axes, in points from the left and
            # bottom edges (shows a kept plot-region margin)
            if p.infos:
                bb = ax.get_window_extent(r)
                fin = [i["x"][np.isfinite(i["x"])] for i in p.infos]
                xs_ = [v.min() for v in fin if v.size]
                xe_ = [v.max() for v in fin if v.size]
                if xs_:
                    px = ax.transData.transform([(min(xs_), 0), (max(xe_), 0)])[:, 0]
                    k72 = 72.0 / fig.dpi
                    out.append(f"{tag}.xdata_pts={(px.min() - bb.x0) * k72:.1f},"
                               f"{(bb.x1 - px.max()) * k72:.1f}")
                    out.append(f"{tag}.xdata_frac={(px.max() - px.min()) / max(bb.width, 1e-9):.3f}")
                out.append(f"{tag}.axes_wpts={bb.width * 72.0 / fig.dpi:.1f}")
            # end labels: clear of their line when they start right of every point of it
            for lab, pts in getattr(p, "_end_series", []):
                for c in ax.texts:
                    if c.get_text() == lab:
                        sx = ax.transData.transform(pts)[:, 0].max()
                        clear = c.get_window_extent(r).x0 >= sx - 0.5
                        out.append(f"{tag}.endlabel={lab}|{'clear' if clear else 'over'}")
            for a_ax, which in ((ax, "y1"), (p.ax2, "y2")):
                if a_ax is None:
                    continue
                for ln in a_ax.get_lines():
                    xd = np.asarray(ln.get_xdata(), dtype=float)
                    yd = np.asarray(ln.get_ydata(), dtype=float)
                    if xd.size == 2 and ln.get_transform() != a_ax.transData:
                        # axhline / axvline: a reference line
                        if np.allclose(yd, yd[0]) and not np.allclose(xd, xd[0]):
                            out.append(f"{tag}.refline={which}:y:{yd[0]:g}")
                        elif np.allclose(xd, xd[0]):
                            out.append(f"{tag}.refline={which}:x:{xd[0]:g}")
                        continue
                    ds = ln.get_drawstyle()
                    if ds and ds != "default":
                        out.append(f"{tag}.drawstyle={ds}")
                    if yd.size > 2:
                        out.append(f"{tag}.line_nan={int(np.isnan(yd).sum())}")
                        ok = ~np.isnan(xd)
                        if ok.any():
                            out.append(f"{tag}.line_x={xd[ok].min():g},{xd[ok].max():g}")
            for c in ax.collections:
                if hasattr(c, "get_segments") and len(c.get_segments()):
                    s0 = c.get_segments()[0]
                    kind = "h" if abs(s0[0][1] - s0[-1][1]) < 1e-12 else "v"
                    out.append(f"{tag}.segments={kind}{len(c.get_segments())}")
            out.append(f"{tag}.patches={len(ax.patches)}")
            if p.ax2 is not None:
                out.append(f"{tag}.y2_on_top={int(p.ax2.get_zorder() > ax.get_zorder())}")
            mk = [ln for ln in ax.lines if ln.get_marker() not in (None, "None", "", " ")]
            if mk:
                out.append(f"{tag}.marker_ms={mk[0].get_markersize():.2f}")
            dk = getattr(p, "_dotkeys", None)
            if dk:
                out.append(f"{tag}.dotkeys=" + "|".join(dk))
            dm = getattr(p, "_dotms", None)
            if dm:
                out.append(f"{tag}.dot_ms={min(dm):.2f},{max(dm):.2f}")
        return out

    def missing_glyphs(self):
        """Characters in the figure's text that no font in the font list can draw."""
        try:
            from matplotlib.ft2font import FT2Font
        except ImportError:
            return ""
        fonts = []
        for name in plt.rcParams["font.family"]:
            try:
                path = font_manager.findfont(font_manager.FontProperties(family=name),
                                             fallback_to_default=False)
                fonts.append(FT2Font(path))
            except Exception:
                continue
        chars = set()
        for t in self.fig.findobj(matplotlib.text.Text):
            chars.update(c for c in t.get_text() if ord(c) > 127 and not c.isspace())
        miss = [c for c in sorted(chars)
                if not any(f.get_char_index(ord(c)) for f in fonts)]
        return "".join(miss)

    def outline_narrow(self):
        """Outline bars and range areas that end up under about two pixels wide
        on the final axis in their own colour, as Stata draws them, so each still
        shows as at least a hairline. The test uses the plotted axis range, which
        other series (or explicit scales) may widen far past the series' own span."""
        self.fig.canvas.draw()
        for pnl in getattr(self, "panels", []):
            for info in pnl.infos:
                ax = info.get("ax") or pnl.ax
                if info.get("type") not in ("bar", "rbar", "rarea") or ax is None:
                    continue
                # a horizontal series spans its x() values on the y axis (rarea
                # records this separately, so it does not change the axis layout)
                horiz = bool(info.get("horizontal") or info.get("narrow_horizontal"))
                lo, hi = ax.get_ylim() if horiz else ax.get_xlim()
                bb = ax.get_window_extent()
                pix = bb.height if horiz else bb.width
                rng = abs(hi - lo)
                if rng <= 0 or pix <= 0:
                    continue
                if info["type"] == "rarea":
                    fx = info["x"][np.isfinite(info["x"])]
                    if len(fx) == 0:
                        continue
                    w = float(fx.max() - fx.min())
                else:
                    w = float(info.get("barwidth") or 0)
                if w * pix / rng >= 2.0:
                    continue
                h = info.get("handle")
                if info["type"] == "rarea":
                    fc = h.get_facecolor() if hasattr(h, "get_facecolor") else None
                    if fc is None or len(fc) == 0 or fc[0][3] == 0:
                        continue
                    c = tuple(fc[0][:3]) + (1.0,)
                    h.set_edgecolor(c)
                    h.set_linewidth(0.6)
                elif not info.get("outlined"):
                    for patch in h:
                        c = tuple(patch.get_facecolor()[:3]) + (1.0,)
                        patch.set_edgecolor(c)
                        patch.set_linewidth(0.6)

    def save(self):
        out = self.s.get("saving") or "gr2mpl.png"
        try:
            self.outline_narrow()
        except Exception:
            pass
        self.fig.savefig(out, dpi=self.dpi, facecolor="white")
        try:
            with open(os.path.join(self.dir, "render_info.txt"), "w", encoding="utf-8") as fh:
                fh.write("\n".join(self.info_lines()) + "\n")
        except Exception as e:  # the record is for checking only; never fail the render
            print("render_info:", e)
        plt.close(self.fig)
        path = os.path.join(self.dir, "skipped.txt")
        if self.skipped:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write("\n".join(self.skipped) + "\n")
        elif os.path.exists(path):
            os.remove(path)
        npath = os.path.join(self.dir, "notes.txt")
        if self.notes:
            with open(npath, "w", encoding="utf-8") as fh:
                fh.write("\n".join(self.notes) + "\n")
        for w in self.skipped:
            print("skipped:", w)
        print("saved", out)


def mpl_too_old():
    """The installed matplotlib version when it is older than MIN_MPL, else ''."""
    m = re.match(r"(\d+)\.(\d+)", matplotlib.__version__)
    if m and (int(m.group(1)), int(m.group(2))) < MIN_MPL:
        return matplotlib.__version__
    return ""


def doctor(font, mpl_line=True):
    """Print the setup report. `gr2mpl doctor` prints the matplotlib line itself
    and passes --doctor-ado, which leaves it out here."""
    print(f"  python      : {sys.executable} ({sys.version.split()[0]})")
    if mpl_line:
        need = f"{MIN_MPL[0]}.{MIN_MPL[1]} or later"
        status = f"TOO OLD: gr2mpl needs {need}" if mpl_too_old() else f"{need} needed: OK"
        print(f"  matplotlib  : {matplotlib.__version__} ({status})")
    print(f"  numpy       : {np.__version__}")
    want = font or FONT_FALLBACKS[0]
    got = pick_font(want)
    status = "found" if got == want else f"NOT found, will fall back to {got}"
    print(f"  font        : {want} ({status})")


def main(argv):
    if len(argv) >= 2 and argv[1] in ("--doctor", "--doctor-ado"):
        doctor(" ".join(argv[2:]).strip().strip('"'), mpl_line=argv[1] == "--doctor")
        return
    old = mpl_too_old()
    if old:
        print(f"gr2mpl needs matplotlib {MIN_MPL[0]}.{MIN_MPL[1]} or later; this Python "
              f"({sys.executable}) has matplotlib {old}.")
        print("fix: python -m pip install --upgrade matplotlib")
        raise SystemExit(1)
    # Stata's `python script, args()` passes quotes through and splits on spaces
    path = " ".join(argv[1:]).strip().strip('"')
    with open(path, encoding="utf-8") as fh:
        spec = json.load(fh, strict=False)
    if not spec.get("specdir"):
        spec["specdir"] = os.path.dirname(path)
    Figure(spec).render()


if __name__ == "__main__":
    main(sys.argv)
