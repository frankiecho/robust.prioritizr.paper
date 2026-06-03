library(here)
library(dplyr)
library(tidyr)
library(readr)

# Time limit used in all runs (minutes) — must match tl in run_one_species_count.R
tl_mins <- 300  # 18000 seconds = 5 hours

problem_names <- c(
  "A. Non-robust: Assume historic baseline",
  "B. Fully Robust",
  "C. Partially Robust: Chance Constraints",
  "D. Partially Robust: Conditional Value-at-Risk Constraints"
)

output_dir <- here::here("output")
summary_times <- read_csv(file.path(output_dir, "solve_times_summary.csv"), show_col_types = FALSE)

# Format a cell as "mean (SD)" or "60.00+" when the time limit was hit
fmt_cell <- function(mean_v, sd_v, tl = tl_mins) {
  if (is.na(mean_v)) return("--")
  if (mean_v >= tl - 0.5) return(sprintf("%.2f+", as.numeric(tl)))
  sprintf("%.2f (%.2f)", mean_v, sd_v)
}

wide <- summary_times |>
  mutate(cell = mapply(fmt_cell, mean_mins, sd_mins)) |>
  select(num_species, problem, cell) |>
  pivot_wider(names_from = problem, values_from = cell) |>
  arrange(as.numeric(num_species)) |>
  rename(`Number of species` = num_species)

cat("=== Formatted table (mean (SD) in minutes) ===\n")
print(wide, n = Inf)
write_csv(wide, file.path(output_dir, "solve_times_table.csv"))

# ---- LaTeX output ----
col_headers <- c("Number of species", problem_names)
col_widths  <- c("0.05", "0.2", "0.2", "0.2", "0.2")
col_spec    <- paste0(
  sapply(col_widths, \(w) sprintf("p{%s\\linewidth}", w)),
  collapse = ""
)

header_row <- paste(
  sapply(col_headers, \(h) sprintf("{%s}", h)),
  collapse = " & "
)

data_rows <- apply(wide, 1, \(row) {
  paste(row, collapse = " & ")
})
data_rows_tex <- paste(data_rows, "\\\\", collapse = "\n        ")

latex <- sprintf(
'\\begin{table}[h]
    \\centering
    \\caption{Solve times (minutes, mean (SD) over 10 replicates) under increasing problem sizes.
    Time limit is set to %d minutes; values marked with + hit the limit.}
    \\label{tab:solve_times}
    \\begin{tabular}{%s}
        \\toprule
        %s \\\\
        \\midrule
        %s
        \\bottomrule
    \\end{tabular}
\\end{table}',
  tl_mins,
  col_spec,
  header_row,
  data_rows_tex
)

cat("\n=== LaTeX table ===\n")
cat(latex, "\n")
writeLines(latex, file.path(output_dir, "solve_times_table.tex"))
cat("\nSaved solve_times_table.csv and solve_times_table.tex\n")
