#!/bin/bash
# Install Rcplex into the robust_pz conda environment against a locally-installed
# CPLEX Optimization Studio (same pattern as the Gurobi tarball install).
#
# Prerequisites:
#   1. Download IBM ILOG CPLEX Optimization Studio V22.2 for Linux x86-64 from
#      IBM Academic Initiative and transfer to M3:
#        scp IBM_ILOG_CPLEX_OptStdv22.2_LIN.bin your_username@m3.massive.org.au:/home/your_username/nh53/
#   2. Run this script from the project root on M3:
#        bash hpc/install_rcplex.sh

set -e

# Load user config if available
SCRIPT_DIR="$(dirname "$0")"
if [ -f "${SCRIPT_DIR}/config.env" ]; then
  source "${SCRIPT_DIR}/config.env"
fi

if [ -z "${HPC_SCRATCH_DIR}" ]; then
  echo "Error: HPC_SCRATCH_DIR not set. Please copy config.env.example to config.env and fill in details."
  exit 1
fi

CPLEX_INSTALLER=${HPC_SCRATCH_DIR}/IBM_ILOG_CPLEX_OptStdv22.2_LIN.bin
CPLEX_INSTALL_DIR=${HPC_SCRATCH_DIR}/cplex2220
CPLEX_INC=${CPLEX_INSTALL_DIR}/cplex/include
CPLEX_BIN=${CPLEX_INSTALL_DIR}/cplex/bin/x86-64_linux
# GCC 5.4.0 lib dir — needed because libcplex2220.so links against it
GCC_LIBDIR=/usr/local/gcc/5.4.0/lib64

echo "=== Loading conda env ==="
source /apps/anaconda/2024.02-1/etc/profile.d/conda.sh
conda activate robust_pz

# Step 1: Run the CPLEX installer silently to the local dir
if [ ! -d "${CPLEX_INC}/ilcplex" ]; then
  echo "=== Installing CPLEX to ${CPLEX_INSTALL_DIR} ==="
  chmod +x "${CPLEX_INSTALLER}"
  "${CPLEX_INSTALLER}" \
    -f /dev/null \
    -i silent \
    -DUSER_INSTALL_DIR="${CPLEX_INSTALL_DIR}" \
    -DLICENSE_ACCEPTED=TRUE
  echo "CPLEX installed."
else
  echo "CPLEX already installed at ${CPLEX_INSTALL_DIR}, skipping."
fi

# Create unversioned libcplex.so symlink so Rcplex's configure can find it
ln -sf ${CPLEX_BIN}/libcplex2220.so ${CPLEX_BIN}/libcplex.so

echo "=== Checking CPLEX files ==="
ls "${CPLEX_INC}/ilcplex/cplex.h" && echo "Header found."
ls "${CPLEX_BIN}/libcplex.so" && echo "libcplex.so found."

# Step 2: Download Rcplex source
echo "=== Downloading Rcplex source ==="
cd /tmp
wget -q https://cloud.r-project.org/src/contrib/Rcplex_0.3-8.tar.gz
tar xzf Rcplex_0.3-8.tar.gz

# Step 3: Patch configure to include transitive link deps.
# Rcplex's AC_CHECK_LIB only passes -lcplex; libcplex2220.so needs
# libstdc++ from GCC 5.4.0 and pthread/dl/m, which we append here.
sed -i "2099s|PKG_LIBS=\"\$CPLEX_LIB\"|PKG_LIBS=\"-L\$CPLEX_LIB -Wl,-rpath,\$CPLEX_LIB -lcplex -L${GCC_LIBDIR} -Wl,-rpath,${GCC_LIBDIR} -lpthread -ldl -lm\"|" /tmp/Rcplex/configure

echo "=== Installing Rcplex ==="
R CMD INSTALL /tmp/Rcplex \
  --configure-args="--with-cplex-include=${CPLEX_INC} --with-cplex-lib=${CPLEX_BIN}"

# Step 4: Install cplexAPI (what prioritizr actually uses)
echo "=== Installing cplexAPI ==="
Rscript -e "
  remotes::install_github('cran/cplexAPI',
    configure.args = paste0(
      '--with-cplex-include=${CPLEX_INC} ',
      '--with-cplex-lib=${CPLEX_BIN}'
    )
  )
"

# Step 5: Verify
echo "=== Verifying ==="
export LD_LIBRARY_PATH=${CPLEX_BIN}:${GCC_LIBDIR}:${LD_LIBRARY_PATH}
Rscript -e "
  library(cplexAPI)
  library(prioritizr)
  cat('cplexAPI:', as.character(packageVersion('cplexAPI')), '\n')
  cat('add_cplex_solver available:', exists('add_cplex_solver'), '\n')
"

echo "=== Done. cplexAPI and Rcplex are ready. ==="
