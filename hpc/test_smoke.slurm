#!/bin/bash
#SBATCH --job-name=robust_pz_smoke
#SBATCH --array=1-4           # 4 scenarios for 18 species, replicate 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --partition=comp
#SBATCH --output=logs/smoke_%A_%a.out
#SBATCH --error=logs/smoke_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=${SLURM_EMAIL}

# Load user config
source ${SLURM_SUBMIT_DIR}/hpc/config.env

# Load conda environment and CPLEX module
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz
export LD_LIBRARY_PATH=/home/fcho0021/nh53/cplex2220/cplex/bin/x86-64_linux:/usr/local/gcc/5.4.0/lib64:$LD_LIBRARY_PATH
export PRIORITIZR_SOLVER=cplex

NUM_SPECIES=18
REPLICATE=1
SCENARIO=$SLURM_ARRAY_TASK_ID   # 1, 2, 3, 4

echo "Smoke test: num_species=$NUM_SPECIES replicate=$REPLICATE scenario=$SCENARIO"
echo "Start time: $(date)"

cd $SLURM_SUBMIT_DIR
Rscript hpc/run_one_species_count.R $NUM_SPECIES $REPLICATE $SCENARIO

echo "End time: $(date)"
