# Label-placement benchmark, ggrepel side (R, ggplot2).
# Each scenario is drawn with the plot region and axis scales of the Stata graph
# (out/stata/geometry_default_<set>.csv). Two versions are run:
#   ggrepel      geom_text_repel at its defaults, given only the labelled points, except for
#                max.overlaps = Inf (so it drops no labels) and the time limit (below)
#   ggrepel_inf  "ggrepel (informed)": the same call, but given every point, with an empty label for
#                each unlabelled point (so its labels also avoid those points), and point.size set to
#                the drawn marker size. Nothing else differs.
# Stopping rule: ggrepel stops after max.iter iterations (default 10000), when its labels settle, or
# after max.time seconds (default 0.5), whichever comes first. A run stopped by the time limit depends
# on the machine's speed and load, so both calls set max.iter = 10000 (the default, written out) and
# max.time = Inf: every run then stops at 10,000 iterations or when the labels settle, and two runs give
# the same positions.
# Sizes: ggplot2 draws a text or point size s at a grid fontsize of s * .pt, where .pt = 72.27 / 25.4,
# and grid reads fontsize in big points (1/72 inch, the unit of Stata and matplotlib; at fontsize 72 one
# line is 72 bigpts). So a label of f points is size f / .pt (3.023 for 8.6 pt), and a marker m points
# across is given size m / .pt (2.109 for the benchmark's 6 pt markers), for the drawn points and for
# point.size, which takes geom_point()'s size units. ggplot2 draws its default marker (shape 19) at size
# 2.109 as a disc about 5.9 points across, a little under m, but every method is scored against the same
# m-point marker.
# ggrepel places labels while drawing, so the label centres and the leader segments are read back
# from the drawn grid objects.
# Writes, per scenario set, out/<method>/results_<set>.csv (label centres, text baselines and leader
# end points in points, y up) and timing_<set>.csv (seconds to place and draw the plot once, ggrepel's iteration
# count in the drawn run and in the run whose positions were read back, and why the latter stopped).
# A run limited to some scenarios keeps the rows of the others.
# Run from the benchmark folder after run_stata.do:  Rscript run_ggrepel.R [scenario ...]
# With no scenarios named, BENCH_SCENARIOS (if set) names them; BENCH_SETS and BENCH_METHODS limit the
# sets and the two versions. BENCH_PNG_DPI keeps every drawn image at that resolution (see audit_ink.py).
# Options for the further runs (see extra.py): BENCH_MAXITER sets max.iter (default 10000), BENCH_SEED
# the seed of both calls (default 12345), and BENCH_LINEPTS=1 gives informed ggrepel the fitted line as
# unlabelled points every 4 points along it, so its labels also avoid the line.
suppressPackageStartupMessages({ library(ggplot2); library(ggrepel); library(grid) })
args <- commandArgs(trailingOnly = TRUE)
envlist <- function(v) { x <- strsplit(trimws(Sys.getenv(v)), "[[:space:]]+")[[1]]; x[nzchar(x)] }
if (!length(args)) args <- envlist("BENCH_SCENARIOS")
sets <- envlist("BENCH_SETS")
meths <- envlist("BENCH_METHODS")
SET_METHODS <- list(main = c("ggrepel", "ggrepel_inf"), perm = c("ggrepel", "ggrepel_inf"),
                    scale = c("ggrepel", "ggrepel_inf"), fontmark = c("ggrepel", "ggrepel_inf"),
                    holdout = c("ggrepel", "ggrepel_inf"), rule = c("ggrepel", "ggrepel_inf"))
files <- c(main = "data/manifest_real.csv", main = "data/manifest_synthetic.csv", perm = "data/manifest_perm.csv",
           scale = "data/manifest_scale.csv", fontmark = "data/manifest_fontmark.csv",
           holdout = "data/manifest_holdout.csv", rule = "data/manifest_rule.csv")
man <- do.call(rbind, lapply(seq_along(files), function(i) {
  if (!file.exists(files[i]) || (length(sets) && !(names(files)[i] %in% sets))) return(NULL)
  read.csv(files[i], colClasses = c(scenario = "character", set = "character", design = "character"))
}))
if (length(args)) man <- man[man$scenario %in% args, ]
PNG_DPI <- Sys.getenv("BENCH_PNG_DPI")
geo <- do.call(rbind, lapply(Sys.glob("out/stata/geometry_default_*.csv"), read.csv))
MAX_ITER <- as.numeric(Sys.getenv("BENCH_MAXITER", "10000"))   # ggrepel's default unless BENCH_MAXITER is set
SEED <- as.integer(Sys.getenv("BENCH_SEED", "12345"))   # random seed for both ggrepel calls
MAX_TIME <- Inf                       # no time limit (the default 0.5 s makes results depend on the machine)
cat("ggrepel", as.character(packageVersion("ggrepel")), "ggplot2", as.character(packageVersion("ggplot2")),
    "max.iter =", MAX_ITER, "max.time =", MAX_TIME, "seed =", SEED, "\n")

