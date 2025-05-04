/* ---------- main.cpp (excerpt) ----------------------------------- */
#include "cg.hh"
#include <chrono>
#include <iomanip>
#include <iostream>

using clk     = std::chrono::high_resolution_clock;
using second  = std::chrono::duration<double>;

int main(int argc, char** argv)
{
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0]
                  << " <matrix-market-file> [threadsPerBlock]\n";
        return 1;
    }

    /* ---------- read second argument (threads‑per‑block) ---------- */
    int threadsPerBlock = 256;                         // default
    if (argc >= 3) {
        threadsPerBlock = std::stoi(argv[2]);
        if (threadsPerBlock <= 0) {
            std::cerr << "threadsPerBlock must be positive\n";
            return 1;
        }
    }

    /* ---------- build problem ------------------------------------- */
    CGSolver solver;
    solver.read_matrix(argv[1]);

    int n = solver.n();
    int m = solver.m();
    double h = 1.0 / n;

    solver.init_source_term(h);

    std::vector<double> x_d(n, 0.0);

    /* ---------- header line --------------------------------------- */
    std::cout << "Matrix : " << argv[1]
              << " | Size : " << m << " × " << n
              << " | Threads/Block : " << threadsPerBlock
              << '\n';

    /* ---------- run CG & measure wall‑time ------------------------ */
    auto t_start = clk::now();
    solver.solve(x_d, threadsPerBlock);          // prints [STEP k] lines
    second elapsed = clk::now() - t_start;

    /* ---------- footer lines -------------------------------------- */
    int    iters         = solver.iters();       // stored by solve()
    double total_sec     = elapsed.count();
    double avg_sec_iter  = total_sec / iters;

    std::cout << std::fixed << std::setprecision(6)
              << "\nTotal CG time       : " << total_sec    << " s\n"
              << "Iterations executed : " << iters         << '\n'
              << "Average time/iter   : " << avg_sec_iter  << " s\n";

    return 0;
}
