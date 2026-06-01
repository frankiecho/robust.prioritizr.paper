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

module load r/4.4.1

echo "Aggregating speed test results: $(date)"
cd $SLURM_SUBMIT_DIR/..
Rscript hpc/aggregate_results.R
echo "Done: $(date)"
