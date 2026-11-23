#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <vector>

#define CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        printf("CUDA error: %s\n", cudaGetErrorString(err)); \
        return 1; \
    } \
} while (0)

__global__ void vectorAdd(const float *a, const float *b, float *c, int n)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n)
        c[i] = a[i] + b[i];
}

int main()
{
    const int n = 1 << 24;
    const size_t bytes = n * sizeof(float);

    std::vector<float> a(n, 1.0f);
    std::vector<float> b(n, 2.0f);
    std::vector<float> c(n);

    float *d_a, *d_b, *d_c;

    CHECK(cudaMalloc(&d_a, bytes));
    CHECK(cudaMalloc(&d_b, bytes));
    CHECK(cudaMalloc(&d_c, bytes));

    CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
    CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));

    int threads = 256;
    int blocks = (n + threads - 1) / threads;

    vectorAdd<<<blocks, threads>>>(d_a, d_b, d_c, n);
    CHECK(cudaGetLastError());
    CHECK(cudaDeviceSynchronize());

    cudaEvent_t start, stop;
    CHECK(cudaEventCreate(&start));
    CHECK(cudaEventCreate(&stop));

    CHECK(cudaEventRecord(start));

    for (int i = 0; i < 100; i++)
        vectorAdd<<<blocks, threads>>>(d_a, d_b, d_c, n);

    CHECK(cudaEventRecord(stop));
    CHECK(cudaEventSynchronize(stop));

    float milliseconds;
    CHECK(cudaEventElapsedTime(&milliseconds, start, stop));

    CHECK(cudaMemcpy(c.data(), d_c, bytes, cudaMemcpyDeviceToHost));

    for (int i = 0; i < n; i++) {
        if (c[i] != 3.0f) {
            printf("Validation failed at index %d\n", i);
            return 1;
        }
    }

    double seconds = milliseconds / 1000.0;
    double bandwidth = (3.0 * bytes * 100.0) / (seconds * 1e9);

    printf("Vector addition passed\n");
    printf("Elements: %d\n", n);
    printf("Average kernel time: %.4f ms\n", milliseconds / 100.0);
    printf("Effective bandwidth: %.2f GB/s\n", bandwidth);

    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}
