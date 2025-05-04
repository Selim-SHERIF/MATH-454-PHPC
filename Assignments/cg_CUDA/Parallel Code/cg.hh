#ifndef __CG_HH__
#define __CG_HH__

#include "matrix.hh"
#include <cblas.h>
#include <string>
#include <vector>

/*
 *  void CGSolver::solve(std::vector<double>& x, int threadsPerBlock)
 *  void CGSolver::read_matrix(const std::string& filename)
 *  void Solver::init_source_term(double h)
 */

class Solver {
public:
  virtual void read_matrix(const std::string& filename) = 0;
  void         init_source_term(double h);

  /* User‑supplied tolerance for ‖r‖² stop criterion */
  void   tolerance(double tol) { m_tolerance = tol; }

  /* Matrix dimensions */
  int m() const { return m_m; }
  int n() const { return m_n; }

  /* Main linear‑solver entry point */
  virtual void solve(std::vector<double>& x,
                     int threadsPerBlock) = 0;

protected:
  int                m_m{0};
  int                m_n{0};
  std::vector<double> m_b;
  double             m_tolerance{1e-10};
};

class CGSolver : public Solver {
public:
  CGSolver() = default;

  void read_matrix(const std::string& filename) override;
  void solve(std::vector<double>& x,
             int threadsPerBlock)             override;

  /* ► expose how many CG iterations the last solve() performed */
  int  iters() const { return m_last_iters; }      // new getter

private:
  Matrix m_A;
  /* ► iteration counter updated inside solve() */
  int    m_last_iters{0};                          // new member
};

#endif /* __CG_HH__ */
