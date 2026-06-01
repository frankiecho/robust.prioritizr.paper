library(here)

# Read arguments: num_species and replicate number
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript run_one_species_count.R <num_species> <replicate>")
num_species <- as.integer(args[1])
replicate   <- as.integer(args[2])

# Get number of threads from SLURM environment (matches --cpus-per-task)
num_threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "1"))

source(here::here("data_prep.R"))
source(here::here("analysis.R"))

cat(sprintf(
  "Solving for %d species, replicate %d, with %d threads\n",
  num_species, replicate, num_threads
))

output <- solve_planning_problem(
  num_species  = num_species,
  replicate    = replicate,
  optim_verbose = TRUE,
  tl           = 3600,   # 60-minute time limit per solve
  num_threads  = num_threads
)

# Print solve times to stdout for the log
problem_names <- c(
  "A. Non-robust",
  "B. Fully Robust",
  "C. Partially Robust: Chance Constraints",
  "D. Partially Robust: CVaR Constraints"
)
times <- sapply(output, \(x) as.numeric(x$solve_time, units = "mins"))
cat("\nSolve times (minutes):\n")
for (i in seq_along(times)) {
  cat(sprintf("  %s: %.4f min\n", problem_names[i], times[i]))
}
