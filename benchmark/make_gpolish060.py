"""Write out/gpolish060/gpolish.ado: this package's gpolish with release 0.6.0's placement settings.

The benchmark's "gpolish 0.6.0 settings" column runs the current gpolish code with one change:
_gpl_placeparms() returns the six values that release 0.6.0 (commit dce17c2) set by hand, where they
were constants written into _gpl_place() itself:
    rings 6           for (q=1; q<=6; q++)
    ring step 0.9     rr = d + q*0.9*h
    base cost 0.6     base = (0.6 + 0.08*rr/h)*h*h
    distance 0.08     (same line)
    box height 1.4    h = fs*1.4 + 2*0.6*fs/8.6
    box pad 0.6       (same line, and w = textw*fs + 2*0.6*fs/8.6)
Release 0.6.1 moved them into _gpl_placeparms() as (rings, step, base, distance, height, pad) and
set them to the tuned values (9, 0.4, 0.05, 0.005, 0.4, 3). Everything else (the font tables, the
obstacles, the leader check) is the current code, so the column shows the effect of the settings alone.
Run from the benchmark folder:  python make_gpolish060.py
"""
import os
import re

V060 = (6, 0.9, 0.6, 0.08, 1.4, 0.6)
TUNED = (9, 0.4, 0.05, 0.005, 0.4, 3)
PARM_RE = re.compile(r"(real rowvector _gpl_placeparms\(\)\n\{\n    return\(\()([^)]*)(\)\))")


def main():
    src = open("../src/gpolish.ado", encoding="utf-8").read()
    m = PARM_RE.search(src)
    assert m, "settings function _gpl_placeparms() not found in ../src/gpolish.ado"
    now = tuple(float(v) for v in m.group(2).split(","))
    assert now == tuple(float(v) for v in TUNED), f"src settings are {now}, not the tuned {TUNED}"
    new = src[:m.start(2)] + ", ".join(str(v) for v in V060) + src[m.end(2):]
    os.makedirs("out/gpolish060", exist_ok=True)
    with open("out/gpolish060/gpolish.ado", "w", encoding="utf-8") as fh:
        fh.write(new)
    print("out/gpolish060/gpolish.ado: _gpl_placeparms() =", V060)


if __name__ == "__main__":
    main()
