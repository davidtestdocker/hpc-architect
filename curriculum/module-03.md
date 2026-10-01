# 模組 03：C/C++ 系統程式與 MPI 工作

[能力路線](ROADMAP.md)｜職缺條件：C/C++ 與 Python；本模組交付可核對答案的編譯型工作。

## 這個模組在做什麼

先編譯一支 C++ 程序觀察工具，再寫出已知答案的 C 計算程式，
最後用 MPI 讓多個程序分工，交給 Slurm 在單節點執行。
每一步都核對輸入、輸出與退出狀態，確認「程式真的算對」。

## 目前成果

| 項目 | 已驗證的結果 |
|---|---|
| C++ 系統工具 | 讀取 `/proc/<PID>/status`，單節點 Slurm 工作 7 正常退出 |
| C 序列計算 | `N=0、1、10、11` 的總和符合已知答案 |
| 本機 MPI | 三個 rank 的分工與答案符合序列版；都在同一台 VM |
| Slurm 啟動 MPI | 工作 9 用兩個 rank 得 `sum=55`，`COMPLETED`、`ExitCode=0:0` |

本模組的完成範圍是**單節點** C/C++、MPI 計算與 Slurm 工作。
多個 rank 可以在同一台 VM 執行；以下記錄的主機名都相同。

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

下表說明工具角色；實際命令與輸出在後面的實作段落。

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

兩條命令均沒有錯誤輸出。載入後查命令路徑與 Slurm 的 MPI 選項：

```text
$ type -a mpicc mpirun
mpicc is /usr/lib64/mpich/bin/mpicc
mpirun is /usr/lib64/mpich/bin/mpirun
$ srun --mpi=list
MPI plugin types are...
        none
        cray_shasta
        pmi2
```

目前 shell 可找到 MPICH，Slurm 列出 `pmi2`；可否一起執行仍以工作結果核對。

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

實際編譯沒有警告或錯誤輸出，產生 `/tmp/proc_snapshot`。

### 本機實測

```text
$ /tmp/proc_snapshot --pid $$
pid=4278
name=bash
state=S (sleeping)
vmrss=5156 kB
```

```text
$ /tmp/proc_snapshot --pid abc; printf 'exit=%s\n' "$?"
PID 必須是正整數
exit=2
```

```text
$ /tmp/proc_snapshot --pid 99999999; printf 'exit=%s\n' "$?"
無法開啟 /proc/99999999/status；程序可能已結束，或目前帳號無權讀取
exit=3
```

**判讀：**有效 PID 讀到 shell 快照；非數字參數以 2 結束；不存在的 PID 以 3 結束。

### 交給單節點 Slurm

[proc-snapshot.sbatch](../project/workloads/proc-snapshot.sbatch) 在 `debug`
分區請求一個節點、一個 task、一個 CPU、64 MiB 與兩分鐘上限。
它用 `srun` 啟動工具，工作輸出寫到提交帳號的家目錄。
一般帳號不能穿過 `/root`，先部署腳本副本：

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/proc-snapshot.sbatch /home/a2264/proc-snapshot.sbatch
```

`install` 沒有錯誤輸出；`stat` 顯示副本是
`a2264:a2264 644 /home/a2264/proc-snapshot.sbatch`，`cmp` 輸出 `same`。

再由 `a2264` 提交並等待工作結束：

```bash
sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch --wait /home/a2264/proc-snapshot.sbatch'; printf 'sbatch_exit=%s\n' "$?"
```

```text
$ sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch --wait /home/a2264/proc-snapshot.sbatch'; printf 'sbatch_exit=%s\n' "$?"
Submitted batch job 7
sbatch_exit=0
```

再讀工作輸出：

```text
$ sudo -u a2264 -- cat /home/a2264/proc-snapshot-7.out
job_id=7
node=instance-20260923-104239
pid=37809
name=proc_snapshot
state=R (running)
vmrss=3224 kB
```

**判讀：**工作 7 退出碼為 0，`name=proc_snapshot`，在單節點 Slurm 工作中讀到自身的程序快照。

## C：已知答案的序列版

[sum_serial.c](../project/workloads/sum_serial.c) 接受 `N`，
逐一加總 `1` 到 `N`，輸出 `n`、`sum`。
有效範圍是 `0` 到 `10000000`，不接受非十進位整數。
程式只使用 CPU，不寫檔案或更改服務。

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_serial /root/hpc-arch/project/workloads/sum_serial.c
```

