// cg_solver_cuda.cu - Fully CUDA-parallelized CG solver (naïve GPU version)
#include "cg.hh"
#include <cmath>
#include <iostream>
#include <algorithm>
#include <numeric>
#include <cuda_runtime.h>

const double NEARZERO = 1.0e-14;
const bool DEBUG = true;

// Kernel: matrix-vector multiply y = A * x (row-major)
__global__ void gpu_matvec(const double* A, const double* x, double* y, int rows, int cols) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < rows) {
        double sum = 0.0;
        for (int j = 0; j < cols; ++j)
            sum += A[i * cols + j] * x[j];
        y[i] = sum;
    }
}

// Kernel: AXPY (y += alpha * x)
__global__ void gpu_axpy(double* y, const double* x, double alpha, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n)
        y[i] += alpha * x[i];
}

// Kernel: vector copy dst = src
__global__ void gpu_copy(double* dst, const double* src, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n)
        dst[i] = src[i];
}

// Kernel: dot product partial sums, with dynamic shared memory
__global__ void gpu_dot_product(const double* a,
                                const double* b,
                                double*       result,
                                int           n)
{
    extern __shared__ double cache[];
    int tid = threadIdx.x;
    int i   = blockIdx.x * blockDim.x + tid;

    double temp = 0.0;
    if (i < n) temp = a[i] * b[i];
    cache[tid] = temp;
    __syncthreads();

    for (int stride = blockDim.x/2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            cache[tid] += cache[tid + stride];
        }
        __syncthreads();
    }

    if (tid == 0) {
        result[blockIdx.x] = cache[0];
    }
}

void CGSolver::solve(std::vector<double>& x, int threadsPerBlock)
{
    int m = m_m;
    int n = m_n;

    const double* h_A = m_A.data();
    const double* h_b = m_b.data();

    double *d_A,*d_b,*d_x,*d_r,*d_p,*d_Ap,*d_tmp,*d_dotbuf;

    size_t size_mat = static_cast<size_t>(m)*n*sizeof(double);
    size_t size_vec = static_cast<size_t>(n)*sizeof(double);

    // 1) device alloc
    cudaMalloc(&d_A, size_mat);
    cudaMalloc(&d_b, size_vec);
    cudaMalloc(&d_x, size_vec);
    cudaMalloc(&d_r, size_vec);
    cudaMalloc(&d_p, size_vec);
    cudaMalloc(&d_Ap, size_vec);
    cudaMalloc(&d_tmp, size_vec);

    const int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;
    cudaMalloc(&d_dotbuf, blocksPerGrid * sizeof(double));

    // Copy host -> device
    cudaMemcpy(d_A, h_A, size_mat, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, size_vec, cudaMemcpyHostToDevice);
    cudaMemcpy(d_r, d_b, size_vec, cudaMemcpyDeviceToDevice);
    cudaMemcpy(d_p, d_r, size_vec, cudaMemcpyDeviceToDevice);
    cudaMemset(d_x, 0, size_vec);

    size_t shared_bytes = threadsPerBlock * sizeof(double);

    // rsold = r^T r
    cudaMemset(d_dotbuf, 0, blocksPerGrid * sizeof(double));
    gpu_dot_product<<<blocksPerGrid, threadsPerBlock, shared_bytes>>>(
        d_r, d_r, d_dotbuf, n);
    cudaDeviceSynchronize();
    std::vector<double> h_dot(blocksPerGrid);
    cudaMemcpy(h_dot.data(), d_dotbuf, blocksPerGrid * sizeof(double),
               cudaMemcpyDeviceToHost);
    double rsold = std::accumulate(h_dot.begin(), h_dot.end(), 0.0);

    // CG loop
    for (int k = 0; k < n; ++k) {
        // Ap = A * p
        gpu_matvec<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_p, d_Ap, m, n);
        cudaDeviceSynchronize();

        // dot = p^T Ap
        cudaMemset(d_dotbuf, 0, blocksPerGrid * sizeof(double));
        gpu_dot_product<<<blocksPerGrid, threadsPerBlock, shared_bytes>>>(
            d_p, d_Ap, d_dotbuf, n);
        cudaDeviceSynchronize();
        cudaMemcpy(h_dot.data(), d_dotbuf, blocksPerGrid * sizeof(double),
                   cudaMemcpyDeviceToHost);
        double dot_pAp = std::accumulate(h_dot.begin(), h_dot.end(), 0.0);

        double denom = std::max(dot_pAp, rsold * NEARZERO);
        double alpha = rsold / denom;

        gpu_axpy<<<blocksPerGrid, threadsPerBlock>>>(d_x, d_p, alpha, n);
        gpu_axpy<<<blocksPerGrid, threadsPerBlock>>>(d_r, d_Ap, -alpha, n);
        cudaDeviceSynchronize();

        // rsnew = r^T r
        cudaMemset(d_dotbuf, 0, blocksPerGrid * sizeof(double));
        gpu_dot_product<<<blocksPerGrid, threadsPerBlock, shared_bytes>>>(
            d_r, d_r, d_dotbuf, n);
        cudaDeviceSynchronize();
        cudaMemcpy(h_dot.data(), d_dotbuf, blocksPerGrid * sizeof(double),
                   cudaMemcpyDeviceToHost);
        double rsnew = std::accumulate(h_dot.begin(), h_dot.end(), 0.0);

        if (std::sqrt(rsnew) < m_tolerance) {
            if (DEBUG) std::cout << "\n";
            m_last_iters = k + 1;
            break;
        }

        double beta = rsnew / rsold;
        cudaMemcpy(d_tmp, d_r, size_vec, cudaMemcpyDeviceToDevice);
        gpu_axpy<<<blocksPerGrid, threadsPerBlock>>>(d_tmp, d_p, beta, n);
        cudaMemcpy(d_p, d_tmp, size_vec, cudaMemcpyDeviceToDevice);

        rsold = rsnew;
        m_last_iters = k + 1;

        if (DEBUG)
            std::cout << "\t[STEP " << k
                      << "] residual = " << std::scientific << std::sqrt(rsold)
                      << "\r" << std::flush;
    }

    if (DEBUG)
        std::cout << "[DONE] final residual = " << std::sqrt(rsold) << '\n';

    // cleanup
    cudaFree(d_A); cudaFree(d_b); cudaFree(d_x);
    cudaFree(d_r); cudaFree(d_p); cudaFree(d_Ap);
    cudaFree(d_tmp); cudaFree(d_dotbuf);
}


void CGSolver::read_matrix(const std::string & filename) {
    m_A.read(filename);
    m_m = m_A.m();
    m_n = m_A.n();
  }
  
  
  /*
  Initialization of the source term b
  */
  void Solver::init_source_term(double h) {
    m_b.resize(m_n);
  
    for (int i = 0; i < m_n; i++) {
      m_b[i] = -2. * i * M_PI * M_PI * std::sin(10. * M_PI * i * h) *
               std::sin(10. * M_PI * i * h);
    }
  }
  