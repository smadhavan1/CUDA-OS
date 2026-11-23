#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>

#define CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        printf("CUDA error: %s\n", cudaGetErrorString(err)); \
        return 1; \
    } \
} while (0)

int main()
{
    const size_t bytes = 256 * 1024 * 1024;

    void *host;
    void *device;

    CHECK(cudaMallocHost(&host, bytes));
    CHECK(cudaMalloc(&device, bytes));

    cudaEvent_t start, stop;
    CHECK(cudaEventCreate(&start));
    CHECK(cudaEventCreate(&stop));

    CHECK(cudaEventRecord(start));

    for (int i = 0; i < 20; i++)
        CHECK(cudaMemcpy(device, host, bytes, cudaMemcpyHostToDevice));

    CHECK(cudaEventRecord(stop));
    CHECK(cudaEventSynchronize(stop));

    float milliseconds;
    CHECK(cudaEventElapsedTime(&milliseconds, start, stop));

    double totalBytes = 2.0 * bytes * 20;
    double bandwidth = totalBytes / (milliseconds / 1000.0) / 1e9;

    printf("Host-to-device bandwidth: %.2f GB/s\n", bandwidth);

    CHECK(cudaEventRecord(start));

    for (int i = 0; i < 20; i++)
        CHECK(cudaMemcpy(host, device, bytes, cudaMemcpyDeviceToHost));

    CHECK(cudaEventRecord(stop));
    CHECK(cudaEventSynchronize(stop));

    CHECK(cudaEventElapsedTime(&milliseconds, start, stop));

    bandwidth = totalBytes / (milliseconds / 1000.0) / 1e9;

    printf("Device-to-host bandwidth: %.2f GB/s\n", bandwidth);

    cudaFreeHost(host);
    cudaFree(device);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}
