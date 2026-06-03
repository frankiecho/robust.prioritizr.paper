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
#SBATCH --mail-user=${SLURM_EMAIL}

# Load user config
source ${SLURM_SUBMIT_DIR}/hpc/config.env

# Load conda environment and CPLEX module
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz
export LD_LIBRARY_PATH=/home/fcho0021/nh53/cplex2220/cplex/bin/x86-64_linux:/usr/local/gcc/5.4.0/lib64:$LD_LIBRARY_PATH
export PRIORITIZR_SOLVER=cplex

echo "=== Environment check ==="
echo "R version:"; Rscript --version
echo "CPLEX: $(which cplex 2>/dev/null || echo 'not found')"
echo "Rcplex installed: $(Rscript -e 'cat(requireNamespace(\"Rcplex\", quietly=TRUE))' 2>/dev/null)"
echo "Start time: $(date)"

cd $SLURM_SUBMIT_DIR
Rscript hpc/run_one_species_count.R 18 1 1

echo "=== Test complete: $(date) ==="
