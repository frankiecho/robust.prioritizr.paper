#!/bin/bash
#SBATCH --job-name=robust_pz_agg
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --partition=comp
#SBATCH --output=logs/agg_%j.out
#SBATCH --error=logs/agg_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=YOUR_EMAIL@monash.edu

# Load conda environment
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz

# Gurobi license and shared library
export GRB_LICENSE_FILE=/home/fcho0021/nh53/gurobi.lic
export LD_LIBRARY_PATH=/home/fcho0021/nh53/gurobi1300/linux64/lib:$LD_LIBRARY_PATH

echo "Aggregating speed test results: $(date)"
cd $SLURM_SUBMIT_DIR
Rscript hpc/aggregate_results.R
echo "Done: $(date)"
