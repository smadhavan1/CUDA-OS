#include <cuda_runtime.h>
#include <cudnn.h>
#include <cstdio>
#include <vector>

#define CUDA_CHECK(call) do { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        printf("CUDA error: %s\n", cudaGetErrorString(err)); \
        return 1; \
    } \
} while (0)

#define CUDNN_CHECK(call) do { \
    cudnnStatus_t status = call; \
    if (status != CUDNN_STATUS_SUCCESS) { \
        printf("cuDNN error: %s\n", cudnnGetErrorString(status)); \
        return 1; \
    } \
} while (0)

int main()
{
    const int batch = 16;
    const int channels = 3;
    const int height = 224;
    const int width = 224;
    const int filters = 32;
    const int kernel = 3;
    const int outputHeight = height - kernel + 1;
    const int outputWidth = width - kernel + 1;

    size_t inputBytes =
        batch * channels * height * width * sizeof(float);

    size_t filterBytes =
        filters * channels * kernel * kernel * sizeof(float);

    size_t outputBytes =
        batch * filters * outputHeight * outputWidth * sizeof(float);

    float *input, *filter, *output;

    CUDA_CHECK(cudaMalloc(&input, inputBytes));
    CUDA_CHECK(cudaMalloc(&filter, filterBytes));
    CUDA_CHECK(cudaMalloc(&output, outputBytes));

    cudnnHandle_t handle;
    cudnnTensorDescriptor_t inputDesc, outputDesc;
    cudnnFilterDescriptor_t filterDesc;
    cudnnConvolutionDescriptor_t convDesc;

    CUDNN_CHECK(cudnnCreate(&handle));
    CUDNN_CHECK(cudnnCreateTensorDescriptor(&inputDesc));
    CUDNN_CHECK(cudnnCreateTensorDescriptor(&outputDesc));
    CUDNN_CHECK(cudnnCreateFilterDescriptor(&filterDesc));
    CUDNN_CHECK(cudnnCreateConvolutionDescriptor(&convDesc));

    CUDNN_CHECK(cudnnSetTensor4dDescriptor(
        inputDesc, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT,
        batch, channels, height, width
    ));

    CUDNN_CHECK(cudnnSetFilter4dDescriptor(
        filterDesc, CUDNN_DATA_FLOAT, CUDNN_TENSOR_NCHW,
        filters, channels, kernel, kernel
    ));

    CUDNN_CHECK(cudnnSetConvolution2dDescriptor(
        convDesc, 0, 0, 1, 1, 1, 1,
        CUDNN_CONVOLUTION, CUDNN_DATA_FLOAT
    ));

    CUDNN_CHECK(cudnnSetTensor4dDescriptor(
        outputDesc, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT,
        batch, filters, outputHeight, outputWidth
    ));

    cudnnConvolutionFwdAlgoPerf_t perfResults[1];
    int returnedAlgoCount = 0;

    CUDNN_CHECK(cudnnGetConvolutionForwardAlgorithm_v7(
        handle, inputDesc, filterDesc, convDesc,
        outputDesc, 1, &returnedAlgoCount, perfResults
    ));

    if (returnedAlgoCount < 1 ||
        perfResults[0].status != CUDNN_STATUS_SUCCESS) {
        fprintf(stderr, "cuDNN convolution algorithm selection failed.\n");
        return 1;
    }

    cudnnConvolutionFwdAlgo_t algorithm = perfResults[0].algo;

    size_t workspaceSize = 0;
    CUDNN_CHECK(cudnnGetConvolutionForwardWorkspaceSize(
        handle, inputDesc, filterDesc, convDesc,
        outputDesc, algorithm, &workspaceSize
    ));

    void *workspace = nullptr;

    if (workspaceSize > 0)
        CUDA_CHECK(cudaMalloc(&workspace, workspaceSize));

    const float alpha = 1.0f;
    const float beta = 0.0f;

    CUDNN_CHECK(cudnnConvolutionForward(
        handle, &alpha,
        inputDesc, input,
        filterDesc, filter,
        convDesc, algorithm,
        workspace, workspaceSize,
        &beta,
        outputDesc, output
    ));

    CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    CUDA_CHECK(cudaEventRecord(start));

    for (int i = 0; i < 20; i++) {
        CUDNN_CHECK(cudnnConvolutionForward(
            handle, &alpha,
            inputDesc, input,
            filterDesc, filter,
            convDesc, algorithm,
            workspace, workspaceSize,
            &beta,
            outputDesc, output
        ));
    }

    CUDA_CHECK(cudaEventRecord(stop));
    CUDA_CHECK(cudaEventSynchronize(stop));

    float milliseconds;
    CUDA_CHECK(cudaEventElapsedTime(&milliseconds, start, stop));

    printf("cuDNN convolution benchmark\n");
    printf("Input: %d x %d x %d x %d\n",
        batch, channels, height, width);
    printf("Filters: %d x %d x %d\n",
        filters, kernel, kernel);
    printf("Average time: %.4f ms\n", milliseconds / 20.0);

    if (workspace)
        cudaFree(workspace);

    cudaFree(input);
    cudaFree(filter);
    cudaFree(output);

    cudnnDestroyConvolutionDescriptor(convDesc);
    cudnnDestroyFilterDescriptor(filterDesc);
    cudnnDestroyTensorDescriptor(inputDesc);
    cudnnDestroyTensorDescriptor(outputDesc);
    cudnnDestroy(handle);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}
