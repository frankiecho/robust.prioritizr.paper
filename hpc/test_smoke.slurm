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

# Load conda environment
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz

export GRB_LICENSE_FILE=${GRB_LICENSE_FILE}
export LD_LIBRARY_PATH=${GRB_LIB_PATH}:$LD_LIBRARY_PATH

NUM_SPECIES=18
REPLICATE=1
SCENARIO=$SLURM_ARRAY_TASK_ID   # 1, 2, 3, 4

echo "Smoke test: num_species=$NUM_SPECIES replicate=$REPLICATE scenario=$SCENARIO"
echo "Start time: $(date)"

cd $SLURM_SUBMIT_DIR
Rscript hpc/run_one_species_count.R $NUM_SPECIES $REPLICATE $SCENARIO

echo "End time: $(date)"
