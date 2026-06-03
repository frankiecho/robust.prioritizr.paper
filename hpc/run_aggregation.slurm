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
#SBATCH --mail-user=${SLURM_EMAIL}

# Load user config
source ${SLURM_SUBMIT_DIR}/hpc/config.env

# Load conda environment
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz

echo "Aggregating speed test results: $(date)"
cd $SLURM_SUBMIT_DIR
Rscript hpc/aggregate_results.R
echo "Done: $(date)"
