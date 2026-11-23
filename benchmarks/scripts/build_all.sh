#!/usr/bin/env bash

set -e

cd "$(dirname "$0")/.."

mkdir -p bin

nvcc -O3 cuda/vector_add.cu -o bin/vector_add
nvcc -O3 cuda/matrix_multiply.cu -lcublas -o bin/matrix_multiply
nvcc -O3 cuda/memory_bandwidth.cu -o bin/memory_bandwidth
nvcc -O3 cudnn/convolution.cu -lcudnn -o bin/convolution
