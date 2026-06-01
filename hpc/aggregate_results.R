library(here)
library(dplyr)
library(tibble)
library(tidyr)
library(purrr)
library(readr)
library(glue)

problem_names <- c(
  "A. Non-robust: Assume historic baseline",
  "B. Fully Robust",
  "C. Partially Robust: Chance Constraints",
  "D. Partially Robust: Conditional Value-at-Risk Constraints"
)

num_species_vec <- c(18, 30, 50, 100, 200, 400, 600, 800, 872)
n_replicates    <- 10
output_dir      <- here::here("output")

# Read all replicate results into a long data frame
all_times <- map_dfr(num_species_vec, function(n) {
  map_dfr(seq_len(n_replicates), function(r) {
    path <- file.path(output_dir, glue("vic_soln_{n}_rep{r}.rds"))
    if (!file.exists(path)) {
      warning(glue("Missing: {path}"))
      return(tibble(
        num_species = n,
        replicate   = r,
        problem     = problem_names,
        time_mins   = NA_real_
      ))
    }
    x <- read_rds(path)
    tibble(
      num_species = n,
      replicate   = r,
      problem     = problem_names,
      time_mins   = map_dbl(x, \(e) as.numeric(e$solve_time, units = "mins"))
    )
  })
})

# Print raw times
cat("=== Raw solve times (minutes) ===\n")
print(all_times, n = Inf)

# Summarise: mean and SD per species count x problem
summary_times <- all_times |>
  group_by(num_species, problem) |>
  summarise(
    mean_mins = mean(time_mins, na.rm = TRUE),
    sd_mins   = sd(time_mins, na.rm = TRUE),
    n         = sum(!is.na(time_mins)),
    .groups = "drop"
  )

cat("\n=== Summary (mean ± SD minutes) ===\n")
print(summary_times, n = Inf)

# Save long-form summary
write_csv(all_times,      file.path(output_dir, "solve_times_raw.csv"))
write_csv(summary_times,  file.path(output_dir, "solve_times_summary.csv"))
cat("\nSaved solve_times_raw.csv and solve_times_summary.csv\n")
