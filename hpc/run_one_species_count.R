library(here)

# Read arguments: num_species, replicate, scenario
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript run_one_species_count.R <num_species> <replicate> <scenario>")
}
num_species  <- as.integer(args[1])
replicate    <- as.integer(args[2])
scenario     <- as.integer(args[3])

# Threads from SLURM environment
num_threads  <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = "1"))

source(here::here("data_prep.R"))
source(here::here("analysis.R"))

cat(sprintf(
  "Solving: num_species=%d  replicate=%d  scenario=%d  threads=%d\n",
  num_species, replicate, scenario, num_threads
))

solve_single_scenario(
  num_species   = num_species,
  replicate     = replicate,
  scenario      = scenario,
  optim_verbose = TRUE,
  tl            = 16200,  # 4.5 hours — leaves 30 min overhead within 5h walltime
  num_threads   = num_threads
)
