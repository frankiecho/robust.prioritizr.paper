#!/bin/bash
#SBATCH --job-name=robust_pz_recombine
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --partition=comp
#SBATCH --output=logs/recombine_%j.out
#SBATCH --error=logs/recombine_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=${SLURM_EMAIL}

# Load user config
source ${SLURM_SUBMIT_DIR}/hpc/config.env

# Load conda environment
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz

echo "Recombining scenario outputs: $(date)"
cd $SLURM_SUBMIT_DIR
Rscript hpc/recombine_results.R
echo "Done: $(date)"
