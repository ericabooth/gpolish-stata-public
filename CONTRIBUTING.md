# Contributing to gpolish

Thank you for using `gpolish` and `gr2mpl`. Bug reports, examples of graphs that do not come out right, and suggestions are all welcome.

## Reporting a problem

Open an issue at https://github.com/ericabooth/gpolish-stata-public/issues and include:

- the output of `which gpolish`, `which gr2mpl` and `about` (your Stata version and edition);
- a short do-file that draws the graph and runs the `gpolish` or `gr2mpl` command, using a Stata example dataset (`sysuse auto`, `sysuse lifeexp`, `webuse ...`) or a few lines of made-up data;
- what you expected and what you saw, ideally with the exported image (`graph export problem.png, width(1200) replace`);
- for `gr2mpl`, your Python version and the versions of matplotlib and numpy (`python -c "import matplotlib, numpy; print(matplotlib.__version__, numpy.__version__)"`).

## Asking for help

Questions about how to get a particular look are welcome as issues too. Please say which graph command you started from.

## Changing the code

- `src/gpolish.ado` is generated. Edit `build/gpolish_template.ado` and run `python build/make_ado.py` to rebuild it.
- Run the test battery on every Stata version you have (the package supports Stata 16 and later). Start Stata in the repository's top folder, because the tests load the commands from `src/`:

  ```stata
  do tests/gpolish_battery.do
  do tests/gr2mpl_tests.do
  ```

  Each script ends with a line giving the number of checks passed when everything works. `gr2mpl_tests.do` needs Python with matplotlib and numpy; set the environment variable `GR2MPL_PYTHON` to that Python, or install the packages into the Python Stata uses.
- Some test, gallery and benchmark scripts set `graph set window fontface` or `graph set svg fontface`. Stata saves these settings between sessions, so note your own values first (`graph set window`, `graph set svg`) if you want to put them back afterwards.
- `gallery/README.md` and `gallery/index.html` are generated from `gallery/gallery.do` by `python gallery/make_page.py`, run from the repository's top folder. Change `gallery.do` or `make_page.py`, not the two pages. `python gallery/make_page.py --check` reports whether the pages match what the script writes, and `python gallery/make_page.py --blocks <folder>` writes each example's code block to its own do-file, so every block can be run in a fresh Stata session. Any other argument stops the script with a usage message before it writes a file. `python gallery/make_sheets.py` rebuilds the three-panel images in `gallery/sheets/`.
- If a change affects how labels are placed, rerun the benchmark in `benchmark/` (see `benchmark/README.md`) and report the before and after numbers in the pull request.
- Describe the change in `CHANGELOG.md`.

## Code of conduct

Please be respectful and constructive in issues and pull requests.

Maintainer: Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com)