# every scenario of a set in manifest order, whatever scenarios this run was limited to
set_order <- function(set) unlist(lapply(seq_along(files), function(i)
  if (names(files)[i] == set && file.exists(files[i])) read.csv(files[i], colClasses = c(scenario = "character"))$scenario))

merge_write <- function(df, path, scens, order) {
  if (file.exists(path)) {
    cc <- c(scenario = "character")
    if ("label" %in% names(df)) cc <- c(cc, label = "character")
    old <- read.csv(path, colClasses = cc, encoding = "UTF-8")
    old <- old[!(old$scenario %in% scens), , drop = FALSE]
    if (nrow(old)) df <- rbind(old, df[, names(old)])
  }
  df <- df[order(match(df$scenario, order)), , drop = FALSE]
  write.csv(df, path, row.names = FALSE, fileEncoding = "UTF-8")
}

run_one <- function(i, method) {
  scen <- man$scenario[i]
  g <- geo[geo$scenario == scen, ]
  d <- read.csv(file.path("data", paste0(scen, ".csv")), colClasses = c(label = "character"), encoding = "UTF-8")
  labsize <- man$label_pt[i] / .pt
  ptsize <- man$marker_pt[i] / .pt
  W <- g$W; H <- g$H
  xl <- c((g$px0 - g$xA) / g$xB, (g$px1 - g$xA) / g$xB)
  yl <- c((g$py0 - g$yA) / g$yB, (g$py1 - g$yA) / g$yB)
  p <- ggplot(d, aes(x, y))
  if (man$fit[i] == 1) p <- p + annotate("segment", x = man$fx0[i], xend = man$fx1[i],
      y = man$fa[i] + man$fb[i] * man$fx0[i], yend = man$fa[i] + man$fb[i] * man$fx1[i], colour = "grey55")
  p <- p + geom_point(size = ptsize, colour = "#0B5D7A", alpha = 0.7)
  if (method == "ggrepel") {
    p <- p + geom_text_repel(data = d[d$lab == 1, ], aes(label = label), size = labsize, family = "Open Sans",
                             seed = SEED, max.overlaps = Inf, max.iter = MAX_ITER, max.time = MAX_TIME,
                             segment.colour = "grey60", segment.size = 0.25,
                             verbose = TRUE)
  } else {
    d$lab2 <- ifelse(d$lab == 1, d$label, "")
    dr <- d
    if (man$fit[i] == 1 && nzchar(Sys.getenv("BENCH_LINEPTS"))) {
      # the fitted line, sampled every 4 pt (as gpolish samples lines), as unlabelled points to avoid
      X0 <- g$xA + g$xB * man$fx0[i]; X1 <- g$xA + g$xB * man$fx1[i]
      Y0 <- g$yA + g$yB * (man$fa[i] + man$fb[i] * man$fx0[i]); Y1 <- g$yA + g$yB * (man$fa[i] + man$fb[i] * man$fx1[i])
      k <- floor(sqrt((X1 - X0)^2 + (Y1 - Y0)^2) / 4) + 1
      xv <- man$fx0[i] + (man$fx1[i] - man$fx0[i]) * (0:k) / k
      dr <- rbind(d[, c("x", "y", "lab2")], data.frame(x = xv, y = man$fa[i] + man$fb[i] * xv, lab2 = ""))
    }
    p <- p + geom_text_repel(data = dr, aes(label = lab2), size = labsize, family = "Open Sans",
                             point.size = ptsize, seed = SEED, max.overlaps = Inf, max.iter = MAX_ITER,
                             max.time = MAX_TIME, segment.colour = "grey60", segment.size = 0.25, verbose = TRUE)
  }
  p <- p + scale_x_continuous(limits = xl, expand = c(0, 0)) + scale_y_continuous(limits = yl, expand = c(0, 0)) +
    theme_void() + theme(plot.margin = margin(H - g$py1, W - g$px1, g$py0, g$px0, unit = "bigpts"))
  # images are kept for the main set's real-data scenarios and seed 1 at 200 dpi, or for every
  # scenario run at BENCH_PNG_DPI when it is set (for audit_ink.py); the resolution does not change
  # the placement
  keep <- nzchar(PNG_DPI) || (man$set[i] == "main" && man$seed[i] <= 1)
  f <- file.path("out", method, paste0(scen, if (keep) ".png" else ".tmp.png"))
  png(f, width = W / 72, height = H / 72, units = "in",
      res = if (nzchar(PNG_DPI)) as.numeric(PNG_DPI) else if (keep) 200 else 72)
  # verbose = TRUE only makes ggrepel report its iterations and time as a message; it does not change
  # the placement. print() places and draws the labels (the timed step); grid.force() then runs the same
  # placement again, with the same seed, so the drawn grid objects can be read. Both runs are recorded,
  # and with no time limit they stop at the same iteration with the same result (checked below).
  msgs <- character(0)
  keepmsg <- function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") }
  t0 <- proc.time()[["elapsed"]]
  withCallingHandlers(print(p), message = keepmsg)
  secs <- proc.time()[["elapsed"]] - t0
  withCallingHandlers(grid.force(), message = keepmsg)
  # ggrepel reports one of three messages: "N iterations in Ts" when it stops at max.iter, "Ts elapsed
  # for N iterations" when it stops at max.time, and "text repel complete in N iterations" when the
  # labels settle first
  im <- grep("^ggrepel: .*[0-9]+ iterations", msgs, value = TRUE)
  it <- as.integer(sub(" iterations$", "", regmatches(im, regexpr("[0-9]+ iterations", im))))
  last <- im[length(im)]
  stop_read <- if (grepl("complete", last)) "settled" else if (grepl("max.time", last)) "time limit" else "iteration limit"
  if (length(it) != 2) stop(scen, ": expected two ggrepel iteration reports, got ", length(it))
  if (it[1] != it[2]) stop(scen, ": the drawn run and the read-back run stopped at different iterations")
  vp <- grep("^panel", grid.ls(viewports = TRUE, grobs = FALSE, print = FALSE)$name, value = TRUE)[1]
  downViewport(vp)
  tr <- grid.get("textrepeltree", grep = TRUE, global = TRUE)
  if (!inherits(tr, "gTree")) tr <- tr[[1]]
  kids <- tr$children
  res <- list()
  for (nm in names(kids)) {
    if (!grepl("^textrepelgrob", nm)) next
    t <- kids[[nm]]
    loc <- deviceLoc(t$x, t$y, valueOnly = TRUE)
    sg <- kids[[sub("^textrepelgrob", "segmentrepelgrob", nm)]]
    lead <- c(NA, NA, NA, NA)
    if (!is.null(sg)) {
      # grid.force() turns the curve into a segments grob (a straight segment at the default curvature 0)
      if (!is.null(sg$children)) sg <- sg$children[[1]]
      a <- deviceLoc(sg$x0, sg$y0, valueOnly = TRUE)
      b <- deviceLoc(sg$x1, sg$y1, valueOnly = TRUE)
      lead <- c(a$x, a$y, b$x, b$y) * 72
    }
    # grid places the text with vjust applied to the string height, which grid takes from the font's
    # ascent of "M" and which has no descent, so the baseline sits vjust * that height below the
    # anchor. score.py builds the label box from this baseline, the same rule as for the Stata labels.
    sh <- convertHeight(grobHeight(textGrob(t$label, gp = t$gp)), "bigpts", valueOnly = TRUE)
    res[[length(res) + 1]] <- data.frame(scenario = scen, label = t$label, cx = loc$x * 72, cy = loc$y * 72,
      hjust = t$hjust, vjust = t$vjust, by = loc$y * 72 - t$vjust * sh, lx0 = lead[1], ly0 = lead[2], lx1 = lead[3], ly1 = lead[4])
  }
  upViewport(0)
  dev.off()
  if (!keep) unlink(f)
  list(res = do.call(rbind, res), tim = data.frame(scenario = scen, seconds = secs, iterations = it[1], iterations_read = it[2],
                                    stop = stop_read))
}

for (set in unique(man$set)) {
  rows <- which(man$set == set)
  for (method in SET_METHODS[[set]]) {
    if (length(meths) && !(method %in% meths)) next
    dir.create(file.path("out", method), showWarnings = FALSE, recursive = TRUE)
    out <- lapply(rows, run_one, method = method)
    scens <- man$scenario[rows]
    ord <- set_order(set)
    merge_write(do.call(rbind, lapply(out, `[[`, "res")), file.path("out", method, paste0("results_", set, ".csv")), scens, ord)
    # a run with BENCH_PNG_DPI draws larger images, so its seconds are not kept
    if (!nzchar(PNG_DPI))
      merge_write(do.call(rbind, lapply(out, `[[`, "tim")), file.path("out", method, paste0("timing_", set, ".csv")), scens, ord)
    cat(method, set, length(rows), "scenarios\n")
  }
}
