library(here)
library(prioritizr)
library(robust.prioritizr)
library(terra)
library(dplyr)
library(tibble)
library(stringr)
library(ggplot2)
library(tidyr)
library(tidyterra)
library(patchwork)
library(gurobi)
library(purrr)
library(sf)
library(readr)

source(here::here("data_prep.R"))
source(here::here("analysis.R"))

problem_names <- c(
  "A. Non-robust: Assume historic baseline",
  "B. Fully Robust",
  "C. Partially Robust: Chance Constraints",
  "D. Partially Robust: Conditional Value-at-Risk Constraints"
)

# Computational speed test: run each species count and read back results
num_species_vec <- c(18, 30, 50, 100, 200, 400, 600, 800, 872)

# Plot and save solve times -------
output_dir <- here::here("output")
outputs <- map(
  num_species_vec,
  \(i) {
    x <- read_rds(file.path(output_dir, glue::glue("vic_soln_{i}.rds")))
    time <- map_dbl(x, \(e) as.numeric(e$solve_time, units = 'mins'))
    return(time)
  }
)

# Table of solve times ---------
names(outputs) <- num_species_vec
solve_times <- bind_rows(outputs, .id = "num_species")

# Fix: solve_times has species counts as columns and problems as rows after bind_rows.
# Transpose so rows = species counts, cols = problems, then label correctly.
solve_times_clean <- t(solve_times)
colnames(solve_times_clean) <- problem_names
rownames(solve_times_clean) <- num_species_vec
solve_times_clean <- rownames_to_column(
  as.data.frame(solve_times_clean),
  "Number of species"
)
write_csv(solve_times_clean, file.path(output_dir, "solve_times.csv"))
