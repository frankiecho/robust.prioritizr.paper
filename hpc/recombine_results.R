library(here)
library(purrr)
library(readr)
library(glue)

# Recombine 4 per-scenario RDS files into one combined RDS per (num_species, replicate)
# Input:  output/vic_soln_{n}_rep{r}_scenario{s}.rds  (s = 1..4)
# Output: output/vic_soln_{n}_rep{r}.rds

num_species_vec <- c(18, 30, 50, 100, 200, 400, 600, 800, 872)
n_replicates    <- 10
n_scenarios     <- 4
output_dir      <- here::here("output")

n_missing <- 0
n_written <- 0

for (n in num_species_vec) {
  for (r in seq_len(n_replicates)) {

    # Check all 4 scenario files exist
    scenario_paths <- map_chr(1:n_scenarios, \(s)
      file.path(output_dir, glue("vic_soln_{n}_rep{r}_scenario{s}.rds"))
    )
    missing <- !file.exists(scenario_paths)
    if (any(missing)) {
      warning(glue(
        "Skipping n={n} rep={r}: missing scenario file(s): ",
        paste(which(missing), collapse = ", ")
      ))
      n_missing <- n_missing + sum(missing)
      next
    }

    # Read and combine into list of 4
    combined <- map(scenario_paths, read_rds)
    out_path <- file.path(output_dir, glue("vic_soln_{n}_rep{r}.rds"))
    write_rds(combined, out_path)
    cat(sprintf("Written: %s\n", basename(out_path)))
    n_written <- n_written + 1
  }
}

cat(sprintf(
  "\nDone. %d combined files written. %d scenario files missing.\n",
  n_written, n_missing
))
