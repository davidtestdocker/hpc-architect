// 將 1 到 N 分配給多個 MPI rank，各自加總後合併，與序列版核對。
// 用法：以 MPI 啟動器執行 sum_mpi N；N 為 0 到 10000000 的十進位整數。
#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <mpi.h>

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

// 初始化 MPI，分配不重疊區段並合併總和；無效輸入時所有 rank 回傳 2。
int main(int argc, char *argv[]) {
    // 先建立 MPI 執行環境，後續才能讓這次啟動的多個程序互相通訊。
    MPI_Init(&argc, &argv);

    int rank = 0;
    int size = 0;
    // MPI_COMM_WORLD 是這次啟動的整組程序；rank 是自己的編號，size 是總數。
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    uint64_t n = 0;
    int valid = 1;
    if (rank == 0) {
        if (argc != 2) {
            fprintf(stderr, "用法: sum_mpi N (0 <= N <= 10000000)\n");
            valid = 0;
        } else if (!parse_n(argv[1], &n)) {
            fprintf(stderr, "N 必須是 0 到 10000000 的十進位整數\n");
            valid = 0;
        }
    }
    // Rank 0 把輸入是否有效通知全部程序，避免其他 rank 繼續等待後面的通訊。
    MPI_Bcast(&valid, 1, MPI_INT, 0, MPI_COMM_WORLD);
    if (!valid) {
        // 所有 rank 都結束 MPI 環境，再用相同的參數錯誤碼退出。
        MPI_Finalize();
        return 2;
    }
    // Rank 0 把 N 傳給全部程序；MPI_UINT64_T 對應 N 使用的 uint64_t 型別。
    MPI_Bcast(&n, 1, MPI_UINT64_T, 0, MPI_COMM_WORLD);

    // 前 n % size 個 rank 多分一個數字；first 與 count 對應連續、不重疊區段。
    const uint64_t base = n / (uint64_t)size;
    const uint64_t extra = n % (uint64_t)size;
    const uint64_t my_rank = (uint64_t)rank;
    const uint64_t count = base + (my_rank < extra ? 1 : 0);
    const uint64_t first = my_rank * base + (my_rank < extra ? my_rank : extra) + 1;

    uint64_t partial = 0;
    for (uint64_t offset = 0; offset < count; ++offset) {
        partial += first + offset;
    }

    char host[MPI_MAX_PROCESSOR_NAME];
    int host_length = 0;
    // 取得此 rank 所在位置的名稱，供輸出核對是否分布在不同節點。
    MPI_Get_processor_name(host, &host_length);
    printf("rank=%d size=%d host=%s first=%" PRIu64 " count=%" PRIu64
           " partial=%" PRIu64 "\n",
           rank, size, host, first, count, partial);
    fflush(stdout);

    uint64_t sum = 0;
    // MPI_SUM 把各 rank 的 partial 相加；MPI_Reduce 將結果交給 rank 0 的 sum。
    MPI_Reduce(&partial, &sum, 1, MPI_UINT64_T, MPI_SUM, 0, MPI_COMM_WORLD);
    if (rank == 0) {
        printf("n=%" PRIu64 "\nsum=%" PRIu64 "\n", n, sum);
    }

    // 所有 rank 完成通訊後關閉 MPI 環境。
    MPI_Finalize();
    return 0;
}
