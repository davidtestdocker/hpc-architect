// 二維熱擴散：在 GPU VM 編譯，由控制節點透過 Slurm 執行。
// 用法：heat2d [邊長] [迭代次數]，預設 1024 格、200 次；邊界固定為零。
// CPU 與 GPU 使用同一個中心熱源、相同更新式，逐格比較並輸出最大誤差。
// 程式只在記憶體運算，不讀寫資料檔；非零退出碼表示輸入、CUDA 或驗證失敗。

#include <cuda_runtime.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <utility>
#include <vector>

#include <unistd.h>

// CUDA 呼叫失敗時立即指出操作與錯誤；不讓缺少 GPU 的情況被當成計算通過。
void check_cuda(cudaError_t result, const char* operation) {
    if (result != cudaSuccess) {
        std::fprintf(stderr, "%s: %s\n", operation, cudaGetErrorString(result));
        std::exit(1);
    }
}

// 將命令列參數限制在可由此 VM 執行的整數範圍；無效輸入直接結束。
int parse_int(const char* value, int minimum, int maximum, const char* label) {
    char* end = nullptr;
    const long parsed = std::strtol(value, &end, 10);
    if (value[0] == '\0' || *end != '\0' || parsed < minimum || parsed > maximum) {
        std::fprintf(stderr, "%s 必須介於 %d 與 %d\n", label, minimum, maximum);
        std::exit(2);
    }
    return static_cast<int>(parsed);
}

// 建立中心方形熱源，其他格點維持零；同一份初始條件交給 CPU 與 GPU。
void initialize(std::vector<float>& cells, int side) {
    const int first = 3 * side / 8;
    const int last = 5 * side / 8;
    for (int y = first; y < last; ++y) {
        for (int x = first; x < last; ++x) {
            cells[static_cast<size_t>(y) * side + x] = 1.0f;
        }
    }
}

// CPU 參考解：每格按上下左右四鄰點更新，固定為零的外圈不改動。
void cpu_step(const float* input, float* output, int side) {
    for (int y = 1; y < side - 1; ++y) {
        for (int x = 1; x < side - 1; ++x) {
            const size_t at = static_cast<size_t>(y) * side + x;
            const float neighbors =
                input[at - 1] + input[at + 1] + input[at - side] + input[at + side];
            output[at] = input[at] + 0.2f * (neighbors - 4.0f * input[at]);
        }
    }
}

// __global__ 表示這個函式由 CPU 發起、在 GPU 上平行執行；每個 GPU thread 更新一格。
__global__ void gpu_step(const float* input, float* output, int side) {
    const int x = blockIdx.x * blockDim.x + threadIdx.x;
    const int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x <= 0 || y <= 0 || x >= side - 1 || y >= side - 1) {
        return;
    }
    const size_t at = static_cast<size_t>(y) * side + x;
    const float neighbors =
        input[at - 1] + input[at + 1] + input[at - side] + input[at + side];
    output[at] = input[at] + 0.2f * (neighbors - 4.0f * input[at]);
}

