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
import json
import math
import os
import re
import sys

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import matplotlib.patheffects as pe  # noqa: E402
from matplotlib import font_manager  # noqa: E402
from matplotlib.colors import to_rgba  # noqa: E402
from matplotlib.transforms import Bbox  # noqa: E402
from matplotlib.offsetbox import AnnotationBbox, DrawingArea  # noqa: E402
from matplotlib.patches import FancyBboxPatch, Polygon, Rectangle  # noqa: E402

INK = "#1F2328"
MUTED = "#6B7280"
GRID = "#E5E7EB"
AXIS = "#9CA3AF"
HOUSE = ["#1F6FB2", "#D1495B", "#2E9E6B", "#E0A100", "#6C4AB6", "#00A0B0",
         "#C2571A", "#7A7F87"]
FONT_FALLBACKS = ["Open Sans", "Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans"]
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


def _strip_tags(s):
    s = re.sub(r"\{c (\d+)\}", lambda m: chr(int(m.group(1))), s)
    s = re.sub(r"\{(it|bind|stSerif|stSans|stMono|stSymbol):([^}]*)\}", r"\2", s)
    s = re.sub(r"\{fontface [^:}]*:([^}]*)\}", r"\1", s)
    s = re.sub(r"\{&([a-zA-Z]+)\}", r"\1", s)
    return s


def clean_text(s):
    """Plain text: SMCL tags dropped, dollar signs escaped (not math)."""
    if not s:
        return ""
    s = re.sub(r"\{bf:([^}]*)\}", r"\1", _strip_tags(s))
    return s.replace("$", r"\$")


def rich_segments(s):
    """One line -> [(text, is_bold), ...] honouring {bf:...}."""
    parts = re.split(r"\{bf:([^}]*)\}", _strip_tags(s or ""))
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


