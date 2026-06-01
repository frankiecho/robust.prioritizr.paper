#!/bin/bash
#SBATCH --job-name=robust_pz_test
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --partition=comp
#SBATCH --output=logs/test_%j.out
#SBATCH --error=logs/test_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=YOUR_EMAIL@monash.edu

module load r/4.4.1
module load gurobi/13.0.0
export GRB_LICENSE_FILE=/projects/$USER/gurobi.lic

echo "=== Environment check ==="
echo "R version:"; Rscript --version
echo "Gurobi license: $GRB_LICENSE_FILE"
echo "Start time: $(date)"

cd $SLURM_SUBMIT_DIR/..

# Run the smallest problem (18 species, replicate 1) as a smoke test
Rscript hpc/run_one_species_count.R 18 1

echo "=== Test complete: $(date) ==="
