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

  `gpolish_battery.do` ends with "checks passed" when everything works. `gr2mpl_tests.do` needs Python with matplotlib and numpy; set the environment variable `GR2MPL_PYTHON` to that Python, or install the packages into the Python Stata uses.
- If a change affects how labels are placed, rerun the benchmark in `benchmark/` (see `benchmark/README.md`) and report the before and after numbers in the pull request.
- Describe the change in `CHANGELOG.md`.

## Code of conduct

Please be respectful and constructive in issues and pull requests.

Maintainer: Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com)