實際編譯沒有警告或錯誤輸出，產生 `/tmp/sum_serial`。

### 序列版實測

```text
$ /tmp/sum_serial 10
n=10
sum=55
```

```text
$ /tmp/sum_serial 0
n=0
sum=0
$ /tmp/sum_serial 1
n=1
sum=1
$ /tmp/sum_serial 11
n=11
sum=66
$ /tmp/sum_serial abc; printf 'exit=%s\n' "$?"
N 必須是 0 到 10000000 的十進位整數
exit=2
```

**判讀：**`N=0、1、10、11` 的總和分別為 `0、1、55、66`；非數字輸入被拒絕並以 2 結束。

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

實際編譯沒有警告或錯誤輸出，產生 `/tmp/sum_mpi`。

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

### 其他本機輸入

```text
$ mpirun -n 3 /tmp/sum_mpi 0
rank=0 size=3 host=instance-20260923-104239 first=1 count=0 partial=0
rank=2 size=3 host=instance-20260923-104239 first=1 count=0 partial=0
rank=1 size=3 host=instance-20260923-104239 first=1 count=0 partial=0
n=0
sum=0
$ mpirun -n 3 /tmp/sum_mpi 1
rank=0 size=3 host=instance-20260923-104239 first=1 count=1 partial=1
rank=1 size=3 host=instance-20260923-104239 first=2 count=0 partial=0
rank=2 size=3 host=instance-20260923-104239 first=2 count=0 partial=0
n=1
sum=1
$ mpirun -n 3 /tmp/sum_mpi 10
rank=0 size=3 host=instance-20260923-104239 first=1 count=4 partial=10
rank=2 size=3 host=instance-20260923-104239 first=8 count=3 partial=27
rank=1 size=3 host=instance-20260923-104239 first=5 count=3 partial=18
n=10
sum=55
$ mpirun -n 3 /tmp/sum_mpi abc; printf 'mpirun_exit=%s\n' "$?"
N 必須是 0 到 10000000 的十進位整數
mpirun_exit=2
```

**判讀：**空區間、單筆、`N=10` 和錯誤輸入各有實際輸出；`N=10` 的三段部分總和是 `10+18+27=55`。

### 由 Slurm 啟動兩個 rank

[sum-mpi.sbatch](../project/workloads/sum-mpi.sbatch) 在 `debug` 分區
申請一個節點、兩個 task（各一 CPU）、128 MiB，最多兩分鐘。
腳本載入 MPICH，再由 `srun --mpi=pmi2` 啟動 `/tmp/sum_mpi 10`。
執行節點必須先有 MPICH 和 `/tmp/sum_mpi`；目前只準備了這台 VM。

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/sum-mpi.sbatch /home/a2264/sum-mpi.sbatch
```

`install` 沒有錯誤輸出；`stat` 顯示
`a2264:a2264 644 /home/a2264/sum-mpi.sbatch`，`cmp` 輸出 `same`。
再提交工作：

```text
$ sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch /home/a2264/sum-mpi.sbatch'
Submitted batch job 9
```

讀取工作輸出：

```text
$ sudo -u a2264 -- cat /home/a2264/sum-mpi-9.out
job_id=9
batch_node=instance-20260923-104239
rank=0 size=2 host=instance-20260923-104239 first=1 count=5 partial=15
rank=1 size=2 host=instance-20260923-104239 first=6 count=5 partial=40
n=10
sum=55
```

核對 Slurm 最終狀態：

```text
$ scontrol show job 9
JobId=9 JobName=sum-mpi
JobState=COMPLETED Reason=None
ExitCode=0:0
RunTime=00:00:01 TimeLimit=00:02:00
Partition=debug
NodeList=instance-20260923-104239
BatchHost=instance-20260923-104239
NumNodes=1 NumCPUs=2 NumTasks=2 CPUs/Task=1
ReqTRES=cpu=2,mem=128M,node=1,billing=2
AllocTRES=cpu=2,mem=128M,node=1,billing=2
Command=/home/a2264/sum-mpi.sbatch
StdOut=/home/a2264/sum-mpi-9.out
```

**判讀：**兩個 rank 都在同一台節點，部分總和 `15+40=55`；`JobState=COMPLETED`、`ExitCode=0:0`，配置為一個節點、兩個 task。
