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

# Define function to catch infeasibility errors -----
try_solve <- function(p) {
  start_time <- Sys.time()
  soln <- NULL
  try(soln <- solve(p), silent = TRUE)
  end_time <- Sys.time()
  solve_time <- end_time - start_time
  if (!is.null(soln)) {
    soln <- terra::wrap(soln)
  }
  # NOTE: p is NOT saved here to avoid terra serialisation issues when
  # reading RDS files back across sessions. soln is terra::wrap()'d.
  res <- list(soln = soln, solve_time = solve_time)
  return(res)
}

# Build the list of 4 prioritizr problem objects ---------
build_problems <- function(
  optim_verbose = FALSE,
  tl            = 3600,
  num_threads   = 1
) {
  # Planning Scenario 1: Historic Baseline only
  pv1 <- problem(cost, species_hb) |>
    add_manual_targets(targets_hb) |>
    add_min_set_objective() |>
    add_locked_in_constraints(pa) |>
    add_default_solver(
      verbose     = optim_verbose,
      time_limit  = tl,
      threads     = num_threads
    )

  # Planning Scenario 2: Fully Robust
  rpv1 <- problem(cost, species_subset) |>
    add_manual_targets(targets) |>
    robust.prioritizr::add_constant_robust_constraints(groups = groups) |>
    add_robust_min_set_objective() |>
    add_locked_in_constraints(pa) |>
    add_default_solver(
      verbose     = optim_verbose,
      time_limit  = tl,
      threads     = num_threads
    )

  # Planning Scenario 3: Chance Constraints
  rpv2 <- problem(cost, species_subset) |>
    add_manual_targets(targets) |>
    robust.prioritizr::add_constant_robust_constraints(
      groups      = groups,
      conf_level  = conf_level
    ) |>
    add_locked_in_constraints(pa) |>
    add_binary_decisions() |>
    robust.prioritizr::add_robust_min_set_objective(method = "chance") |>
    add_default_solver(
      verbose     = optim_verbose,
      time_limit  = tl,
      threads     = num_threads
    )

  # Planning Scenario 4: CVaR Constraints
  rpv3 <- problem(cost, species_subset) |>
    add_manual_targets(targets) |>
    robust.prioritizr::add_constant_robust_constraints(
      groups      = groups,
      conf_level  = conf_level
    ) |>
    add_locked_in_constraints(pa) |>
    add_binary_decisions() |>
    robust.prioritizr::add_robust_min_set_objective(method = "cvar") |>
    add_default_solver(
      verbose     = optim_verbose,
      time_limit  = tl,
      threads     = num_threads
    )

  list(pv1, rpv1, rpv2, rpv3)
}

# Solve a single scenario (for HPC parallelisation) --------
# Saves a self-contained per-scenario RDS with no terra references in the
# problem object. Output: vic_soln_{num_species}_rep{replicate}_scenario{scenario}.rds
solve_single_scenario <- function(
  num_species   = 50,
  replicate     = 1,
  scenario      = 1,    # 1-4
  optim_verbose = FALSE,
  tl            = 3600,
  num_threads   = 1
) {
  stopifnot(scenario %in% 1:4)
  set.seed(490129 + replicate - 1)

  rp_data_prep(num_species)

  prob_list <- build_problems(
    optim_verbose = optim_verbose,
    tl            = tl,
    num_threads   = num_threads
  )

  p      <- prob_list[[scenario]]
  result <- try_solve(p)

  # Add metadata
  result$num_species <- num_species
  result$replicate   <- replicate
  result$scenario    <- scenario

  output_dir <- here::here("output")
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  out_path <- file.path(
    output_dir,
    glue::glue("vic_soln_{num_species}_rep{replicate}_scenario{scenario}.rds")
  )
  readr::write_rds(result, out_path)
  cat(sprintf(
    "Saved: %s  |  solve_time: %.4f min\n",
    basename(out_path),
    as.numeric(result$solve_time, units = "mins")
  ))
  return(result)
}

# Solve all 4 scenarios sequentially (used by main.R) ------
# Min number of species for this study = list of "threatened_species"
# Max number of species for this study = 872
solve_planning_problem <- function(
  num_species   = 50,
  replicate     = 1,
  optim_verbose = FALSE,
  tl            = 3600,
  num_threads   = 1
) {
  set.seed(490129 + replicate - 1)

  rp_data_prep(num_species)

  prob_list <- build_problems(
    optim_verbose = optim_verbose,
    tl            = tl,
    num_threads   = num_threads
  )

  output_dir <- here::here("output")
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  output <- map(prob_list, try_solve)

  # Wrap terra objects before saving
  cost          <- terra::wrap(cost)
  species_hb    <- terra::wrap(species_hb)
  species_subset <- terra::wrap(species_subset)

  readr::write_rds(
    output,
    file.path(output_dir, glue::glue("vic_soln_{num_species}_rep{replicate}.rds"))
  )
  list2env(as.list(environment()), envir = .GlobalEnv)
  return(output)
}
