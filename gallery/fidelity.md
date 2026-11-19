# gr2mpl text placement compared with Stata

This page measures how far each text item in a `gr2mpl` image sits from the same item in Stata's own export, for all 22 gallery graphs. [fidelity.do](fidelity.do) exports each polished graph from Stata as SVG and keeps the `gr2mpl` spec; [fidelity.py](fidelity.py) redraws the spec, reads where matplotlib placed each line of text, and pairs it with the Stata line that has the same string. Distances are in points (1/72 inch) on the 7 by 4.6 inch graph, measured between the anchor points Stata's SVG uses: the left end, centre or right end of the baseline. Every item is listed in [fidelity.csv](fidelity.csv).

## Overall

Of 545 matched text items, half sit within 10.0 points of Stata's position and 90 percent within 20.9 points; the largest distance is 62.2 points. 4 items (1 percent) are within 2 points and 36 (7 percent) within 5 points. 3 items appear only in Stata's export and 0 only in the `gr2mpl` image.

## By kind of text

The two shift columns give the median signed offset of the `gr2mpl` item: positive across means further right than in Stata, positive down means lower on the page.

| Kind | Matched | Median (pt) | 90th pct (pt) | Max (pt) | Within 5 pt | Shift across (pt) | Shift down (pt) | Stata only | gr2mpl only |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Titles, subtitles, notes, captions and panel titles | 82 | 10.0 | 13.4 | 41.0 | 1 | 6.2 | 5.8 | 0 | 0 |
| Axis titles | 11 | 11.2 | 11.4 | 15.0 | 0 | -8.4 | -7.4 | 0 | 0 |
| Tick labels, including category-axis labels | 272 | 10.2 | 14.5 | 36.1 | 21 | -8.2 | 1.6 | 0 | 0 |
| Legend entries and legend titles | 19 | 25.9 | 50.2 | 62.2 | 1 | 4.4 | 7.1 | 3 | 0 |
| Gpolish annotations and other added text | 76 | 8.8 | 14.6 | 26.8 | 5 | -4.7 | 4.3 | 0 | 0 |
| Text not named in the spec, mostly marker labels | 85 | 14.0 | 29.9 | 38.4 | 8 | -8.2 | 1.8 | 0 | 0 |

## By graph

| Graph | Matched | Median (pt) | Max (pt) | Largest item | Stata only | gr2mpl only |
|---|---:|---:|---:|---|---:|---:|
| 01_avplot | 16 | 10.0 | 14.4 | tick label: 1,000 | 0 | 0 |
| 02_heatmap | 88 | 14.4 | 62.2 | legend: Below -0.6 | 0 | 0 |
| 03_coefplot | 25 | 11.0 | 21.2 | tick label: 21+ | 0 | 0 |
| 04_lines | 27 | 8.4 | 12.7 | tick label: 80 | 0 | 0 |
| 05_scatter | 33 | 9.6 | 34.4 | legend: Europe & Central Asia | 0 | 0 |
| 06_margins | 23 | 8.0 | 12.6 | tick label: 20 | 0 | 0 |
| 07_highlight | 16 | 8.5 | 12.8 | tick label: 80 | 0 | 0 |
| 08_overlays | 18 | 10.4 | 15.5 | tick label: 5,000 | 0 | 0 |
| 09_cibrace | 14 | 13.5 | 26.8 | annotation: interval | 0 | 0 |
| 10_flow | 18 | 10.2 | 15.4 | annotation: union status missing | 0 | 0 |
| 11_fitci | 19 | 9.5 | 34.4 | legend: Domestic | 0 | 0 |
| 12_timeseries | 15 | 8.5 | 13.3 | tick label: 1,400 | 0 | 0 |
| 13_coef | 13 | 11.6 | 12.0 | tick label: 4 | 0 | 0 |
| 14_histogram | 18 | 9.8 | 10.8 | tick label: 40 | 0 | 0 |
| 15_hbar | 19 | 9.6 | 21.8 | other: 0 | 0 | 0 |
| 16_box | 11 | 9.6 | 20.5 | tick label: White | 0 | 0 |
| 17_by | 26 | 7.7 | 17.6 | title: Manufacturing | 0 | 0 |
| 18_combine | 43 | 12.8 | 57.8 | legend: Domestic | 0 | 0 |
| 19_matrix | 32 | 11.0 | 16.9 | tick label: 15,000 | 0 | 0 |
| 20_dendrogram | 32 | 9.2 | 14.3 | tick label: 100 | 0 | 0 |
| 21_statplot | 17 | 8.5 | 15.8 | tick label: College grad | 0 | 0 |
| 22_heatplot | 22 | 10.1 | 30.3 | legend: 2.158 | 3 | 0 |

## Reading the numbers

A matched item is one whose string appears in both images. An item found in only one image is either text one program draws and the other does not, or a string the two programs write differently (for example a label that `gr2mpl` wraps onto two lines where Stata keeps one); the CSV lists each such item. Repeated strings, such as a 0 tick label on both axes, are paired so that the total distance within that string is as small as possible; where a whole block of repeated labels is shifted, as in the correlation heatmap, this can still pair a label with a neighbour's position. The distance measures position only: it does not compare font size or the width of the text, so two labels with the same anchor can still differ in length. Results depend on the fonts installed; these were measured with Open Sans in both programs.
