#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
RESULT_DIR="${1:-$HOME/cuda-minimal-results}"

mkdir -p "$RESULT_DIR"

"$SCRIPT_DIR/gpu_info.sh" > "$RESULT_DIR/gpu_info.txt" 2>&1

"$BENCHMARK_DIR/bin/vector_add" \
    > "$RESULT_DIR/vector_add.txt" 2>&1

"$BENCHMARK_DIR/bin/matrix_multiply" \
    > "$RESULT_DIR/matrix_multiply.txt" 2>&1

"$BENCHMARK_DIR/bin/memory_bandwidth" \
    > "$RESULT_DIR/memory_bandwidth.txt" 2>&1

"$BENCHMARK_DIR/bin/convolution" \
    > "$RESULT_DIR/convolution.txt" 2>&1

echo "Results saved to $RESULT_DIR"
