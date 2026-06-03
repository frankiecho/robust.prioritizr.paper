# Running the Speed Test on Monash M3 HPC

## Prerequisites

- Monash M3 account with access to the `comp` partition
- Gurobi WLS academic license file (see Step 2)

---

## Step 1: Transfer the repository to M3

On your local machine:

```bash
rsync -avz /Users/fcho0021/Documents/GitHub/robust_prioritizr_paper/ \
  fcho0021@m3.massive.org.au:/home/fcho0021/nh53/robust_prioritizr_paper/
```

---

## Step 2: Set up the Gurobi WLS license

1. Register at **portal.gurobi.com** using your Monash email (`@monash.edu`)
2. Go to **Licenses → Request → Academic WLS License**
3. Download the generated `gurobi.lic` file — it contains:
   ```
   WLSACCESSID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   WLSSECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   LICENSEID=xxxxxxx
   ```
4. Copy it to M3:
   ```bash
   scp ~/Downloads/gurobi.lic fcho0021@m3.massive.org.au:/home/fcho0021/nh53/gurobi.lic
   ```
5. Verify it is readable:
   ```bash
   cat /home/fcho0021/nh53/gurobi.lic
   ```

### Activating the license inside conda

The Gurobi R package reads the license via the `GRB_LICENSE_FILE` environment variable.
Set it before running any R code:

```bash
export GRB_LICENSE_FILE=/home/fcho0021/nh53/gurobi.lic
```

Make it permanent by adding to `~/.bashrc`:

```bash
echo 'export GRB_LICENSE_FILE=/home/fcho0021/nh53/gurobi.lic' >> ~/.bashrc
source ~/.bashrc
```

Test the license is working:

```bash
conda activate robust_pz
Rscript -e "
library(gurobi)
model <- list(obj=1, modelsense='min', A=matrix(1,1,1), sense='>', rhs=1, lb=0)
result <- gurobi(model)
cat('Status:', result$status, '\n')
if (result$status == 'OPTIMAL') cat('Gurobi license OK\n')
"
```

> **Note:** WLS licenses require outbound HTTPS to `license.gurobi.com`. If compute nodes
> are firewalled, contact merc-support@monash.edu to ask about a license proxy.

---

## Step 3: Set up the conda environment

**(a)** Load anaconda and create the environment with R and the full geospatial stack:

```bash
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh

conda create -n robust_pz -c conda-forge \
  r-base=4.4.1 \
  r-terra r-sf r-units \
  r-here r-dplyr r-tibble r-tidyr r-stringr \
  r-ggplot2 r-patchwork r-purrr r-readr \
  r-cli r-glue r-rcpparmadillo r-slam \
  gdal proj geos

conda activate robust_pz
```

**(b)** Install remaining R packages from CRAN inside the conda environment:

```bash
Rscript -e "install.packages(c(
  'prioritizr', 'tidyterra', 'piggyback', 'robust.prioritizr'
), repos = 'https://cloud.r-project.org')"
```

**(c)** Install the Gurobi R package from the downloaded Linux tarball:

```bash
# Download the Gurobi Linux tarball (if not already done)
cd /home/fcho0021/nh53/
wget https://packages.gurobi.com/13.0/gurobi13.0.0_linux64.tar.gz
tar -xzf gurobi13.0.0_linux64.tar.gz

# Install the R package
Rscript -e "install.packages(
  '/home/fcho0021/nh53/gurobi1300/linux64/R/gurobi_13.0-0_R_4.5.0.tar.gz',
  repos = NULL, type = 'source'
)"
```

**(d)** Verify all packages are installed:

```bash
Rscript -e "
pkgs <- c('gurobi','terra','sf','prioritizr','robust.prioritizr',
          'here','dplyr','ggplot2','tidyterra','patchwork','purrr','readr')
for (p in pkgs) {
  tryCatch(
    { library(p, character.only=TRUE); cat(p, ': OK\n') },
    error=\(e) cat(p, ': FAILED -', conditionMessage(e), '\n')
  )
}
"
```

**(e)** Add `module load anaconda/2024.02-1` to `~/.bashrc` so conda is always available:

```bash
echo 'source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh' >> ~/.bashrc
source ~/.bashrc
```

---

## Step 4: Download and cache the data (login node only)

Compute nodes may have no internet access. Download once on the login node:

```bash
cd /home/fcho0021/nh53/robust_prioritizr_paper
conda activate robust_pz
export GRB_LICENSE_FILE=/home/fcho0021/nh53/gurobi.lic
Rscript -e "source('data_prep.R'); rp_data_prep(18)"
```

This downloads all files into `data/`. All subsequent runs will use the cached files.

---

## Step 5: Create the logs directory

```bash
cd /home/fcho0021/nh53/robust_prioritizr_paper
mkdir -p logs output
```

---

## Step 6: Update email addresses in SLURM scripts

Edit `hpc/run_speed_test.slurm`, `hpc/run_aggregation.slurm`, and `hpc/test_setup.slurm`
and replace `YOUR_EMAIL@monash.edu` with your actual Monash email.

---

## Step 7: Run the smoke test first

```bash
cd /home/fcho0021/nh53/robust_prioritizr_paper
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
cd /home/fcho0021/nh53/robust_prioritizr_paper
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

This writes:
- `output/solve_times_raw.csv` — one row per species × replicate × problem
- `output/solve_times_summary.csv` — mean and SD per species × problem

---

## Step 10: Generate the LaTeX table (run locally or on login node)

Copy outputs back to your local machine:

```bash
rsync -avz fcho0021@m3.massive.org.au:/home/fcho0021/nh53/robust_prioritizr_paper/output/ \
  /Users/fcho0021/Documents/GitHub/robust_prioritizr_paper/output/
```

Then run:

```bash
Rscript make_table.R
```

This saves `output/solve_times_table.csv` and `output/solve_times_table.tex`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Gurobi license OK` not printed | Check `GRB_LICENSE_FILE` path; ensure WLS credentials are valid at portal.gurobi.com |
| WLS license fails on compute node | Compute node may be firewalled; contact merc-support@monash.edu |
| `conda activate` not found | Run `source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh` first |
| Package not found in R | Ensure `conda activate robust_pz` was run before `Rscript` |
| `libgurobi130.so` not found | Ensure the gurobi R package was installed while `conda activate robust_pz` was active |
| Job killed (OOM) | Increase `--mem` in the SLURM script |
| Job times out | Increase `--time`; hitting the 60-min limit is expected for large problems |
| `here()` returns wrong path | Ensure `.here` file exists at the project root |
| Compute node has no internet | Run data download on login node first (Step 4) |
