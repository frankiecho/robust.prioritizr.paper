# Running the Speed Test on Monash M3 HPC

## Prerequisites

- Monash M3 account with access to the `comp` partition
- Gurobi academic license (see Step 2)

---

## Step 1: Transfer the repository to M3

On your local machine:

```bash
rsync -avz /path/to/robust_prioritizr_paper/ \
  your_username@m3.massive.org.au:/projects/your_username/robust_prioritizr_paper/
```

---

## Step 2: Set up the Gurobi license

1. SSH into M3: `ssh your_username@m3.massive.org.au`
2. Load Gurobi and run the license retrieval tool (your key is emailed from gurobi.com after registering for an academic license):
   ```bash
   module load gurobi/13.0.0
   grbgetkey YOUR_LICENSE_KEY
   ```
   By default this writes `~/gurobi.lic`. Move it to your project directory so compute nodes can read it:
   ```bash
   mv ~/gurobi.lic /projects/$USER/gurobi.lic
   ```
3. Confirm the path in `hpc/run_speed_test.slurm` and `hpc/test_setup.slurm` matches:
   ```
   export GRB_LICENSE_FILE=/projects/$USER/gurobi.lic
   ```

---

## Step 3: Install R packages on M3

Run this **once** interactively on a login node. Replace `YOUR_USERNAME` throughout.

```bash
module load r/4.4.1
module load gurobi/13.0.0

mkdir -p /projects/YOUR_USERNAME/Rlib

R --no-save << 'EOF'
.libPaths("/projects/YOUR_USERNAME/Rlib")

# Install from CRAN (robust.prioritizr is on CRAN, requires compilation)
install.packages(c(
  "robust.prioritizr",
  "prioritizr",
  "here", "terra", "sf",
  "dplyr", "tibble", "tidyr", "stringr",
  "ggplot2", "tidyterra", "patchwork",
  "purrr", "readr", "cli", "glue", "piggyback"
), repos = "https://cloud.r-project.org")
EOF
```

Add this to `~/.Rprofile` on M3 so every R session finds the library:

```r
.libPaths(c("/projects/YOUR_USERNAME/Rlib", .libPaths()))
```

> **Note:** `robust.prioritizr` requires compilation from source (NeedsCompilation: yes).
> If `install.packages` fails with a compiler error, check that the default C++ compiler
> is available: `module list` and look for a gcc/toolchain module.

---

## Step 4: Download and cache the data (login node only)

Compute nodes may have no internet access. Download once on the login node:

```bash
cd /projects/your_username/robust_prioritizr_paper
module load r/4.4.1
Rscript -e "source('data_prep.R'); rp_data_prep(18)"
```

This downloads all files into `data/`. All subsequent runs (including HPC jobs) will
use the cached files automatically.

---

## Step 5: Create the logs directory

```bash
cd /projects/your_username/robust_prioritizr_paper
mkdir -p logs output
```

---

## Step 6: Update email addresses in SLURM scripts

Edit `hpc/run_speed_test.slurm`, `hpc/run_aggregation.slurm`, and `hpc/test_setup.slurm`
and replace `YOUR_EMAIL@monash.edu` with your actual email.

---

## Step 7: Run the smoke test first

Before submitting the full 90-task array, verify that R, Gurobi, and the package all work:

```bash
cd /projects/your_username/robust_prioritizr_paper
sbatch hpc/test_setup.slurm
```

Check the log once it finishes:

```bash
cat logs/test_*.out
```

Expected output ends with solve times for 4 problems printed to stdout and
`output/vic_soln_18_rep1.rds` written to disk.

---

## Step 8: Submit the full speed test (9 species counts × 10 replicates = 90 jobs)

```bash
cd /projects/your_username/robust_prioritizr_paper
ARRAY_JOB=$(sbatch --parsable hpc/run_speed_test.slurm)
echo "Submitted array job: $ARRAY_JOB"
```

Monitor progress:

```bash
squeue -u $USER
```

---

## Step 9: Submit the aggregation job (runs after all array tasks succeed)

```bash
sbatch --dependency=afterok:$ARRAY_JOB hpc/run_aggregation.slurm
```

This reads all 90 RDS files, computes mean and SD solve times, and writes:
- `output/solve_times_raw.csv` — one row per species count × replicate × problem
- `output/solve_times_summary.csv` — mean and SD per species count × problem

---

## Step 10: Generate the LaTeX table (run locally or on login node)

After copying outputs back to your local machine:

```bash
rsync -avz your_username@m3.massive.org.au:/projects/your_username/robust_prioritizr_paper/output/ \
  /path/to/robust_prioritizr_paper/output/
```

Then run:

```bash
Rscript make_table.R
```

This prints the formatted table, saves `output/solve_times_table.csv`, and writes
`output/solve_times_table.tex` ready to paste into your paper.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `GRB_LICENSE_FILE` not found | Check path in SLURM scripts matches where `grbgetkey` wrote the file |
| Package not found | Ensure `~/.Rprofile` contains `.libPaths("/projects/YOUR_USERNAME/Rlib")` |
| Compilation failure during install | Load a gcc module before running `R`: `module load gcc` |
| Job killed (OOM) | Increase `--mem` in the SLURM script |
| Job times out | Increase `--time`; solutions at the 60-min limit are expected for large problems |
| `here()` returns wrong path | Ensure `.here` file exists at the project root |
| Compute node has no internet | Run data download on login node first (Step 4) |
