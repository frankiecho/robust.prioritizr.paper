# Robust Conservation Prioritization under Climate Uncertainty

Reproducible analysis code for the paper comparing robust and non-robust spatial conservation planning approaches across climate change scenarios in Victoria, Australia.

Four planning approaches are evaluated:

| Label | Approach |
|---|---|
| A | Non-robust: historic baseline only |
| B | Fully Robust |
| C | Partially Robust: Chance Constraints |
| D | Partially Robust: Conditional Value-at-Risk (CVaR) Constraints |

Species distribution data spans five climate scenarios (historic baseline, SSP1-2.6, SSP2-4.5, SSP3-7.0, SSP5-8.5) across multiple timesteps.

## Dependencies

- R ≥ 4.4
- [`prioritizr`](https://prioritizr.net)
- [`robust.prioritizr`](https://github.com/frankiecho/robust.prioritizr)
- [`terra`](https://rspatial.github.io/terra/), `sf`, `tidyterra`
- `dplyr`, `tidyr`, `ggplot2`, `patchwork`, `purrr`, `readr`, `stringr`, `cowplot`
- A MILP solver: **CPLEX** (used on HPC) or **Gurobi** (local)

Install R packages:

```r
install.packages(c(
  "prioritizr", "terra", "sf", "tidyterra", "dplyr", "tidyr",
  "ggplot2", "patchwork", "purrr", "readr", "stringr", "cowplot",
  "here", "tibble", "cli", "glue"
))
# robust.prioritizr from GitHub:
remotes::install_github("frankiecho/robust.prioritizr")
```

## Running the analysis locally

### 1. Prepare data

Downloads and caches species distribution rasters, cost layer, and protected area mask into `data/`:

```r
source("data_prep.R")
rp_data_prep(num_species = 50)
```

Data are fetched from a remote source on first run; subsequent runs use the local cache.

### 2. Run main analysis and generate figures/tables

```r
source("main.R")
```

Outputs written to:
- `plots/p1_map.png` — prioritization maps + area + cost panels (Figure 1)
- `plots/p2_rep.png` — species representation plot (Figure 2)
- `tables/tab_species_representation.tex` — per-species representation table
- `tables/tab_area.tex` — protected area size table
- `tables/tab_cost.tex` — cost metric table
- `tables/tab_solve_time_main.tex` — solver time table

### 3. Run solver speed test (optional, single replicate)

```r
source("speed_test.R")
```

## Running on HPC (Monash M3)

For the full speed-scaling experiment (9 species counts × 10 replicates = 90 jobs) see **[HPC_GUIDE.md](HPC_GUIDE.md)**, which covers:

- Environment setup (conda + CPLEX)
- Data download on the login node
- SLURM job submission for the array job and aggregation step
- Syncing outputs back locally

Key SLURM scripts in `hpc/`:

| Script | Purpose |
|---|---|
| `test_setup.slurm` | Smoke test (single solve) |
| `run_speed_test.slurm` | Full array job (90 tasks) |
| `run_aggregation.slurm` | Aggregate results after array completes |
| `run_recombine.slurm` | Recombine partial outputs |

After syncing outputs back, run `make_table.R` to generate the solver-scaling LaTeX table.

## Repository structure

```
├── data_prep.R            # Download/cache input data
├── analysis.R             # Build prioritizr problems and solve
├── main.R                 # Main results: figures and tables
├── speed_test.R           # Single-node speed test
├── run_one_species_count.R# HPC array task entrypoint
├── aggregate_results.R    # Aggregate HPC outputs to CSV
├── recombine_results.R    # Recombine partial RDS outputs
├── make_table.R           # Generate solver-scaling table
├── hpc/                   # SLURM scripts
├── data/                  # Cached input rasters (gitignored)
├── output/                # Solver outputs and CSVs (gitignored)
├── plots/                 # Generated figures (gitignored)
├── tables/                # Generated LaTeX tables (gitignored)
└── HPC_GUIDE.md           # Step-by-step HPC setup guide
```

## Solvers

The analysis supports three solver back-ends configured via the `solver` argument in `build_problems()`:

- `"default"` — auto-detects the best available solver (Gurobi preferred locally)
- `"gurobi"` — requires a Gurobi license (`gurobi` R package)
- `"cplex"` — requires IBM CPLEX (`cplexAPI` or `Rcplex`); used on Monash M3 HPC
