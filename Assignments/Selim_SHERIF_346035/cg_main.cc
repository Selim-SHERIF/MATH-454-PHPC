#include "cg.hh"
#include <mpi.h>
#include <chrono>
#include <iostream>
#include <vector>
#include <algorithm>

using clk = std::chrono::high_resolution_clock;
using second = std::chrono::duration<double>;
using time_point = std::chrono::time_point<clk>;

int main(int argc, char **argv)
{
  // Initialize the MPI environment.
  MPI_Init(&argc, &argv);

  int rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);

  if (argc < 2)
  {
    if (rank == 0)
      std::cerr << "Usage: " << argv[0] << " [matrix-market-filename]" << std::endl;
    MPI_Finalize();
    return 1;
  }

  CGSolverSparse sparse_solver;
  sparse_solver.read_matrix(argv[1]);
  int n = sparse_solver.n();
  int m = sparse_solver.m();
  double h = 1.0 / n;

  sparse_solver.init_source_term(h);

  std::vector<double> x_s(n);
  std::fill(x_s.begin(), x_s.end(), 0.0);

  if (rank == 0)
    std::cout << "Call CG sparse on matrix size " << m << " x " << n << " using MPI...\n";

  // Synchronize all processes before timing
  MPI_Barrier(MPI_COMM_WORLD);
  double local_start = MPI_Wtime();

  sparse_solver.solve(x_s);

  double local_elapsed = MPI_Wtime() - local_start;

  // Collect the max time from all processes
  double max_elapsed;
  MPI_Reduce(&local_elapsed, &max_elapsed, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);

  if (rank == 0)
  {
    std::cout << "Time for CG (sparse solver)  = " << std::scientific << max_elapsed << " [s]\n";
  }

  // Finalize the MPI environment.
  MPI_Finalize();
  return 0;
}
