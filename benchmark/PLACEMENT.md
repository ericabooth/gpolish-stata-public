# How `gpolish ptlabel` places labels

This is pseudocode for the placement search in `_gpl_place()` and its helpers in `build/gpolish_template.ado` (gpolish 0.7.0). It was checked line by line against that file. All lengths are in Stata's device units; `fs` is the label size and `rad` the marker radius, both converted from points to device units, and `off` is `offset()` (default 3 points).

## Settings

`P = _gpl_placeparms() = (9, 0.4, 0.05, 0.005, 0.4, 3)`:

| | Meaning | Value |
|---|---|---|
| P1 | rings searched for a leader spot | 9 |
| P2 | ring step, in label heights | 0.4 |
| P3 | base cost of a far spot, in label heights squared | 0.05 |
| P4 | extra far-spot cost per label height of distance | 0.005 |
| P5 | box height, in font sizes | 0.4 |
| P6 | box pad, in points at 8.6 points (scaled by fs/8.6) | 3 |

## Obstacles (`_gpl_obstacles`)

```
O = empty list of boxes (x0, y0, x1, y1)
for each drawn plot in the graph:
    scatter, connected, dot with a visible marker: one square of half-width rad_plot per point
    connected, line, rline, function: one square 4 pt wide every 4 pt along each segment (at most 400 per segment)
    bar, rbar: one box per bar (bar width, else 2 pt)
    area, rarea: strips at most 4 pt wide between neighbouring positions (at most 200 per interval)
    rcap, rspike, rcapsym: one box 3 pt wide per range
for each xline()/yline(): a box 2 pt wide around the line
for each text already added: a box as wide as its widest line and nlines * size * 1.3 tall,
    placed by its box alignment
```

## Label boxes

```
for each selected label i (in the order of the rows in the data):
    w[i] = textwidth(font, label[i]) * fs + 2 * P6 * fs/8.6     (per-font width table)
h = fs * P5 + 2 * P6 * fs/8.6                                    (one height for every label)
d = rad + off
```

## Candidate positions next to the point

Each row: side s, centre offset (dx, dy), text alignment, position penalty p, box alignment. The box centre is (px + dx + s*w/2, py + dy).

| k | Position | s | dx | dy | penalty p |
|---|---|---|---|---|---|
| 1 | east | +1 | d | 0 | 0 |
| 2 | west | -1 | -d | 0 | 0.15 |
| 3 | north | 0 | 0 | d + h/2 | 0.25 |
| 4 | south | 0 | 0 | -d - h/2 | 0.3 |
| 5 | north-east | +1 | 0.7d | 0.7d + h/3 | 0.4 |
| 6 | south-east | +1 | 0.7d | -(0.7d + h/3) | 0.4 |
| 7 | north-west | -1 | -0.7d | 0.7d + h/3 | 0.5 |
| 8 | south-west | -1 | -0.7d | -(0.7d + h/3) | 0.5 |

## Overlap cost (`_gpl_hard`)

```
hard(b) = 2 * max(0, sum of overlap areas of b with O  -  overlap of b with own)
        + 4 * sum of overlap areas of b with the current boxes B[j], j != i
              (in pass 1 only labels already placed, j < i, count)
        + 1000 * h * (length by which b passes the left or right plot edge)
        + 1000 * w * (length by which b passes the bottom or top plot edge)
own = square of half-width 1.01*rad around the label's own point (its own marker is not an obstacle)
```

## Search

```
B[i] = east box for every label (starting layout)
for pass = 1 to 4:
    for i = 1 to m:
        bc = infinity
        for k = 1 to 8:                                   adjacent spots
            b = box(k);  c = hard(b) + p_k * h^2
            if c < bc: keep b, bc = c, resid = hard(b), far = 0
        if leaders allowed and resid > 0.02 * w[i] * h:  ring search
            for q = 1 to P1:
                rr = d + q * P2 * h
                for a = 0, 22.5, ..., 337.5 degrees:      16 directions
                    centre = (px + cos(a)*(rr + w/2), py + sin(a)*(rr + h/2))
                    base = (P3 + P4 * rr/h) * h^2
                    skip if base >= bc
                    skip if hard(b) + base >= bc
                    seg = leader(point, b, r0 = 1.3*rad, gap = 0.12*h)
                    c = hard(b) + base + leadcost(seg)
                    if c < bc: keep b, bc = c, resid = hard(b), far = 1, keep seg
        B[i] = kept box;  L[i] = kept seg if far, else none
```

Later passes see every other label's box from the pass before or the current pass, so a label can move away from one placed after it.

## Leader line and its cost

```
leader: q = nearest point of box b to the point (px, py); from (px, py) toward q,
        start r0 out from the point and stop gap short of q
        (if |q - p| < r0 + gap + 1, the segment is the whole span p to q)
leadcost(seg) = 2    * h^2 * (other label boxes the segment touches)
              + 1.5  * h^2 * (other leaders it properly crosses)
              + 0.15 * h^2 * (obstacle boxes in O it touches)
```

## Output

```
overlap flag = resid > 0.35 * w * h   (counted in the "crowded" note)
far labels: drawn centred on their box with a leader line; others: at the adjacent anchor
the placed boxes are added to O, so later ptlabel calls avoid them
```
