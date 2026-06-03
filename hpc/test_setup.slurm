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

# Load conda environment
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz

# Gurobi license and shared library
export GRB_LICENSE_FILE=/home/fcho0021/nh53/gurobi.lic
export LD_LIBRARY_PATH=/home/fcho0021/nh53/gurobi1300/linux64/lib:$LD_LIBRARY_PATH

echo "=== Environment check ==="
echo "R version:"; Rscript --version
echo "Gurobi license: $GRB_LICENSE_FILE"
echo "Start time: $(date)"

cd $SLURM_SUBMIT_DIR

# Run the smallest problem (18 species, replicate 1) as a smoke test
Rscript hpc/run_one_species_count.R 18 1

echo "=== Test complete: $(date) ==="
