#!/bin/bash
#SBATCH --job-name=robust_pz_speed
#SBATCH --array=121-200    # tasks 121-200: species 100/200, max observed 6.3GB
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=05:30:00
#SBATCH --partition=comp
#SBATCH --output=logs/speed_%A_%a.out
#SBATCH --error=logs/speed_%A_%a.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=${SLURM_EMAIL}

# Load user config (sets HPC_PROJECT_DIR, SLURM_EMAIL, etc.)
source ${SLURM_SUBMIT_DIR}/hpc/config.env

# Load conda environment and CPLEX module
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz
export LD_LIBRARY_PATH=/home/fcho0021/nh53/cplex2220/cplex/bin/x86-64_linux:/usr/local/gcc/5.4.0/lib64:$LD_LIBRARY_PATH
export PRIORITIZR_SOLVER=cplex

# Map task ID (1-360) to species count, replicate, scenario
# Layout: scenario varies fastest, then replicate, then species
#   Tasks   1-4:   species=18,  rep=1,  scenario=1-4
#   Tasks   5-8:   species=18,  rep=2,  scenario=1-4
#   Tasks  37-40:  species=18,  rep=10, scenario=1-4
#   Tasks  41-44:  species=30,  rep=1,  scenario=1-4
#   Tasks 357-360: species=872, rep=10, scenario=1-4
NUM_SPECIES_VEC=(18 30 50 100 200 400 600 800 872)
ZERO_IDX=$(( $SLURM_ARRAY_TASK_ID - 1 ))
SPECIES_IDX=$(( $ZERO_IDX / 40 ))
REPLICATE=$(( ($ZERO_IDX % 40) / 4 + 1 ))
SCENARIO=$(( $ZERO_IDX % 4 + 1 ))
NUM_SPECIES=${NUM_SPECIES_VEC[$SPECIES_IDX]}

echo "Task $SLURM_ARRAY_TASK_ID: num_species=$NUM_SPECIES replicate=$REPLICATE scenario=$SCENARIO"
echo "Start time: $(date)"

cd $SLURM_SUBMIT_DIR
Rscript hpc/run_one_species_count.R $NUM_SPECIES $REPLICATE $SCENARIO

echo "End time: $(date)"
