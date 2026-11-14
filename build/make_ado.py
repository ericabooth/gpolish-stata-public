"""Assemble gpolish.ado from the template and the font-width tables."""
import json, os
here = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(here, "fontwidths.json")))
def vec(v):
    rows = [", ".join(f"{x:g}" for x in v[i:i+16]) for i in range(0, len(v), 16)]
    return "(" + ", \n            ".join(rows) + ")"
parts = []
for name, (r, b) in d.items():
    if r == b: b = [round(x * 1.06, 3) for x in r]
    parts.append(f'    if (font == "{name}") {{\n        if (bold) return({vec(b)})\n        return({vec(r)})\n    }}')
r, b = d["arial"]
parts.append(f'    if (bold) return({vec(b)})\n    return({vec(r)})')
known = " | ".join(f'font == "{k}"' for k in d)
t = open(os.path.join(here, "gpolish_template.ado")).read()
t = t.replace("@FONTTABLES@", "\n".join(parts)).replace("@FONTKNOWN@", known)
open(os.path.join(here, "..", "src", "gpolish.ado"), "w").write(t)
print("fonts:", ", ".join(d))
