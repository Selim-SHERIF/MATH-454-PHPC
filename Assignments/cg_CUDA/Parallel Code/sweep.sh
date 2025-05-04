#!/bin/bash
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --qos=math-454
#SBATCH --account=math-454
#SBATCH --output=sweep_%j.out
#SBATCH --error =sweep_%j.err

module purge
module load gcc/11.3.0
module load cuda/11.8.0
module load openblas/0.3.20

# Problem sizes
matrices=( lap2D_5pt_n100.mtx  )

# threadsPerBlock sweep starting at 1
threads=( 1 2 4 8 16 32 64 128 256 512 1024 )

# CSV header: include total time, iteration count, average time/iter
echo "matrix,threadsPerBlock,total_time_s,iterations,avg_time_s" > results.csv

for mat in "${matrices[@]}"; do
  for tpb in "${threads[@]}"; do
    echo "=== ${mat} @ ${tpb} threads/block ==="
    out=$(srun --quiet ./cgsolver "$mat" "$tpb")

    # Extract Total CG time (in seconds)
    total=$(echo "$out" \
            | awk -F: '/^Total CG time/ { gsub(/ s/,"",$2); print $2 }' \
            | tr -d ' ')

    # Extract number of iterations executed
    iters=$(echo "$out" \
            | awk -F: '/^Iterations executed/ { gsub(/ /,"",$2); print $2 }' \
            | tr -d ' ')

    # Extract average time per iteration
    avg=$(echo "$out" \
          | awk -F: '/^Average time\/iter/ { gsub(/ s/,"",$2); print $2 }' \
          | tr -d ' ')

    # Fallback: if avg is empty, compute from total & iters
    if [[ -z "$avg" && -n "$total" && -n "$iters" ]]; then
      avg=$(awk -v T="$total" -v I="$iters" 'BEGIN{printf "%.6f", T/I}')
    fi

    echo "${mat},${tpb},${total},${iters},${avg}" >> results.csv
  done
done

echo "Sweep complete. Results in results.csv"