// 在同一輸入上跑 CPU 參考解與 GPU 計算，回報主機、裝置、時間及逐格誤差。
int main(int argc, char** argv) {
    if (argc > 3) {
        std::fprintf(stderr, "用法：%s [邊長 64..4096] [迭代 1..2000]\n", argv[0]);
        return 2;
    }
    const int side = argc >= 2 ? parse_int(argv[1], 64, 4096, "邊長") : 1024;
    const int steps = argc >= 3 ? parse_int(argv[2], 1, 2000, "迭代次數") : 200;
    const size_t count = static_cast<size_t>(side) * side;
    const size_t bytes = count * sizeof(float);

    std::vector<float> cpu_a(count, 0.0f);
    std::vector<float> cpu_b(count, 0.0f);
    std::vector<float> gpu_result(count, 0.0f);
    initialize(cpu_a, side);

    int device = -1;
    check_cuda(cudaGetDevice(&device), "cudaGetDevice");
    cudaDeviceProp properties{};
    check_cuda(cudaGetDeviceProperties(&properties, device), "cudaGetDeviceProperties");

    float* gpu_a = nullptr;
    float* gpu_b = nullptr;
    check_cuda(cudaMalloc(&gpu_a, bytes), "cudaMalloc gpu_a");
    check_cuda(cudaMalloc(&gpu_b, bytes), "cudaMalloc gpu_b");
    check_cuda(cudaMemcpy(gpu_a, cpu_a.data(), bytes, cudaMemcpyHostToDevice),
               "cudaMemcpy 初始格點");
    check_cuda(cudaMemset(gpu_b, 0, bytes), "cudaMemset 備用格點");

    const auto cpu_start = std::chrono::steady_clock::now();
    for (int step = 0; step < steps; ++step) {
        cpu_step(cpu_a.data(), cpu_b.data(), side);
        std::swap(cpu_a, cpu_b);
    }
    const auto cpu_end = std::chrono::steady_clock::now();

    cudaEvent_t gpu_start = nullptr;
    cudaEvent_t gpu_end = nullptr;
    check_cuda(cudaEventCreate(&gpu_start), "cudaEventCreate start");
    check_cuda(cudaEventCreate(&gpu_end), "cudaEventCreate end");
    const dim3 threads(16, 16);
    const dim3 blocks((side + 15) / 16, (side + 15) / 16);
    check_cuda(cudaEventRecord(gpu_start), "cudaEventRecord start");
    for (int step = 0; step < steps; ++step) {
        // <<<區塊數,每區塊執行緒數>>> 讓 GPU 同時處理多個格點；交換緩衝區供下一輪讀取。
        gpu_step<<<blocks, threads>>>(gpu_a, gpu_b, side);
        check_cuda(cudaGetLastError(), "gpu_step 啟動");
        std::swap(gpu_a, gpu_b);
    }
    check_cuda(cudaEventRecord(gpu_end), "cudaEventRecord end");
    check_cuda(cudaEventSynchronize(gpu_end), "cudaEventSynchronize end");
    float gpu_ms = 0.0f;
    check_cuda(cudaEventElapsedTime(&gpu_ms, gpu_start, gpu_end), "cudaEventElapsedTime");
    check_cuda(cudaMemcpy(gpu_result.data(), gpu_a, bytes, cudaMemcpyDeviceToHost),
               "cudaMemcpy GPU 結果");

    double cpu_sum = 0.0;
    double gpu_sum = 0.0;
    double max_error = 0.0;
    for (size_t i = 0; i < count; ++i) {
        cpu_sum += cpu_a[i];
        gpu_sum += gpu_result[i];
        max_error = std::max(max_error,
                             std::abs(static_cast<double>(cpu_a[i]) - gpu_result[i]));
    }

    char host[256] = {};
    if (gethostname(host, sizeof(host) - 1) != 0) {
        std::perror("gethostname");
        return 1;
    }
    const double cpu_ms =
        std::chrono::duration<double, std::milli>(cpu_end - cpu_start).count();
    const bool passed = max_error <= 1e-4;
    std::printf("host=%s device_index=%d device=%s grid=%dx%d steps=%d\n",
                host, device, properties.name, side, side, steps);
    std::printf("cpu_sum=%.6f gpu_sum=%.6f max_abs_error=%.8f\n",
                cpu_sum, gpu_sum, max_error);
    std::printf("cpu_ms=%.3f gpu_kernel_ms=%.3f validation=%s\n",
                cpu_ms, gpu_ms, passed ? "PASS" : "FAIL");

    check_cuda(cudaEventDestroy(gpu_start), "cudaEventDestroy start");
    check_cuda(cudaEventDestroy(gpu_end), "cudaEventDestroy end");
    check_cuda(cudaFree(gpu_a), "cudaFree gpu_a");
    check_cuda(cudaFree(gpu_b), "cudaFree gpu_b");
    return passed ? 0 : 1;
}
