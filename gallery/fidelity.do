* Stata's SVG export and gr2mpl's spec folder for every gallery graph, for
* gallery/fidelity.py. Run from the repository root:
*     stata-mp -b do gallery/fidelity.do
*     python gallery/fidelity.py
* Files go to gallery/fidelity_work (not committed). No gallery image changes.
version 16
capture mkdir "gallery/fidelity_work"
global GALLERY_FIDELITY "`c(pwd)'/gallery/fidelity_work"
do gallery/gallery.do
global GALLERY_FIDELITY
