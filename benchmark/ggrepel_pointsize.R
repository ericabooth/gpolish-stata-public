# How far ggrepel keeps one label from one point, for the point.size values the benchmark uses.
# ggrepel turns point.size into a repulsion radius with its own approximate rule (the size read as
# "lines", divided by 13 and scaled by the panel's aspect ratio), so this script measures the result:
# one point, one label in Open Sans 8.6 pt on a 7 x 4.6 inch figure, the label started on the point
# and nudged a tiny amount in six directions, and the gap between the point and the label's text box.
# point.size 1 is ggrepel's default (the "ggrepel" column); 2.117 is the benchmark's 6 pt marker in
# ggplot2 size units, 6 * 72.27 / 72 / .pt (the "ggrepel (informed)" column).
# Run from the benchmark folder:  Rscript ggrepel_pointsize.R
suppressPackageStartupMessages({ library(ggplot2); library(ggrepel); library(grid) })
PT <- 72.27/72
one <- function(ps, bp, ang) {
  d <- data.frame(x = c(0.5), y = c(0.5), label = "Mmmmmm")
  p <- ggplot(d, aes(x, y)) + geom_point(size = 6*PT/.pt) +
    geom_text_repel(aes(label = label), size = 8.6*PT/.pt, family = "Open Sans", seed = 1,
                    max.overlaps = Inf, point.size = ps, box.padding = bp, nudge_x = 0.0001*cos(ang), nudge_y = 0.0001*sin(ang)) +
    scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    theme_void() + theme(plot.margin = margin(10, 10, 35, 40, unit = "bigpts"))
  png(tempfile(), width = 7, height = 4.6, units = "in", res = 72); print(p); grid.force()
  vp <- grep("^panel", grid.ls(viewports = TRUE, grobs = FALSE, print = FALSE)$name, value = TRUE)[1]
  downViewport(vp)
  t <- grid.get("textrepelgrob", grep = TRUE, global = TRUE); if (!inherits(t, "grob")) t <- t[[1]]
  w <- convertWidth(grobWidth(t), "bigpts", TRUE); h <- convertHeight(grobHeight(t), "bigpts", TRUE)
  c0 <- deviceLoc(t$x, t$y, valueOnly = TRUE); pt <- deviceLoc(unit(0.5, "native"), unit(0.5, "native"), valueOnly = TRUE)
  upViewport(0); dev.off()
  cx <- c0$x*72; cy <- c0$y*72; px <- pt$x*72; py <- pt$y*72
  dx <- max(cx - w/2 - px, 0, px - cx - w/2); dy <- max(cy - h/2 - py, 0, py - cy - h/2)
  sqrt(dx^2 + dy^2)
}
for (ps in c(1, 6*PT/.pt)) for (bp in c(0, 0.25)) {
  g <- sapply(c(0, 1, 2, 3, 4, 5), function(a) one(ps, bp, a))
  cat(sprintf("point.size %.3f box.padding %.2f lines: gap from point to text box %s pt\n", ps, bp, paste(sprintf("%.2f", g), collapse=" ")))
}
