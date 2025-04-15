#include <algorithm>
#include <string>
#include <vector>
#include <mpi.h>
#ifndef __MATRIX_COO_H_
#define __MATRIX_COO_H_

class MatrixCOO {
public:
  MatrixCOO() = default;

  inline int m() const { return m_m; }
  inline int n() const { return m_n; }

  inline int nz() const { return irn.size(); }
  inline int is_sym() const { return m_is_sym; }

  void read(const std::string & filename);

  void mat_vec(const std::vector<double> & x, std::vector<double> & y) {
    std::fill_n(y.begin(), y.size(), 0.);

    for (size_t z = 0; z < irn.size(); ++z) {
      auto i = irn[z];
      auto j = jcn[z];
      auto a_ = a[z];

      y[i] += a_ * x[j];
      if (m_is_sym and (i != j)) {
        y[j] += a_ * x[i];
      }
    }
  }


  void mat_vec_parallel(const std::vector<double>& x, 
    std::vector<double>& y, 
    MPI_Comm comm) {
    int rank, nprocs;
    MPI_Comm_rank(comm, &rank);
    MPI_Comm_size(comm, &nprocs);

    // Create a local contribution vector and initialize it to zero.
    std::vector<double> y_local(y.size(), 0.0);

    // Determine the total number of nonzeros and partition them among processes.
    int total_nz = irn.size();
    int start = rank * total_nz / nprocs;
    int end   = (rank + 1) * total_nz / nprocs;

    // Loop over the local block of nonzeros.
    for (int idx = start; idx < end; ++idx) {
    int i = irn[idx];
    int j = jcn[idx];
    double a_val = a[idx];

    // Each process contributes to the global output vector.
    y_local[i] += a_val * x[j];
  if (m_is_sym && (i != j)) {
  y_local[j] += a_val * x[i];
  }
    }

    // Combine the contributions from all processes into the global output vector.
    MPI_Allreduce(y_local.data(), y.data(), y.size(), MPI_DOUBLE, MPI_SUM, comm);
}

  std::vector<int> irn;
  std::vector<int> jcn;
  std::vector<double> a;

private:
  int m_m{0};
  int m_n{0};
  bool m_is_sym{false};
};

#endif // __MATRIX_COO_H_
