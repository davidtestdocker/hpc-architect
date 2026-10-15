// 二維熱擴散的 CPU 工作：由 Slurm 在兩台 CPU 運算節點執行同一份程式。
// 固定輸入為 1024×1024 格、200 次更新，與 heat2d.cu 的預設輸入相同。
// 程式只使用記憶體，輸出主機、總和與驗證結果；驗證失敗時回傳非零狀態。

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>

#include <unistd.h>

namespace {
constexpr int kSide = 1024;
constexpr int kSteps = 200;
constexpr double kExpectedSum = 65535.998004;
constexpr double kAllowedError = 0.1;
}

// 建立與 GPU 工作相同的中心方形熱源；cells 是待寫入的方格陣列。
void initialize(std::vector<float>& cells) {
    const int first = 3 * kSide / 8;
    const int last = 5 * kSide / 8;
    for (int y = first; y < last; ++y) {
        for (int x = first; x < last; ++x) {
            cells[static_cast<size_t>(y) * kSide + x] = 1.0f;
        }
    }
}

// 依上下左右四鄰點更新一輪；外圈保持零，結果寫入 output。
void cpu_step(const float* input, float* output) {
    for (int y = 1; y < kSide - 1; ++y) {
        for (int x = 1; x < kSide - 1; ++x) {
            const size_t at = static_cast<size_t>(y) * kSide + x;
            const float neighbors =
                input[at - 1] + input[at + 1] + input[at - kSide] + input[at + kSide];
            output[at] = input[at] + 0.2f * (neighbors - 4.0f * input[at]);
        }
    }
}

// 執行固定輸入並與模組 05 的 CPU 參考總和核對；成功回傳 0，否則回傳 1。
int main() {
    const size_t count = static_cast<size_t>(kSide) * kSide;
    std::vector<float> current(count, 0.0f);
    std::vector<float> next(count, 0.0f);
    initialize(current);

    const auto start = std::chrono::steady_clock::now();
    for (int step = 0; step < kSteps; ++step) {
        cpu_step(current.data(), next.data());
        std::swap(current, next);
    }
    const auto finish = std::chrono::steady_clock::now();

    double sum = 0.0;
    for (const float cell : current) {
        sum += cell;
    }
    const double error = std::abs(sum - kExpectedSum);
    const bool passed = std::isfinite(sum) && error <= kAllowedError;
    char host[256] = {};
    if (gethostname(host, sizeof(host) - 1) != 0) {
        std::perror("gethostname");
        return 1;
    }
    const double elapsed_ms =
        std::chrono::duration<double, std::milli>(finish - start).count();
    std::printf("host=%s grid=%dx%d steps=%d\n", host, kSide, kSide, kSteps);
    std::printf("sum=%.6f expected=%.6f abs_error=%.6f\n", sum, kExpectedSum, error);
    std::printf("cpu_ms=%.3f validation=%s\n", elapsed_ms, passed ? "PASS" : "FAIL");
    return passed ? 0 : 1;
}
