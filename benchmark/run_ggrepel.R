# Label-placement benchmark, ggrepel side (R, ggplot2).
# Each scenario is drawn with the plot region and axis scales of the Stata graph
# (out/stata/geometry_default_<set>.csv). Two versions are run:
#   ggrepel      geom_text_repel at its defaults, given only the labelled points (max.overlaps = Inf,
#                so it drops no labels)
#   ggrepel_inf  "ggrepel (informed)": the same call, but given every point, with an empty label for
#                each unlabelled point (so its labels also avoid those points), and point.size set to
#                the drawn marker size. Nothing else differs.
# Marker size in ggplot2 units: ggplot2 sizes are millimetres, and a size s is drawn at a font size of
# s * .pt points, where .pt = 72.27 / 25.4 (ggplot2 counts TeX points, 72.27 to the inch). A marker
# m big points (1/72 inch, the unit of Stata and matplotlib) across is m * 72.27 / 72 TeX points, so
# its ggplot2 size is m * 72.27 / 72 / .pt (2.117 for the benchmark's 6 pt markers). The same rule sets
# the label size and the size of the drawn points, and point.size takes geom_point()'s size units.
# ggplot2 draws its markers a little under m points across (shape 19 at that font size), but every
# method is scored against the same m-point marker.
# ggrepel places labels while drawing, so the label centres and the leader segments are read back
# from the drawn grid objects.
# Writes, per scenario set, out/<method>/results_<set>.csv (label centres and leader end points in
# points, y up) and timing_<set>.csv (seconds to place and draw the plot once, and ggrepel's iteration
# count in the drawn run and in the run whose positions were read back). A run limited to some scenarios keeps the rows of the others.
# Run from the benchmark folder after run_stata.do:  Rscript run_ggrepel.R [scenario ...]
# With no scenarios named, BENCH_SCENARIOS (if set) names them; BENCH_SETS and BENCH_METHODS limit the
# sets and the two versions.
suppressPackageStartupMessages({ library(ggplot2); library(ggrepel); library(grid) })
args <- commandArgs(trailingOnly = TRUE)
envlist <- function(v) { x <- strsplit(trimws(Sys.getenv(v)), "[[:space:]]+")[[1]]; x[nzchar(x)] }
if (!length(args)) args <- envlist("BENCH_SCENARIOS")
sets <- envlist("BENCH_SETS")
meths <- envlist("BENCH_METHODS")
SET_METHODS <- list(main = c("ggrepel", "ggrepel_inf"), perm = c("ggrepel", "ggrepel_inf"),
                    scale = c("ggrepel", "ggrepel_inf"), fontmark = c("ggrepel", "ggrepel_inf"))
files <- c(main = "data/manifest_real.csv", main = "data/manifest_synthetic.csv", perm = "data/manifest_perm.csv",
           scale = "data/manifest_scale.csv", fontmark = "data/manifest_fontmark.csv")
man <- do.call(rbind, lapply(seq_along(files), function(i) {
  if (!file.exists(files[i]) || (length(sets) && !(names(files)[i] %in% sets))) return(NULL)
  read.csv(files[i], colClasses = c(scenario = "character", set = "character", design = "character"))
}))
if (length(args)) man <- man[man$scenario %in% args, ]
geo <- do.call(rbind, lapply(Sys.glob("out/stata/geometry_default_*.csv"), read.csv))
PT <- 72.27 / 72                      # ggplot sizes are in TeX points; Stata and matplotlib use 1/72 in
cat("ggrepel", as.character(packageVersion("ggrepel")), "ggplot2", as.character(packageVersion("ggplot2")), "\n")

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
  labsize <- man$label_pt[i] * PT / .pt
  ptsize <- man$marker_pt[i] * PT / .pt
  W <- g$W; H <- g$H
  xl <- c((g$px0 - g$xA) / g$xB, (g$px1 - g$xA) / g$xB)
  yl <- c((g$py0 - g$yA) / g$yB, (g$py1 - g$yA) / g$yB)
  p <- ggplot(d, aes(x, y))
  if (man$fit[i] == 1) p <- p + annotate("segment", x = man$fx0[i], xend = man$fx1[i],
      y = man$fa[i] + man$fb[i] * man$fx0[i], yend = man$fa[i] + man$fb[i] * man$fx1[i], colour = "grey55")
  p <- p + geom_point(size = ptsize, colour = "#0B5D7A", alpha = 0.7)
  if (method == "ggrepel") {
    p <- p + geom_text_repel(data = d[d$lab == 1, ], aes(label = label), size = labsize, family = "Open Sans",
                             seed = 12345, max.overlaps = Inf, segment.colour = "grey60", segment.size = 0.25,
                             verbose = TRUE)
  } else {
    d$lab2 <- ifelse(d$lab == 1, d$label, "")
    p <- p + geom_text_repel(data = d, aes(label = lab2), size = labsize, family = "Open Sans",
                             point.size = ptsize, seed = 12345, max.overlaps = Inf,
                             segment.colour = "grey60", segment.size = 0.25, verbose = TRUE)
  }
  p <- p + scale_x_continuous(limits = xl, expand = c(0, 0)) + scale_y_continuous(limits = yl, expand = c(0, 0)) +
    theme_void() + theme(plot.margin = margin(H - g$py1, W - g$px1, g$py0, g$px0, unit = "bigpts"))
  keep <- man$set[i] == "main" && man$seed[i] <= 1
  f <- file.path("out", method, paste0(scen, if (keep) ".png" else ".tmp.png"))
  png(f, width = W / 72, height = H / 72, units = "in", res = if (keep) 200 else 72)
  # verbose = TRUE only makes ggrepel report its iterations and time as a message; it does not change
  # the placement. print() places and draws the labels (the timed step); grid.force() then runs the same
  # placement again, with the same seed, so the drawn grid objects can be read. Both runs are recorded:
  # when neither reaches ggrepel's 0.5 second limit they stop at the same iteration with the same result.
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
    res[[length(res) + 1]] <- data.frame(scenario = scen, label = t$label, cx = loc$x * 72, cy = loc$y * 72,
      hjust = t$hjust, vjust = t$vjust, lx0 = lead[1], ly0 = lead[2], lx1 = lead[3], ly1 = lead[4])
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
    merge_write(do.call(rbind, lapply(out, `[[`, "tim")), file.path("out", method, paste0("timing_", set, ".csv")), scens, ord)
    cat(method, set, length(rows), "scenarios\n")
  }
}
