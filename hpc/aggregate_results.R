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

scenario_map <- setNames(problem_names, 1:4)

num_species_vec <- c(18, 30, 50, 100, 200, 400, 600, 800, 872)
n_replicates    <- 10
n_scenarios     <- 4
output_dir      <- here::here("output")

# Unix timestamp written by the first SLURM task to start — used to exclude
# pre-existing RDS files from earlier runs (e.g. old Gurobi solves).
epoch_file <- here::here("output", "cplex_run_start_epoch.txt")
if (!file.exists(epoch_file)) {
  stop(
    "output/cplex_run_start_epoch.txt not found.\n",
    "This file is written automatically when the SLURM array jobs start.\n",
    "Run the speed test tiers first, then re-run aggregation."
  )
}
cplex_start_epoch <- as.integer(readLines(epoch_file, n = 1L))
cat(sprintf("Using run start epoch: %d (%s)\n", cplex_start_epoch,
            format(as.POSIXct(cplex_start_epoch, origin = "1970-01-01"), "%Y-%m-%d %H:%M:%S")))

read_scenario <- function(n, r, s) {
  path <- file.path(output_dir, glue("vic_soln_{n}_rep{r}_scenario{s}.rds"))

  # Must exist
  if (!file.exists(path)) {
    message(glue("Missing: vic_soln_{n}_rep{r}_scenario{s}.rds — skipping"))
    return(NULL)
  }

  # Must have been written after the CPLEX jobs started (exclude old Gurobi files)
  mtime <- as.integer(file.info(path)$mtime)
  if (mtime <= cplex_start_epoch) {
    message(glue("Skipping (pre-CPLEX timestamp): vic_soln_{n}_rep{r}_scenario{s}.rds"))
    return(NULL)
  }

  # Read and validate
  x <- tryCatch(read_rds(path), error = function(e) {
    message(glue("Failed to read vic_soln_{n}_rep{r}_scenario{s}.rds: {e$message}"))
    return(NULL)
  })
  if (is.null(x) || is.null(x$solve_time)) {
    message(glue("No solve_time in vic_soln_{n}_rep{r}_scenario{s}.rds — skipping"))
    return(NULL)
  }

  tibble(
    num_species = n,
    replicate   = r,
    scenario    = s,
    problem     = scenario_map[[as.character(s)]],
    time_mins   = as.numeric(x$solve_time, units = "mins")
  )
}

cat("Reading per-scenario CPLEX results...\n")
all_times <- map_dfr(num_species_vec, function(n) {
  map_dfr(seq_len(n_replicates), function(r) {
    map_dfr(seq_len(n_scenarios), function(s) {
      read_scenario(n, r, s)
    })
  })
})

cat(glue("\nLoaded {nrow(all_times)} completed CPLEX solves",
         " (out of {length(num_species_vec) * n_replicates * n_scenarios} expected)\n\n"))

# Print raw times
cat("=== Raw solve times (minutes) ===\n")
print(all_times, n = Inf)

# Summarise: mean and SD per species count x problem
summary_times <- all_times |>
  group_by(num_species, problem) |>
  summarise(
    mean_mins = mean(time_mins, na.rm = TRUE),
    sd_mins   = sd(time_mins, na.rm = TRUE),
    n         = n(),
    .groups = "drop"
  )

cat("\n=== Summary (mean ± SD minutes) ===\n")
print(summary_times, n = Inf)

# Save
write_csv(all_times,     file.path(output_dir, "solve_times_raw.csv"))
write_csv(summary_times, file.path(output_dir, "solve_times_summary.csv"))
cat("\nSaved solve_times_raw.csv and solve_times_summary.csv\n")