def nice_dates(pos, labs):
    """Stata's default %td labels (01jan2001) read better as 'Jan 2001'."""
    if not labs or not all(re.fullmatch(r"\d{2}[a-z]{3}\d{4}", l or "") for l in labs):
        return labs
    base = dt.date(1960, 1, 1)
    dates = [base + dt.timedelta(days=int(round(p))) for p in pos]
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
        self.legend_style = {}
        self.axis_off = set()
        self._slots = {}
        self.style_axes(ax)

    # ---- small accessors ---------------------------------------------------
    def pts(self, v):
        return v * self.f.unit

    def lw(self, p, key="lwidth", floor=0.6):
        v = num(p.get(key))
        if v is None:
            return max(floor, 1.2)
        return max(floor, self.pts(v) * self.f.lwscale)

    def ms(self, p, floor=2.0):
        v = num(p.get("msize"))
        if v is None:
            return 5.0
        return max(floor, self.pts(v) * self.f.msscale)

    def skip(self, msg):
        where = f"panel {self.index + 1}: " if self.f.multi else ""
        self.f.skipped.append(where + msg)

    def style_axes(self, ax):
        for side in ("top", "right", "left"):
            ax.spines[side].set_visible(False)
        ax.spines["bottom"].set_color(AXIS)
        ax.spines["bottom"].set_linewidth(0.9)
        ax.tick_params(axis="both", length=0, labelsize=self.f.tickfs, pad=5)
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
        if s.get("y2axis") and any(str(p.get("yaxis")) == "2" for p in s.get("plots", [])):
            self.ax2 = self.ax.twinx()
            self.style_axes(self.ax2)
            self.ax2.spines["bottom"].set_visible(False)
            # filled layers on the second axis go behind the first axis
            fills = {"bar", "rbar", "area", "rarea", "spike"}
            behind = all(p.get("type") in fills for p in s.get("plots", [])
                         if str(p.get("yaxis")) == "2")
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
            self.draw_text(t, keep_color=False)
        for t in s.get("added_text", []):
            self.draw_text(t, keep_color=True)
        self.added_shapes()

    def draw_plot(self, p, i):
        t = p.get("type", "")
        if p.get("draw") == "no":
            return None
        if t not in SUPPORTED:
            self.skip(f"plot {p.get('index')} (type {t})")
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
        info = {"type": t, "color": lc, "x": x, "y": y, "handle": None, "p": p,
                "ax": ax}

        def marker_kw():
            if nomarker:
                return dict(marker="None")
            same = tuple(mline[:3]) == tuple(mfill[:3])
            mlw = num(p.get("mlwidth"))
            if hollow:
                return dict(marker=marker, ms=self.ms(p), mfc="white", mec=mline,
                            mew=max(1.0, self.pts(mlw)) if mlw else 1.2)
            size = self.ms(p)
            if same and (self.s.get("role") == "matrix" or size < 4.5):
                # a white rim would eat a small marker; draw it solid instead
                return dict(marker=marker, ms=size, mfc=mfill, mec=mfill, mew=0.0)
            return dict(marker=marker, ms=size, mfc=mfill,
                        mec=mline if not same else "white",
                        mew=self.pts(mlw) if (mlw is not None and not same) else 0.6)

        if t == "line":
            (h,) = ax.plot(x, y, color=lc, lw=self.lw(p), ls=dash, zorder=z + 1,
                           solid_capstyle="round", solid_joinstyle="round")
            info["handle"] = h
        elif t in ("connected", "scatter"):
            ls = dash if t == "connected" else "None"
            (h,) = ax.plot(x, y, color=lc, lw=self.lw(p), ls=ls, zorder=z + 1.5,
                           **marker_kw())
            info["handle"] = h
            info["color"] = lc if t == "connected" else (mline if hollow else mfill)
            labs = self.col(cols, p, "label")
            lmap = p.get("labelmap") or {}
            if labs is not None and lmap:
                labs = [lmap.get(v, lmap.get(v.split(".")[0], v)) for v in labs]
            if labs is not None:
                self.marker_labels(ax, x, y, labs, p)
        elif t in ("bar", "rbar"):
            width = num(p.get("barsize"), 0.8) or 0.8
            base = num(p.get("base"), 0.0)
            lo = y2 if (t == "rbar" and y2 is not None) else np.full_like(y, base)
            kw = dict(color=afill, lw=0.6, edgecolor="white", zorder=z)
            if horizontal:
                h = ax.barh(x, y - lo, left=lo, height=width, **kw)
            else:
                h = ax.bar(x, y - lo, bottom=lo, width=width, **kw)
            info.update(handle=h, color=afill, bars=True, horizontal=horizontal,
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
            h = ax.fill_between(x, base, y, color=col, lw=0, zorder=z)
            ax.plot(x, y, color=afill[:3], lw=1.2, zorder=z + 0.5)
            info.update(handle=h, color=afill)
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
            info.update(handle=h, color=afill, band=True)
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
            (h,) = ax.plot(x, y, color=lc, lw=self.lw(p, floor=0.8), ls=ls, zorder=z + 1, **mk)
            ax.plot(x, y2, color=lc, lw=self.lw(p, floor=0.8), ls=ls, zorder=z + 1, **mk)
            info.update(handle=h, band=True)
        elif t in ("spike", "dropline", "dot"):
            base = num(p.get("base"))
            if base is None:
                base = num(p.get("drawnbase"), 0.0) or 0.0
            if t != "dot":
                ax.vlines(x, base, y, color=lc, lw=self.lw(p, floor=0.9), zorder=z)
            if t in ("dropline", "dot"):
                (h,) = ax.plot(x, y, ls="None", zorder=z + 1, **marker_kw())
                info["handle"] = h
            else:
                info["handle"] = plt.Line2D([], [], color=lc, lw=1.5)
        elif t in PC_TYPES:
            if y2 is None or x2 is None:
                self.skip(f"plot {p.get('index')} (type {t}): second coordinates not found")
                return None
            if horizontal:  # stored unswapped; Stata swaps the axes when drawing
                x, y, x2, y2 = y, x, y2, x2
                info["horizontal"] = True
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
            info["handle"] = plt.Line2D([], [], color=lc, lw=lw)
            info["x"] = np.r_[x, x2]
            info["y"] = np.r_[y, y2]
        return info

    def marker_labels(self, ax, x, y, labs, p):
        pos = str(p.get("labpos", "3")).strip()
        offsets = {"12": (0, 6, "center", "bottom"), "6": (0, -6, "center", "top"),
                   "3": (6, 0, "left", "center"), "9": (-6, 0, "right", "center"),
                   "0": (0, 0, "center", "center"),
                   "1": (5, 5, "left", "bottom"), "2": (5, 5, "left", "bottom"),
                   "4": (5, -5, "left", "top"), "5": (5, -5, "left", "top"),
                   "7": (-5, -5, "right", "top"), "8": (-5, -5, "right", "top"),
                   "10": (-5, 5, "right", "bottom"), "11": (-5, 5, "right", "bottom")}
        dx, dy, ha, va = offsets.get(pos, offsets["3"])
        size = num(p.get("labsize"))
        fs = max(6.5, self.pts(size)) if size else 7.5
        col = stata_color(p.get("labcolor"), to_rgba(MUTED))
        if col[:3] == (0, 0, 0):
            col = to_rgba(INK)
        for xi, yi, lab in zip(x, y, labs):
            if lab in ("nan", "", ".") or np.isnan(xi) or np.isnan(yi):
                continue
            ax.annotate(clean_text(lab), (xi, yi), xytext=(dx, dy),
                        textcoords="offset points", ha=ha, va=va, fontsize=fs,
                        color=col, zorder=5)

    def bar_width(self):
        for i in self.infos:
            if i.get("bars"):
                return num(i["p"].get("barsize"), 0.8) or 0.8
        return 0.8

    def set_ticks(self, ax, which, ticks):
        pos = [t[0] for t in ticks]
        labs = nice_dates(pos, [t[1] for t in ticks])
        if which == "x":
            ax.set_xticks(pos)
            ax.set_xticklabels(labs)
        else:
            ax.set_yticks(pos)
            ax.set_yticklabels(labs)

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
            ticks = [(num(t[0]), clean_text(t[1])) for t in a.get("ticks", [])]
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
            if ticks:
                self.set_ticks(ax, which, ticks)
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
        if self.ax2 is not None:
            self.ax2.tick_params(axis="y", labelright=True, labelleft=False,
                                 labelcolor=MUTED)
            self.ax2.grid(False)

    def reflines(self):
        for r in self.s.get("reflines", []):
            z = num(r.get("z"))
            if z is None:
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
                self.ax.axvline(z, **kw)
            else:
                self.ax.axhline(z, **kw)

    def draw_text(self, t, keep_color):
        """Text box anchored to a data point. Each {bf:} run is its own artist,
        placed with point offsets (rotated about the anchor when an angle is set)."""
        if t.get("draw") == "no":
            return
        x, y = num(t.get("x")), num(t.get("y"))
        lines = [rich_segments(l) for l in (t.get("text") or [])]
        lines = [l for l in lines if l]
        if x is None or y is None or not lines:
            return
        col = stata_color(t.get("color"), to_rgba(INK))
        if not keep_color and col[:3] == (0, 0, 0):
            col = to_rgba(INK)
        ha, va = ALIGN.get(str(t.get("place", "")).strip().lower(), ("center", "center"))
        size = num(t.get("size"))
        fs = self.pts(size) if size else 9.0
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
                                 + (num(t.get("m" + k), 0.0) or 0.0))
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
            self.ax.add_artist(ab)
            cx += (padl - padr) / 2
            cy += (padb - padt) / 2
        for k, line in enumerate(lines):
            lx = -W / 2 + {"left": 0, "center": (W - lw_[k]) / 2, "right": W - lw_[k]}[ml]
            ly = H / 2 - (k + 0.5) * lh
            for (txt, bold), w in zip(line, widths[k]):
                a = self.ax.annotate(txt, xy=(x, y),
                                     xytext=(cx + lx * ct - ly * st, cy + lx * st + ly * ct),
                                     textcoords="offset points", ha="left", va="center",
                                     rotation=theta, rotation_mode="anchor",
                                     fontsize=fs, color=col,
                                     fontweight="bold" if bold else "normal",
                                     annotation_clip=False, zorder=8)
                if not box:
                    self.halo(a)
                lx += w

    def added_shapes(self):
        ax = self.ax
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
        leg = leg if leg is not None else self.s.get("legend", {})
        out = {}
        if leg.get("draw") != "no":
            for e in leg.get("entries", []):
                k = num(e[0])
                if k is not None and e[1]:
                    lab = clean_text(e[1])
                    out[int(k)] = lab
                    col = stata_color(e[2], None) if len(e) > 2 else None
                    bold = bool(re.fullmatch(r"\s*\{bf:[^}]*\}\s*", e[1]))
                    self.legend_style[lab] = (col, bold)
        return out

    def legend_items(self, labels):
        handles, texts, seen = [], [], set()
        for info in self.infos:
            lab = labels.get(info["p"]["index"])
            if not lab or info["handle"] is None or lab in seen:
                continue
            seen.add(lab)
            handles.append(info["handle"])
            texts.append(lab)
        if len(handles) == 1 and len(self.infos) == 1:
            return [], []
        return handles, texts

    def restyle_legend(self, leg):
        for txt in leg.get_texts():
            col, bold = self.legend_style.get(txt.get_text(), (None, False))
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
            cax.tick_params(axis="y", length=0, labelsize=7.5, pad=3, left=False, right=True,
                            labelleft=False, labelright=True, labelcolor=MUTED)
            for sp in cax.spines.values():
                sp.set_visible(False)
            title = clean_text(leg.get("title", ""))
            if title:
                cax.set_title(title, fontsize=8.5, color=MUTED, loc="left", pad=4)
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
        cax.tick_params(axis="x", length=0, labelsize=7.5, pad=2, top=True, bottom=False,
                        labeltop=True, labelbottom=False, labelcolor=MUTED)
        for sp in cax.spines.values():
            sp.set_visible(False)
        title = clean_text(self.s.get("legend", {}).get("title", ""))
        if title:
            cax.text(1.03, 0.5, title, transform=cax.transAxes, fontsize=8.5, color=MUTED,
                     ha="left", va="center")
        self.has_legend = True
        return True

    def legend(self):
        labels = self.series_labels()
        polys = [i for i in self.infos if i.get("poly") and i["p"]["index"] in labels]
        if len(polys) >= 5 and len(polys) == len(labels):
            return self.ramp_legend(labels)
        handles, texts = self.legend_items(labels)
        if not handles:
            return False
        one_row = num(self.s.get("legend", {}).get("rows")) == 1 or len(handles) <= 6
        leg = self.ax.legend(handles, texts, loc="lower left", bbox_to_anchor=(0, 1.0),
                             ncol=len(handles) if one_row else 4, frameon=False,
                             fontsize=self.f.tickfs - 0.5, handlelength=1.6,
                             handletextpad=0.5, columnspacing=1.4, borderaxespad=0.2,
                             labelcolor=INK)
        self.restyle_legend(leg)
        self.has_legend = True
        return True

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
            j = np.where(ok)[0][np.argmax(x[ok])]
            cands.append((x[j], y[j], lab, info["color"]))
        if not cands:
            return False
        fig.canvas.draw()
        ypix = np.array([ax.transData.transform((c[0], c[1]))[1] for c in cands])
        fs = 9.5
        sep = fs * 1.28 * fig.dpi / 72.0
        ext = ax.get_window_extent()
        newpix = repel_1d(ypix, sep, ext.y0, ext.y1)
        inv = ax.transData.inverted()
        for (cx, cy, lab, col), py_new in zip(cands, newpix):
            px = ax.transData.transform((cx, cy))[0]
            ynew = inv.transform((px, py_new))[1]
            ax.annotate(lab, xy=(cx, ynew), xytext=(8, 0), textcoords="offset points",
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
            if any(val is None for val in v.values()):
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
            seg(z, v["adjl"], z, v["p25"], color=c[:3], lw=1.2, zorder=2)
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
                ax.plot([x], [y], ls="None", marker=MARKERS.get(str(m.get("symbol")), "o"),
                        ms=max(size * 0.6, self.pts(sz) * self.f.msscale) if sz else size,
                        mfc=c if arr == "points" else "white", mec=c if arr == "outsides" else "white",
                        mew=1.0 if arr == "outsides" else 0.6, zorder=3)
        self.bar_seen = seen
        sticks = [(num(t[0]), clean_text(t[1])) for t in s.get("scaleaxis", [])]
        gticks = [(num(t[0]), clean_text(t[1])) for t in s.get("grpaxis", [])]
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
            if sticks:
                ax.set_yticks([t[0] for t in sticks])
                ax.set_yticklabels([t[1] for t in sticks])
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
            off = {"left": 3, "right": -3, "center": 0}[ha], {"bottom": 3, "top": -3, "center": 0}[va]
            ax.annotate(txt, (x, y), xytext=off, textcoords="offset points", ha=ha, va=va,
                        fontsize=max(6.5, self.f.tickfs - 1.5), color=INK, zorder=4,
                        annotation_clip=False)
        sup = [(num(t[0]), clean_text(t[1])) for t in s.get("supaxis", [])]
        sup = [t for t in sup if t[0] is not None and t[1]]
        if not sup:
            return
        fig = self.f.fig
        fig.canvas.draw()
        r = fig.canvas.get_renderer()
        px2pt = 72.0 / fig.dpi
        fs = self.f.tickfs
        if self.horizontal:
            wmax = max([t.get_window_extent(r).width for t in ax.get_yticklabels()] or [0])
            for pos, lab in sup:
                ax.annotate(lab, xy=(0, pos), xycoords=("axes fraction", "data"),
                            xytext=(-(wmax * px2pt + 16), 0), textcoords="offset points",
                            ha="right", va="center", fontsize=fs, fontweight="bold",
                            color="#374151", annotation_clip=False)
        else:
            hmax = max([t.get_window_extent(r).height for t in ax.get_xticklabels()] or [0])
            for pos, lab in sup:
                ax.annotate(lab, xy=(pos, 0), xycoords=("data", "axes fraction"),
                            xytext=(0, -(hmax * px2pt + 14)), textcoords="offset points",
                            ha="center", va="top", fontsize=fs, fontweight="bold",
                            color="#374151", annotation_clip=False)

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
                handles.append(plt.Line2D([], [], ls="None", marker="o", ms=6, mfc=c,
                                          mec="white"))
            else:
                handles.append(plt.Rectangle((0, 0), 1, 1, facecolor=c, edgecolor="none"))
        self.ax.legend(handles, [clean_text(e[1]) for e in entries], loc="lower left",
                       bbox_to_anchor=(0, 1.0), ncol=min(len(handles), 4), frameon=False,
                       fontsize=self.f.tickfs - 0.5, handlelength=1.1, handleheight=0.9,
                       borderaxespad=0.2)
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
            return True
        return False

    def tightbbox(self, r):
        boxes = [self.ax.get_tightbbox(r)]
        if self.ax2 is not None:
            boxes.append(self.ax2.get_tightbbox(r))
        boxes = [b for b in boxes if b is not None]
        return Bbox.union(boxes).transformed(self.f.fig.transFigure.inverted())

    def set_position(self, rect):
        self.ax.set_position(rect)
        if self.ax2 is not None:
            self.ax2.set_position(rect)

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
        self.unit = min(self.xs, self.ys) * 72.0 / 100.0  # relative size unit -> points
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
        self.tickfs = 8.5 if len(self.pspecs) > 2 else 9.5

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
        plt.rcParams.update({
            "font.family": self.font, "font.size": 10, "text.color": INK,
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
                        ha="center", va="center", fontsize=self.tickfs + 1.5,
                        fontweight="bold", color="#374151", wrap=True)
            elif fam == "blank":
                ax.set_axis_off()
            else:
                p.skip(f"sub-graph of family {fam}")
                ax.set_axis_off()
            self.panels.append(p)

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
                p.ax.set_xlabel(p.axis_title("x"), fontsize=self.tickfs, color=MUTED, labelpad=6)
            if (not self.ytitle or two_axes) and p.axis_title("y"):
                p.ax.set_ylabel(p.axis_title("y"), fontsize=self.tickfs, color=MUTED, labelpad=6)
            if p.ax2 is not None and p.axis_title("y2"):
                p.ax2.set_ylabel(p.axis_title("y2"), fontsize=self.tickfs, color=MUTED,
                                 rotation=270, labelpad=14)
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
                if title:
                    p.ax.set_title(title, loc="left", fontsize=self.tickfs + 1,
                                   fontweight="bold", color="#374151",
                                   pad=24 if p.has_legend else 7)
            if is_by and not s.get("nolegend") and self.panels:
                p0 = self.panels[0]
                handles, texts = p0.legend_items(p0.series_labels(s.get("legend", {})))
                if len(handles) > 1:
                    self.fig_legend = (handles, texts, p0)
        self.layout()
        changed = False
        for p in self.panels:
            if not p.horizontal:
                changed = p.fix_tick_overlap() or changed
        if changed:
            self.layout()
        self.save()

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
        if ytitle and not subtitle:
            subtitle, ytitle = ytitle, ""
        H, W = self.ys * 72.0, self.xs * 72.0
        padx, pady = 14.0, 12.0
        ycur = H - pady
        left = padx / W
        if title:
            arts.append(fig.text(left, ycur / H, title, fontsize=14, fontweight="bold",
                                 color=INK, ha="left", va="top", linespacing=1.15))
            ycur -= 14 * 1.22 * (title.count("\n") + 1) + 3
        if subtitle:
            arts.append(fig.text(left, ycur / H, subtitle, fontsize=10.5, color=MUTED,
                                 ha="left", va="top", linespacing=1.2))
            ycur -= 10.5 * 1.3 * (subtitle.count("\n") + 1) + 2
        if ytitle:
            arts.append(fig.text(left, ycur / H, ytitle, fontsize=9.5, color=MUTED,
                                 ha="left", va="top"))
            ycur -= 9.5 * 1.35
        if self.fig_legend:
            handles, texts, p0 = self.fig_legend
            ycur -= 4
            leg = fig.legend(handles, texts, loc="upper left",
                             bbox_to_anchor=(left - 4 / W, ycur / H), ncol=min(len(handles), 5),
                             frameon=False, fontsize=9, handlelength=1.6, handletextpad=0.5,
                             columnspacing=1.4, borderaxespad=0.0, borderpad=0.1)
            p0.restyle_legend(leg)
            arts.append(leg)
            ycur -= 9 * 1.7
        ycur -= 8
        bottom = pady
        if note:
            arts.append(fig.text(left, pady / H, note, fontsize=8, color=MUTED, ha="left",
                                 va="bottom", linespacing=1.3))
            bottom += 8 * 1.35 * (note.count("\n") + 1) + 6
        if self.xtitle:
            xt = fig.text(0.5, bottom / H, self.xtitle, fontsize=9.5, color=MUTED,
                          ha="center", va="bottom")
            arts.append(xt)
            self._xtitle_artist = xt
            bottom += 9.5 * 1.3 + 5
        else:
            self._xtitle_artist = None

        L, B, R, T = padx / W, bottom / H, 1 - padx / W, ycur / H
        rows, cols = self.rows, self.cols
        tight = s.get("family") == "matrix"
        gapx = ((5.0 if tight else 16.0) / W) if cols > 1 else 0.0
        gapy = ((5.0 if tight else 14.0) / H) if rows > 1 else 0.0
        dl, dr = [0.0] * cols, [0.0] * cols
        dt_, db = [0.0] * rows, [0.0] * rows
        rects = {}
        for _ in range(4):
            w = ((R - L) - sum(dl) - sum(dr) - gapx * (cols - 1)) / cols
            h = ((T - B) - sum(dt_) - sum(db) - gapy * (rows - 1)) / rows
            if w < 0.08 or h < 0.08:
                w, h = max(w, 0.08), max(h, 0.08)
            for k, p in enumerate(self.panels):
                r_, c_ = divmod(k, cols)
                x0 = L + sum(dl[j] + w + dr[j] + gapx for j in range(c_)) + dl[c_]
                y1 = T - sum(dt_[j] + h + db[j] + gapy for j in range(r_)) - dt_[r_]
                rects[k] = [x0, y1 - h, w, h]
                p.set_position(rects[k])
            fig.canvas.draw()
            rr = fig.canvas.get_renderer()
            ndl, ndr = [0.0] * cols, [0.0] * cols
            ndt, ndb = [0.0] * rows, [0.0] * rows
            for k, p in enumerate(self.panels):
                r_, c_ = divmod(k, cols)
                bb = p.tightbbox(rr)
                x0, y0, w0, h0 = rects[k]
                ndl[c_] = max(ndl[c_], x0 - bb.x0)
                ndr[c_] = max(ndr[c_], bb.x1 - (x0 + w0))
                ndb[r_] = max(ndb[r_], y0 - bb.y0)
                ndt[r_] = max(ndt[r_], bb.y1 - (y0 + h0))
            dl, dr, dt_, db = ndl, ndr, ndt, ndb
        if self._xtitle_artist is not None and self.panels:
            xs = [rects[k][0] for k in rects] + [rects[k][0] + rects[k][2] for k in rects]
            self._xtitle_artist.set_x((min(xs) + max(xs)) / 2)

    def save(self):
        out = self.s.get("saving") or "gr2mpl.png"
        self.fig.savefig(out, dpi=self.dpi, facecolor="white")
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


def doctor(font):
    print(f"  python      : {sys.executable} ({sys.version.split()[0]})")
    print(f"  matplotlib  : {matplotlib.__version__}")
    print(f"  numpy       : {np.__version__}")
    want = font or FONT_FALLBACKS[0]
    got = pick_font(want)
    status = "found" if got == want else f"NOT found, will fall back to {got}"
    print(f"  font        : {want} ({status})")


def main(argv):
    if len(argv) >= 2 and argv[1] == "--doctor":
        doctor(" ".join(argv[2:]).strip().strip('"'))
        return
    # Stata's `python script, args()` passes quotes through and splits on spaces
    path = " ".join(argv[1:]).strip().strip('"')
    with open(path, encoding="utf-8") as fh:
        spec = json.load(fh, strict=False)
    if not spec.get("specdir"):
        spec["specdir"] = os.path.dirname(path)
    Figure(spec).render()


if __name__ == "__main__":
    main(sys.argv)
