#!/bin/bash
set -e

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
  echo "Error: Do not run this script as root."
  exit 1
fi

# Set OpenBLAS to use 1 thread per MPI process
export OPENBLAS_NUM_THREADS=1

# Set default number of MPI processes (can override via ./run.sh 8)
NP=${1:-4}

# Set matrix file (can customize if needed)
MATRIX_FILE="lap2D_5pt_n300.mtx"

# Run the solver
echo "Running CG solver with $NP MPI processes on matrix $MATRIX_FILE..."
mpirun -np "$NP" ./cgsolver "$MATRIX_FILE"

echo "Run complete."
