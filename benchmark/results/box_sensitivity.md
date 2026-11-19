# Label-placement benchmark: gpolish scored with its search's box

Post hoc check; no setting was changed. gpolish's labels rescored with the measured text box
(scored), the search's core box (as wide as the text, 0.4 times the font size tall) and that core
box padded by 3 points on every side (padded). See box_sensitivity.py for the construction.
Main-set cells are the single graph in the original row order; perm cells give the median and
range over 10 row orders. The informed ggrepel and gpolish 0.6.0 columns keep their measured boxes.

## Clean labels (share)

| Scenario | Rows | gpolish, scored box | gpolish, core box | gpolish, padded box | gpolish 0.6.0 settings | ggrepel (informed) |
|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | original order | 1.00 | 1.00 | 1.00 | 0.92 | 0.75 |
| Life expectancy, 12 of 63 labelled | 10 orders | 1.00 (1.00 to 1.00) | 1.00 (1.00 to 1.00) | 1.00 (1.00 to 1.00) | 1.00 (0.92 to 1.00) | 0.88 (0.75 to 0.92) |
| Auto, 19 of 74 labelled | original order | 0.84 | 0.95 | 0.74 | 0.89 | 0.63 |
| Auto, 19 of 74 labelled | 10 orders | 0.84 (0.74 to 0.89) | 0.95 (0.95 to 1.00) | 0.63 (0.58 to 0.68) | 0.84 (0.74 to 0.89) | 0.74 (0.63 to 0.74) |
| Life expectancy, all 63 labelled | original order | 0.75 | 0.83 | 0.62 | 0.83 | 0.67 |
| Life expectancy, all 63 labelled | 10 orders | 0.79 (0.65 to 0.84) | 0.83 (0.75 to 0.86) | 0.67 (0.59 to 0.81) | 0.68 (0.59 to 0.76) | 0.64 (0.57 to 0.73) |
| Auto, all 74 labelled | original order | 0.59 | 0.73 | 0.32 | 0.51 | 0.58 |
| Auto, all 74 labelled | 10 orders | 0.54 (0.50 to 0.59) | 0.73 (0.66 to 0.78) | 0.36 (0.30 to 0.41) | 0.51 (0.42 to 0.62) | 0.57 (0.49 to 0.61) |

## Clean labels within 3 ems of their point (share)

| Scenario | Rows | gpolish, scored box | gpolish, core box | gpolish, padded box | gpolish 0.6.0 settings | ggrepel (informed) |
|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | original order | 1.00 | 1.00 | 1.00 | 0.92 | 0.75 |
| Life expectancy, 12 of 63 labelled | 10 orders | 1.00 (1.00 to 1.00) | 1.00 (1.00 to 1.00) | 1.00 (1.00 to 1.00) | 1.00 (0.92 to 1.00) | 0.88 (0.75 to 0.92) |
| Auto, 19 of 74 labelled | original order | 0.68 | 0.79 | 0.58 | 0.68 | 0.63 |
| Auto, 19 of 74 labelled | 10 orders | 0.71 (0.63 to 0.79) | 0.79 (0.79 to 0.84) | 0.53 (0.47 to 0.58) | 0.68 (0.58 to 0.74) | 0.74 (0.63 to 0.74) |
| Life expectancy, all 63 labelled | original order | 0.63 | 0.68 | 0.52 | 0.59 | 0.59 |
| Life expectancy, all 63 labelled | 10 orders | 0.66 (0.57 to 0.70) | 0.65 (0.59 to 0.70) | 0.60 (0.52 to 0.70) | 0.48 (0.41 to 0.49) | 0.56 (0.51 to 0.65) |
| Auto, all 74 labelled | original order | 0.35 | 0.43 | 0.27 | 0.22 | 0.34 |
| Auto, all 74 labelled | 10 orders | 0.39 (0.30 to 0.47) | 0.47 (0.42 to 0.54) | 0.25 (0.19 to 0.32) | 0.23 (0.18 to 0.31) | 0.35 (0.27 to 0.41) |

