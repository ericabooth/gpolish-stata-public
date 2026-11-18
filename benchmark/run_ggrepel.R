# Label-placement benchmark, ggrepel side (R, ggplot2).
# Each scenario is drawn with the plot region and axis scales of the Stata graph
# (out/stata/geometry.csv), with geom_text_repel at its defaults. ggrepel places labels
# while drawing, so the final centres are read back from the drawn grid objects.
# Writes out/ggrepel/results.csv (label centres in points, y up) and timing.csv.
# Run from the benchmark folder after run_stata.do:  Rscript run_ggrepel.R [scenario ...]
# With no scenarios named, the environment variable BENCH_SCENARIOS (if set) names them.
suppressPackageStartupMessages({ library(ggplot2); library(ggrepel); library(grid) })
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) args <- strsplit(trimws(Sys.getenv("BENCH_SCENARIOS")), "[[:space:]]+")[[1]]
args <- args[nzchar(args)]
dir.create("out/ggrepel", showWarnings = FALSE, recursive = TRUE)
man <- rbind(read.csv("data/manifest_synthetic.csv", colClasses = c(scenario = "character")),
             read.csv("data/manifest_real.csv", colClasses = c(scenario = "character")))
if (length(args)) man <- man[man$scenario %in% args, ]
geo <- read.csv("out/stata/geometry_default.csv")
PT <- 72.27 / 72                      # ggplot sizes are in TeX points; Stata and matplotlib use 1/72 in
labsize <- 8.6 * PT / .pt
ptsize <- 6.0 * PT / .pt
res <- list(); tim <- list()
for (i in seq_len(nrow(man))) {
  scen <- man$scenario[i]
  g <- geo[geo$scenario == scen, ]
  d <- read.csv(file.path("data", paste0(scen, ".csv")), colClasses = c(label = "character"), encoding = "UTF-8")
  W <- g$W; H <- g$H
  xl <- c((g$px0 - g$xA) / g$xB, (g$px1 - g$xA) / g$xB)
  yl <- c((g$py0 - g$yA) / g$yB, (g$py1 - g$yA) / g$yB)
  p <- ggplot(d, aes(x, y))
  if (man$fit[i] == 1) p <- p + annotate("segment", x = man$fx0[i], xend = man$fx1[i],
      y = man$fa[i] + man$fb[i] * man$fx0[i], yend = man$fa[i] + man$fb[i] * man$fx1[i], colour = "grey55")
  p <- p + geom_point(size = ptsize, colour = "#0B5D7A", alpha = 0.7) +
    geom_text_repel(data = d[d$lab == 1, ], aes(label = label), size = labsize, family = "Open Sans",
                    seed = 12345, max.overlaps = Inf, segment.colour = "grey60", segment.size = 0.25) +
    scale_x_continuous(limits = xl, expand = c(0, 0)) + scale_y_continuous(limits = yl, expand = c(0, 0)) +
    theme_void() + theme(plot.margin = margin(H - g$py1, W - g$px1, g$py0, g$px0, unit = "bigpts"))
  keep <- man$seed[i] <= 1
  f <- file.path("out/ggrepel", paste0(scen, if (keep) ".png" else ".tmp.png"))
  png(f, width = W / 72, height = H / 72, units = "in", res = if (keep) 200 else 72)
  t0 <- proc.time()[["elapsed"]]
  print(p)
  grid.force()
  secs <- proc.time()[["elapsed"]] - t0
  vp <- grep("^panel", grid.ls(viewports = TRUE, grobs = FALSE, print = FALSE)$name, value = TRUE)[1]
  downViewport(vp)
  tg <- grid.get("textrepelgrob", grep = TRUE, global = TRUE)
  if (inherits(tg, "grob")) tg <- list(tg)
  for (t in tg) {
    loc <- deviceLoc(t$x, t$y, valueOnly = TRUE)
    res[[length(res) + 1]] <- data.frame(scenario = scen, label = t$label,
      cx = loc$x * 72, cy = loc$y * 72, hjust = t$hjust, vjust = t$vjust)
  }
  upViewport(0)
  dev.off()
  if (!keep) unlink(f)
  tim[[length(tim) + 1]] <- data.frame(scenario = scen, seconds = secs)
}
write.csv(do.call(rbind, res), "out/ggrepel/results.csv", row.names = FALSE)
write.csv(do.call(rbind, tim), "out/ggrepel/timing.csv", row.names = FALSE)
cat(nrow(man), "scenarios\n")
