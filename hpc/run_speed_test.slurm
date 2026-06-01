#!/bin/bash
#SBATCH --job-name=robust_pz_speed
#SBATCH --array=1-90          # 9 species counts x 10 replicates
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --partition=comp
#SBATCH --output=logs/speed_%A_%a.out
#SBATCH --error=logs/speed_%A_%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=YOUR_EMAIL@monash.edu

# Load modules
module load r/4.4.1
module load gurobi/13.0.0

# Point to Gurobi license file
export GRB_LICENSE_FILE=/projects/$USER/gurobi.lic

# Map task ID (1-90) to species count and replicate
# Tasks 1-10  -> species 18,  replicates 1-10
# Tasks 11-20 -> species 30,  replicates 1-10
# ... etc.
NUM_SPECIES_VEC=(18 30 50 100 200 400 600 800 872)
SPECIES_IDX=$(( ($SLURM_ARRAY_TASK_ID - 1) / 10 ))
REPLICATE=$(( ($SLURM_ARRAY_TASK_ID - 1) % 10 + 1 ))
NUM_SPECIES=${NUM_SPECIES_VEC[$SPECIES_IDX]}

echo "Task $SLURM_ARRAY_TASK_ID: num_species=$NUM_SPECIES replicate=$REPLICATE"
echo "Start time: $(date)"

# Run from the project root
cd $SLURM_SUBMIT_DIR/..

Rscript hpc/run_one_species_count.R $NUM_SPECIES $REPLICATE

echo "End time: $(date)"
