"""Build the gallery pages from gallery/gallery.do: gallery/index.html (GitHub Pages)
and gallery/README.md (rendered on GitHub). Run from the repository root."""
import re, html
INFO = {
 "01_lines": ("Multi-series lines", "Direct end labels with a value column replace the legend. The two notes are placed automatically."),
 "02_scatter": ("Labelled scatter on a log axis", "Point labels pick the least crowded of eight positions and avoid the fit line. Legend text takes the colour of its key."),
 "03_margins": ("marginsplot", "A graph built by another command. gpolish reads the drawn graph, so the same end labels work."),
 "04_highlight": ("One series highlighted", "Context series in gray, one in colour, and only that one labelled."),
 "05_fitci": ("Scatter with fit and confidence band", "Selected points labelled; the legend becomes a coloured key above the plot."),
 "06_timeseries": ("Daily time series", "A callout placed by the layout step at the series minimum."),
 "07_coef": ("Coefficient plot", "Built from twoway rcap and scatter. The scheme and the title edit do the work."),
 "08_histogram": ("Histogram", "A note with a curved arrow; text position given by hand here."),
 "09_hbar": ("Ranked horizontal bars", "graph hbar is not a twoway graph: the scheme and the bold title apply, the layout commands do not. gr2mpl redraws it."),
 "10_box": ("Box plot", "Same split as the bar chart: scheme and title inside Stata, full restyle from gr2mpl."),
 "11_by": ("Small multiples with by()", "The scheme removes the shaded panel strips. gr2mpl gives bold panel titles and shared axes."),
 "12_combine": ("Combined panels", "graph combine of four graphs, each styled by the scheme; gr2mpl redraws every panel."),
}
src = open("gallery/gallery.do").read()
blocks = re.split(r"\n\* -{20,} (\d\d) [^\n]*\n", src)
code = {}
for i in range(1, len(blocks), 2):
    body = blocks[i + 1]
    m = re.search(r"shotA (\S+)\n(.*?)\nshotBC \S+", body, re.S)
    if not m: continue
    c = m.group(2).replace("`SZ'", "xsize(7) ysize(4.6)").replace("`TS'", "size(13.5pt)").replace("`SS'", "size(10pt)")
    c = c.replace("`NS'", "size(8pt)").replace("`LS'", "labsize(9pt)")
    code[m.group(1)] = c.strip() + "\ngr2mpl, saving(figure.png) replace"
COLS = [("a", "Stata default"), ("b", "scheme(pypolish) + gpolish"), ("c", "+ gr2mpl (matplotlib render)")]
# ---- HTML page
css = """
:root{--bg:#f6f6f4;--card:#ffffff;--ink:#1a1a1a;--mute:#6b6b6b;--line:#e2e2de;--accent:#0b5d7a;--code:#f1f1ee}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#161718;--card:#202224;--ink:#ececec;--mute:#a0a0a0;--line:#34373a;--accent:#6fb1c7;--code:#1a1b1d}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 "Open Sans",system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
main{max-width:1500px;margin:0 auto;padding:32px 16px 64px}
h1{font-size:30px;margin:0 0 6px}h2{font-size:20px;margin:0 0 4px}
p.lead{color:var(--mute);max-width:70ch;margin:0 0 10px}a{color:var(--accent)}
nav{margin:18px 0 26px;display:flex;flex-wrap:wrap;gap:8px}
nav a{font-size:13px;text-decoration:none;border:1px solid var(--line);background:var(--card);padding:4px 10px;border-radius:14px}
section{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:18px;margin:0 0 22px}
section p{color:var(--mute);margin:0 0 14px;max-width:80ch}
.row{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
@media (max-width:900px){.row{grid-template-columns:1fr}}
figure{margin:0}figcaption{font-size:12.5px;font-weight:700;color:var(--mute);margin:0 0 5px;text-transform:uppercase;letter-spacing:.04em}
img{width:100%;height:auto;display:block;border:1px solid var(--line);border-radius:4px;background:#fff}
details{margin-top:12px}summary{cursor:pointer;color:var(--accent);font-size:14px}
pre{background:var(--code);border:1px solid var(--line);border-radius:6px;padding:12px;overflow-x:auto;font:12.5px/1.5 ui-monospace,Menlo,Consolas,monospace}
footer{color:var(--mute);font-size:13px;margin-top:30px}
"""
h = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
     "<title>gpolish gallery</title><style>" + css + "</style></head><body><main>",
     "<h1>gpolish gallery</h1>",
     '<p class="lead">Twelve Stata graphs, each drawn three ways: Stata\'s default look, the same graph with <code>scheme(pypolish)</code> and <code>gpolish</code> (still a Stata graph), and that graph redrawn in matplotlib by <code>gr2mpl</code>.</p>',
     '<p class="lead"><a href="https://github.com/ericabooth/gpolish-stata-public">Repository and installation</a> · every image on this page is produced by <a href="https://github.com/ericabooth/gpolish-stata-public/blob/main/gallery/gallery.do">gallery/gallery.do</a>.</p><nav>']
for k in sorted(code): h.append(f'<a href="#{k}">{html.escape(INFO[k][0])}</a>')
h.append("</nav>")
md = ["# gpolish gallery", "",
      "Twelve Stata graphs, each drawn three ways: Stata's default look, the same graph with `scheme(pypolish)` and `gpolish` (still a Stata graph), and that graph redrawn in matplotlib by `gr2mpl`.", "",
      "Every image is produced by [gallery.do](gallery.do). A browsable version is at <https://ericabooth.github.io/gpolish-stata-public/gallery/>.", ""]
for k in sorted(code):
    t, blurb = INFO[k]
    h.append(f'<section id="{k}"><h2>{html.escape(t)}</h2><p>{html.escape(blurb)}</p><div class="row">')
    for s, lab in COLS:
        h.append(f'<figure><figcaption>{html.escape(lab)}</figcaption><a href="img/{k}_{s}.png"><img loading="lazy" src="img/{k}_{s}.png" alt="{html.escape(t)}: {html.escape(lab)}"></a></figure>')
    h.append(f"</div><details><summary>Stata code for the polished versions</summary><pre>{html.escape(code[k])}</pre></details></section>")
    md += [f"## {t}", "", blurb, "", f"![{t}](sheets/{k}.png)", "", "<details><summary>Stata code for the polished versions</summary>", "", "```stata", code[k], "```", "", "</details>", ""]
h.append("<footer>gpolish, gr2mpl and the pypolish scheme are MIT licensed. Data: datasets shipped with Stata.</footer></main></body></html>")
open("gallery/index.html", "w").write("\n".join(h))
open("gallery/README.md", "w").write("\n".join(md))
print(len(code), "examples")
