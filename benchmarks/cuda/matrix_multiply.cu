#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cstdio>
#include <vector>

#define CUDA_CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        printf("CUDA error: %s\n", cudaGetErrorString(err)); \
        return 1; \
    } \
} while (0)

#define CUBLAS_CHECK(call) do { \
    cublasStatus_t status = call; \
    if (status != CUBLAS_STATUS_SUCCESS) { \
        printf("cuBLAS error: %d\n", status); \
        return 1; \
    } \
} while (0)

int main()
{
    const int n = 2048;
    const size_t bytes = n * n * sizeof(float);

    std::vector<float> a(n * n, 1.0f);
    std::vector<float> b(n * n, 2.0f);
    std::vector<float> c(n * n);

    float *d_a, *d_b, *d_c;

    CUDA_CHECK(cudaMalloc(&d_a, bytes));
    CUDA_CHECK(cudaMalloc(&d_b, bytes));
    CUDA_CHECK(cudaMalloc(&d_c, bytes));

    CUDA_CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));

    cublasHandle_t handle;
    CUBLAS_CHECK(cublasCreate(&handle));

    const float alpha = 1.0f;
    const float beta = 0.0f;

    cublasSgemm(
        handle,
        CUBLAS_OP_N,
        CUBLAS_OP_N,
        n, n, n,
        &alpha,
        d_b, n,
        d_a, n,
        &beta,
        d_c, n
    );

    CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    CUDA_CHECK(cudaEventRecord(start));

    for (int i = 0; i < 20; i++) {
        CUBLAS_CHECK(cublasSgemm(
            handle,
            CUBLAS_OP_N,
            CUBLAS_OP_N,
            n, n, n,
            &alpha,
            d_b, n,
            d_a, n,
            &beta,
            d_c, n
        ));
    }

    CUDA_CHECK(cudaEventRecord(stop));
    CUDA_CHECK(cudaEventSynchronize(stop));

    float milliseconds;
    CUDA_CHECK(cudaEventElapsedTime(&milliseconds, start, stop));

    CUDA_CHECK(cudaMemcpy(c.data(), d_c, bytes, cudaMemcpyDeviceToHost));

    if (c[0] != 2.0f * n) {
        printf("Validation failed\n");
        return 1;
    }

    double seconds = milliseconds / 1000.0 / 20.0;
    double operations = 2.0 * n * n * n;
    double gflops = operations / seconds / 1e9;

    printf("Matrix multiplication passed\n");
    printf("Matrix size: %d x %d\n", n, n);
    printf("Average time: %.4f ms\n", milliseconds / 20.0);
    printf("Performance: %.2f GFLOP/s\n", gflops);

    cublasDestroy(handle);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}
