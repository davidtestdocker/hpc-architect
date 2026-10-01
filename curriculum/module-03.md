# 模組 03：C/C++ 系統程式與 MPI 工作

[能力路線](ROADMAP.md)｜職缺條件：C/C++ 與 Python；本模組交付可核對答案的編譯型工作。

## 目前成果

| 項目 | 已驗證的結果 |
|---|---|
| C++ 系統工具 | 讀取 `/proc/<PID>/status`，單節點 Slurm 工作 7 正常退出 |
| C 序列計算 | `N=0、1、10、11` 的總和符合已知答案 |
| 本機 MPI | 三個 rank 的分工與答案符合序列版；都在同一台 VM |
| Slurm 啟動 MPI | 工作 9 用兩個 rank 得 `sum=55`，`COMPLETED`、`ExitCode=0:0` |
| 尚未驗證 | 獨立節點間的 MPI、GPU 裝置工作與加速效果 |

**多個 rank 不等於跨節點。** 以下 MPI 輸出中的主機名都相同。
東京 GPU VM 雖已建立，尚未接入 Slurm；VM 狀態見[模組 04](module-04.md)。

## 先看懂編譯、Slurm 與 MPI

原始碼先由編譯器產生可執行檔，之後才能直接執行或交給 Slurm。
編譯成功只證明產生了程式，不證明答案正確。
Slurm 分配資源並啟動工作；MPI 讓工作中的多個程序交換資料、合併結果。

| 名稱 | 在本模組的意思 |
|---|---|
| rank | MPI 程序編號，不是 CPU 核心編號 |
| `ntasks` | 向 Slurm 請求的 task 數；本例一個 task 啟動一個 MPI rank |
| `cpus-per-task` | 每個 task 需要的 CPU 數，與 task 數不能互換 |
| `MPI_Bcast` | rank 0 把輸入與有效性傳給其他 rank |
| `MPI_Reduce` | 合併每個 rank 算出的部分總和 |
| `sbatch`／`srun` | 提交批次工作／在配置的資源中啟動程序 |

例如 `1` 到 `10` 的總和是 `55`。三個 rank 可分算
`1–4=10`、`5–7=18`、`8–10=27`，再合併為 `55`。
除了總和，還要看每個 rank 的起點、數量與主機名，
才能確認沒有漏算、重算，並辨認是否跨節點。

## 工具與檔案

| 工具 | 用途 | 本機已確認的條件 |
|---|---|
| `g++` | 編譯 C++ 系統工具 | `gcc-c++-14.3.1-4.4.el10.alma.2.x86_64` 已安裝 |
| `gcc` | 編譯 C 序列版 | 在目前 VM 使用 |
| `mpicc` | 編譯 C MPI 版並帶入 MPICH 函式庫 | `mpich-4.1.2-15.el10.x86_64`、`mpich-devel-4.1.2-15.el10.x86_64` 已安裝 |
| `mpirun` | 在本機直接啟動 MPI ranks | 已確認路徑 `/usr/lib64/mpich/bin/mpirun` |
| `srun --mpi=pmi2` | 由 Slurm 啟動 MPI 工作 | 當時 `srun --mpi=list` 列出 `pmi2`，工作 9 已實測 |

MPICH 的命令位於 `/usr/lib64/mpich/bin`。
這台 VM 的 shell 使用下列環境準備；它只影響當前 shell，
不安裝套件或修改服務：

```bash
source /etc/profile.d/modules.sh
module load mpi/mpich-x86_64
```

載入後 `mpicc`、`mpirun` 都可從該路徑找到。

## C++：讀取程序快照

[proc_snapshot.cpp](../project/workloads/proc_snapshot.cpp) 接受 `--pid`，
只讀 `/proc/<PID>/status`，輸出程序名稱、當時狀態及 `VmRSS`。
`VmRSS` 是當時常駐記憶體的約略值，不是記憶體上限；
程序可能結束或 PID 被重用，結果不能當成持續監測。
無法取得 `VmRSS` 時程式輸出 `unavailable`，不把未知寫成零。

編譯產物放 `/tmp/proc_snapshot`；編譯不會執行程式或改動指定程序：

```bash
g++ -std=c++17 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/proc_snapshot /root/hpc-arch/project/workloads/proc_snapshot.cpp
```

| 實際測試命令 | 必要結果 | 判讀 |
|---|---|---|
| `/tmp/proc_snapshot --pid $$` | `pid=4278`、`name=bash`、`state=S (sleeping)`、`vmrss=5156 kB` | 讀到當時 shell 的快照 |
| `/tmp/proc_snapshot --pid abc` | `PID 必須是正整數`、退出碼 `2` | 非數字參數被拒絕 |
| `/tmp/proc_snapshot --pid 99999999` | 無法開啟對應 `/proc` 路徑、退出碼 `3` | 不存在的 PID 被辨認；未實測權限不足 |

以上兩個錯誤案例是工具功能驗證，並非建置試錯。

### 交給單節點 Slurm

