// 計算 1 到 N 的整數總和，作為 MPI 分工結果的單程序對照。
// 用法：sum_serial N；N 為 0 到 10000000 的十進位整數。
#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define MAX_N UINT64_C(10000000)

// 驗證十進位 N 的每個字元與範圍；有效時寫入 out 並回傳 1，否則回傳 0。
static int parse_n(const char *text, uint64_t *out) {
    if (text[0] == '\0') {
        return 0;
    }
    for (const char *p = text; *p != '\0'; ++p) {
        if (*p < '0' || *p > '9') {
            return 0;
        }
    }

    errno = 0;
    char *end = NULL;
    unsigned long long value = strtoull(text, &end, 10);
    if (errno == ERANGE || *end != '\0' || value > MAX_N) {
        return 0;
    }
    *out = (uint64_t)value;
    return 1;
}

// 接收一個 N，逐項加總 1 到 N 並印出結果；參數錯誤時回傳 2。
int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "用法: sum_serial N (0 <= N <= 10000000)\n");
        return 2;
    }

    uint64_t n = 0;
    if (!parse_n(argv[1], &n)) {
        fprintf(stderr, "N 必須是 0 到 10000000 的十進位整數\n");
        return 2;
    }

    uint64_t sum = 0;
    for (uint64_t i = 1; i <= n; ++i) {
        sum += i;
    }
    printf("n=%" PRIu64 "\nsum=%" PRIu64 "\n", n, sum);
    return 0;
}