[proc-snapshot.sbatch](../project/workloads/proc-snapshot.sbatch) 在 `debug`
分區請求一個節點、一個 task、一個 CPU、64 MiB 與兩分鐘上限。
它用 `srun` 啟動工具，工作輸出寫到提交帳號的家目錄。
一般帳號不能穿過 `/root`，先部署腳本副本：

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/proc-snapshot.sbatch /home/a2264/proc-snapshot.sbatch
```

再由 `a2264` 提交並等待工作結束：

```bash
sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch --wait /home/a2264/proc-snapshot.sbatch'; printf 'sbatch_exit=%s\n' "$?"
```

```text
Submitted batch job 7
sbatch_exit=0
job_id=7
node=instance-20260923-104239
pid=37809
name=proc_snapshot
state=R (running)
vmrss=3224 kB
```

後五行擷取自 `/home/a2264/proc-snapshot-7.out`。
工作正常退出，工具在單節點 Slurm 工作中讀到自己的程序快照。

## C：已知答案的序列版

[sum_serial.c](../project/workloads/sum_serial.c) 接受 `N`，
逐一加總 `1` 到 `N`，輸出 `n`、`sum`。
有效範圍是 `0` 到 `10000000`，不接受非十進位整數。
程式只使用 CPU，不寫檔案或更改服務。

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_serial /root/hpc-arch/project/workloads/sum_serial.c
```

| 實際命令 | 輸出或退出碼 | 核對 |
|---|---|---|
| `/tmp/sum_serial 0` | `n=0`、`sum=0` | 空區間 |
| `/tmp/sum_serial 1` | `n=1`、`sum=1` | 單筆 |
| `/tmp/sum_serial 10` | `n=10`、`sum=55` | 已知一般答案 |
| `/tmp/sum_serial 11` | `n=11`、`sum=66` | 供不能整除的 MPI 分工比對 |
| `/tmp/sum_serial abc` | 參數錯誤、退出碼 `2` | 無效輸入被拒絕 |

## C：MPI 分工版

[sum_mpi.c](../project/workloads/sum_mpi.c) 使用同一個 `N`。
每個 rank 計算一段連續數字，rank 0 合併部分總和；
輸出含 `rank`、`host`、`first`、`count`、`partial` 與總和。
無效輸入由 rank 0 通知其他 rank 一起結束，避免程序卡在通訊等待。
rank 輸出順序可能變動，應按編號和區間判讀。

在載入 MPICH 的 shell 編譯：

```bash
mpicc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_mpi /root/hpc-arch/project/workloads/sum_mpi.c
```

本機三個 rank 的不等分案例：

```bash
mpirun -n 3 /tmp/sum_mpi 11
```

```text
rank=0 size=3 host=instance-20260923-104239 first=1 count=4 partial=10
rank=1 size=3 host=instance-20260923-104239 first=5 count=4 partial=26
rank=2 size=3 host=instance-20260923-104239 first=9 count=3 partial=30
n=11
sum=66
```

三段為 `1–4`、`5–8`、`9–11`，部分總和 `10+26+30=66`，
與序列版相同。三個 host 相同，因此只有單節點分工證據。

| 其他本機實測 | 實際結果 | 判讀 |
|---|---|---|
| `mpirun -n 3 /tmp/sum_mpi 0` | 所有 rank 的 `count=0`，`sum=0` | 空區間 |
| `mpirun -n 3 /tmp/sum_mpi 1` | 只有 rank 0 分到數字，`sum=1` | rank 數多於資料筆數 |
| `mpirun -n 3 /tmp/sum_mpi 10` | 部分總和 `10+18+27=55` | 與序列版一致 |
| `mpirun -n 3 /tmp/sum_mpi abc` | 參數錯誤、`mpirun_exit=2` | 無效輸入被拒絕 |

### 由 Slurm 啟動兩個 rank

[sum-mpi.sbatch](../project/workloads/sum-mpi.sbatch) 在 `debug` 分區
申請一個節點、兩個 task（各一 CPU）、128 MiB，最多兩分鐘。
腳本載入 MPICH，再由 `srun --mpi=pmi2` 啟動 `/tmp/sum_mpi 10`。
執行節點必須先有 MPICH 和 `/tmp/sum_mpi`；目前只準備了這台 VM。

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/sum-mpi.sbatch /home/a2264/sum-mpi.sbatch
sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch /home/a2264/sum-mpi.sbatch'
```

```text
Submitted batch job 9
job_id=9
batch_node=instance-20260923-104239
rank=0 size=2 host=instance-20260923-104239 first=1 count=5 partial=15
rank=1 size=2 host=instance-20260923-104239 first=6 count=5 partial=40
n=10
sum=55
```

工作結果擷取自 `/home/a2264/sum-mpi-9.out`。
用 `scontrol show job 9` 查得 `JobState=COMPLETED`、`ExitCode=0:0`、
`NumNodes=1`、`NumTasks=2`、`NumCPUs=2`。
兩個 rank 在同一節點，`15+40=55`；
這證明單節點 Slurm 啟動 MPI 並算對答案，還不是跨節點通訊成果。

## 後續缺口

取得並接入獨立運算節點後，才能用各 rank 的主機名及資料交換
驗證跨節點 MPI。GPU 工作則要有裝置、輸入、已知答案與使用率證據。
只有 `nvidia-smi` 顯示卡，不能宣稱 GPU 計算成功或有加速。
