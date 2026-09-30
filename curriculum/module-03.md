# 模組 03：C/C++ 系統程式與 MPI 工作

[能力路線](ROADMAP.md)｜職缺條件：C、C++、Python；支撐能力：能開發、除錯並解釋 HPC 工作。

## 程式與 MPI 的關鍵概念

### 為什麼選 C++

模組 02 已用 Python 寫過健檢工具。這次選 C++，是為了練習另一種在 HPC 工作中常見的交付方式：
**先把原始碼編成可執行檔，再交給 Slurm 啟動**。
編譯把原始碼轉成電腦可執行的內容，連結把程式用到的部分組成可執行檔；
編譯成功只表示產生了程式，不表示答案正確。

職缺列出 C/C++、Python 或 Go，沒有規定每種都要用。
本模組選 C++ 作為編譯型工作的實作語言，練習輸入、資源生命週期、錯誤訊息與退出碼；
也要能閱讀和修改 C。這是課程的具體選擇，不代表所有 HPC 工作都必須用 C++。

### MPI 是什麼、為什麼用

**MPI（Message Passing Interface）** 是讓多個獨立程序交換資料、合併結果的通訊介面。
已經用過的 Slurm 負責分配資源並啟動工作；MPI 處理工作啟動後，程序之間如何合作。
例如計算 1 到 10 的總和，先用一個程序算出已知答案：
`1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 = 55`。
改用 3 個程序合作時，可以這樣分工：

| 程序 | 負責的數字 | 部分答案 |
|---|---|---:|
| 0 | 1、2、3、4 | 10 |
| 1 | 5、6、7 | 18 |
| 2 | 8、9、10 | 27 |

最後合併部分答案：`10 + 18 + 27 = 55`。
每個數字都只分給一個程序，且合併結果等於已知答案，
才能確認這個例子的資料分配與加總沒有漏算或重算。

MPI 把每個程序編一個 **rank**；rank 是程序編號，不是 CPU 核心。
Slurm 的 `ntasks` 指申請的 task 數；`cpus-per-task` 指每個 task 分配的 CPU 數，兩者不能互換。
3 個 rank 可能都在同一台 VM；只有記錄各 rank 的主機名，才有證據判斷是否跨節點。
本模組先用單節點核對計算與排程，取得獨立 compute VM 後再驗證跨節點。

另準備有已知答案的小型 GPU 計算工作，待 GPU VM 可用後驗證實際裝置執行。
只看到 `nvidia-smi` 並不能證明計算工作用到了 GPU，也不能證明計算正確。

## 編譯與執行工具

- `gcc` 編譯 C，`g++` 編譯 C++；編譯時開啟警告，可提早發現可疑寫法。
- `mpicc`／`mpic++` 是編譯 MPI 程式的命令入口，會帶入所需的 MPI 函式庫設定。
- `sbatch` 把工作交給 Slurm；提交成功後，還要看工作輸出與退出狀態，才能判斷程式是否跑對。

MPI 工作要用哪種啟動命令，需依實際安裝的版本與 Slurm 整合方式確認後再決定。

## 實作成果與驗證

在 project/workloads/ 完成一個小型 C++ 系統／資源觀察程式，要求明確參數、檔案或程序資訊讀取、錯誤處理及測試；另完成 C 或 C++ 的序列計算與 MPI 版本。測試零筆、單筆、不可整除、一般輸入與無效輸入；MPI 結果須與序列版一致。將可執行檔透過單節點 Slurm 提交；取得獨立 compute VM 後再驗證跨節點 rank 分布。GPU 計算工作選擇與實際驅動／工具鏈相容的最小例子，保存輸入、預期答案與裝置使用證據。不要把多 rank、跨 VM、使用 GPU 與加速四者混成一件事。

過關證據含原始碼、編譯方法、測試輸入與預期答案、工作腳本、實際輸出和錯誤案例；能當場修改一個參數或修復一個失敗。至少能閱讀並修改 C 與 C++，其中一種要能獨立完成較深入程式。Go 因職缺寫「C/C++、Python 或 Go」而非全都必須，不另設主線。

## C++ 編譯器

已安裝套件：`gcc-c++-14.3.1-4.4.el10.alma.2.x86_64`、
`libstdc++-devel-14.3.1-4.4.el10.alma.2.x86_64`。

## 第一個 C++ 工作：讀取指定程序的狀態

[proc_snapshot.cpp](../project/workloads/proc_snapshot.cpp) 是 **C++ 原始碼**，不是可直接執行的程式。
在這台 VM 執行下方的 `g++` 指令後，才會建立可執行檔 `/tmp/proc_snapshot`；
執行這個檔案並提供 `--pid` 和程序 ID，才會讀取 `/proc/<PID>/status`，
印出程序名稱、狀態和 `VmRSS`。執行程式不會建立另一份 `/tmp/proc_snapshot`，
也**不會停止或修改指定程序**。
這是把模組 02 已練過的「輸入、可判讀輸出、錯誤碼」用 C++ 實作，
之後才能把編成的程式交給 Slurm 執行。

`/proc` 是 Linux 核心提供的程序資訊入口，不是一般保存於磁碟的日誌。
`Name` 是程序名稱，`State` 是讀取時的狀態；
`VmRSS` 是常駐記憶體的約略值，通常以 kB 顯示，**不是記憶體上限**。
程序可能在讀取前結束，PID 也可能日後被重用；
因此輸出只能當作當時指定 PID 的快照，不能保證持續狀態。
這些欄位的定義與 `VmRSS` 的精度限制見
[Linux 核心的 /proc 文件](https://docs.kernel.org/filesystems/proc.html)。

程式從 `main` 接收命令列參數，先用 `std::from_chars` 確認 PID 是正整數，
再用 `std::ifstream` 開啟對應的狀態檔並逐行取出欄位；
檔案物件離開作用範圍時會關閉檔案。
正常輸出是 `pid`、`name`、`state`、`vmrss` 四行；
若檔案沒有 `VmRSS`，會印 `unavailable`，不把未知值寫成零。
退出碼 `0` 表示讀取成功，`2` 表示參數錯誤，`3` 表示檔案無法讀取或缺少必要欄位。
這個工具只支援 Linux 的 `/proc` 格式，且讀取權限由執行它的帳號決定。

先把原始碼編成可執行檔。這次確定要在 VM 執行的第一條指令是：

```bash
g++ -std=c++17 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/proc_snapshot /root/hpc-arch/project/workloads/proc_snapshot.cpp
```

`-std=c++17` 選這份程式使用的 C++ 版本；三個 `-W` 選項開啟常見警告；
`-O0 -g` 保留方便除錯的編譯結果；`-o` 指定輸出檔。
這條指令會建立或覆蓋 `/tmp/proc_snapshot`，不執行程式，
也不更動 Slurm、其他服務或雲端資源；不要把沒有錯誤訊息直接當成結果正確。
若不再需要這個編譯產物，可移除 `/tmp/proc_snapshot`，原始碼仍保存在專案中。

**實際編譯與結果：**

```text
$ g++ -std=c++17 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/proc_snapshot /root/hpc-arch/project/workloads/proc_snapshot.cpp
$
```

指令沒有顯示錯誤或警告，並返回提示字元；可先確認編譯這一步完成。
這尚未證明程式能讀到正確的程序資料。

接著讀取目前 shell 的程序狀態。`$$` 是目前 shell 的 PID，
展開後會交給 `--pid`；這樣使用真正存在的程序，不需要建立假資料。
這次確定要在 VM 執行的指令是：

```bash
/tmp/proc_snapshot --pid $$
```

它只讀取 `/proc/<目前 shell 的 PID>/status`，
預期輸出 `pid`、`name`、`state`、`vmrss` 四個欄位；
`name` 應與目前 shell 相符，實際 PID、狀態及記憶體值以回傳結果為準。
這條指令不建立或修改檔案，不影響 Slurm、其他服務或雲端資源。

**實際執行與輸出：**

```text
$ /tmp/proc_snapshot --pid $$
pid=4278
name=bash
state=S (sleeping)
vmrss=5156 kB
```

本次 `$$` 展開為 PID 4278，讀到的名稱 `bash` 與目前 shell 相符。
`S (sleeping)` 表示讀取時 shell 正在等待，不是程式失敗；
`5156 kB` 是該程序當時的約略常駐記憶體，
不是 Slurm 分配值或記憶體上限。這次確認了有效 PID 的讀取路徑，
尚未驗證錯誤輸入與程序不存在時的行為。

接著驗證參數錯誤。這次把 `--pid` 設成非數字 `abc`，
應由程式拒絕，不應嘗試讀取 `/proc`；
結尾的 `printf` 立即顯示剛才程式的退出碼，避免下一個命令覆蓋 `$?`。
這次確定要在 VM 執行的指令是：

```bash
/tmp/proc_snapshot --pid abc; printf 'exit=%s\n' "$?"
```

預期錯誤訊息為 `PID 必須是正整數`、`exit=2`；
實際結果仍以 VM 輸出為準。
這是一次錯誤輸入測試，只讀既有可執行檔，
不建立或修改檔案、程序、Slurm 服務或雲端資源。

**實際執行與輸出：**

```text
$ /tmp/proc_snapshot --pid abc; printf 'exit=%s\n' "$?"
PID 必須是正整數
exit=2
```

`abc` 不是正整數 PID，程式印出參數錯誤訊息並以 `2` 結束；
這確認了非數字輸入的拒絕路徑，尚未驗證不存在的 PID。

接著驗證格式正確、但不存在的 PID。`99999999` 是正整數，
因此會通過參數檢查；Linux 的 PID 上限低於這個數字，
開啟 `/proc/99999999/status` 應失敗。
這次確定要在 VM 執行的指令是：

```bash
/tmp/proc_snapshot --pid 99999999; printf 'exit=%s\n' "$?"
```

預期程式回報無法開啟 `/proc/99999999/status`，並顯示 `exit=3`；
實際訊息仍以 VM 輸出為準。
這條指令只讀既有可執行檔並嘗試讀取 `/proc`，
不建立或修改檔案、程序、Slurm 服務或雲端資源。

**實際執行與輸出：**

```text
$ /tmp/proc_snapshot --pid 99999999; printf 'exit=%s\n' "$?"
無法開啟 /proc/99999999/status；程序可能已結束，或目前帳號無權讀取
exit=3
```

`99999999` 通過正整數參數檢查，但對應狀態檔無法開啟；
程式以 `3` 結束，確認了檔案讀取失敗的處理路徑。
訊息同時涵蓋程序不存在與權限不足兩種可能；
這次使用超出 Linux PID 範圍的數字，因此是不存在程序的案例，
不能視為已驗證權限不足的行為。

## 交給 Slurm 前確認節點

模組 01 已用 `sinfo -N` 看過分區中的節點；
提交這個 C++ 工具前再查一次，因為當時的 `idle` 不代表現在仍可排程。
這次確定要在 VM 執行的指令是：

```bash
sinfo -N
```

輸出中的 `PARTITION` 用來確認可用分區，`STATE` 用來判斷節點當下狀態；
這次只查詢 Slurm，不提交工作，不修改檔案、服務或雲端資源。

**實際查詢與輸出：**

```text
$ sinfo -N
NODELIST                  NODES PARTITION STATE
instance-20260923-104239      1    debug* idle
```

`debug*` 是目前預設分區，只有本機節點 `instance-20260923-104239`；
查詢時它是 `idle`，可準備單節點工作，但提交時仍須以當時狀態為準。

### C++ 工具的單節點批次腳本

[proc-snapshot.sbatch](../project/workloads/proc-snapshot.sbatch) 在 `debug`
分區申請一個 Slurm task，執行已編好的 `/tmp/proc_snapshot`，
藉此核對 C++ 工具是否能在排程工作內讀取程序狀態。
它由一般帳號 `a2264` 從自己的家目錄提交；
腳本申請一個節點、一個 Slurm task、每個 task 一個 CPU、64 MiB 記憶體與兩分鐘上限。
提交後在工作目錄產生 `proc-snapshot-<工作 ID>.out`，
其中應有工作 ID、節點名稱及工具輸出的 `pid`、`name`、`state`、`vmrss`。
`sbatch --wait` 的退出碼再用來確認批次工作是否正常結束。

腳本內的 `srun` 會在分配到的節點啟動一個 shell；
`exec` 用 C++ 工具取代該 shell 而保留 PID，因此工具讀的是自己的
`/proc/<PID>/status`。這避免把提交端 shell 的 PID 誤當成工作節點上的 PID。
`/tmp/proc_snapshot` 只在目前這台 VM 編譯；這份腳本只供單節點使用，
若日後改成多節點工作，須先把執行檔部署到每個工作節點。

一般帳號無法穿過 `/root` 讀取專案腳本，
所以先由 root 把腳本複製到 `a2264` 的家目錄，供稍後提交。
這次確定要在 VM 執行的指令是：

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/proc-snapshot.sbatch /home/a2264/proc-snapshot.sbatch
```

`install` 會建立或覆蓋 `/home/a2264/proc-snapshot.sbatch`，
設為 `a2264` 擁有且權限為 `0644`；不會修改專案腳本、提交工作、
更動 Slurm 服務或雲端資源。若要撤回這份副本，可刪除家目錄中的該檔。
執行結果仍以 VM 回傳為準。

**實際複製與結果：**

```text
$ install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/proc-snapshot.sbatch /home/a2264/proc-snapshot.sbatch
$
```

指令沒有顯示錯誤並返回提示字元；接著核對檔案擁有者、權限與內容。
同一複製操作後，可一起執行以下兩條唯讀驗證指令：

```bash
stat -c '%U:%G %a %n' /home/a2264/proc-snapshot.sbatch
cmp /root/hpc-arch/project/workloads/proc-snapshot.sbatch /home/a2264/proc-snapshot.sbatch && echo same
```

`stat` 應顯示 `a2264:a2264` 與 `644`；`cmp` 完全相同時才會印出 `same`。
兩條指令只讀檔案，不提交工作或修改服務。

**實際驗證與輸出：**

```text
$ stat -c '%U:%G %a %n' /home/a2264/proc-snapshot.sbatch
a2264:a2264 644 /home/a2264/proc-snapshot.sbatch
$ cmp /root/hpc-arch/project/workloads/proc-snapshot.sbatch /home/a2264/proc-snapshot.sbatch && echo same
same
```

副本由 `a2264` 擁有、權限為 `644`，且與專案腳本內容相同；
可供該帳號提交，尚未執行 Slurm 工作。

### 提交單節點 C++ 工作

這次確定要在 VM 執行的指令是：

```bash
sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch --wait /home/a2264/proc-snapshot.sbatch'; printf 'sbatch_exit=%s\n' "$?"
```

`sudo -u` 讓一般帳號提交；`cd` 將提交目錄設為 `/home/a2264`，
使 `#SBATCH --output` 指定的輸出檔留在該處。
`sbatch --wait` 等待工作結束，最後立即印出其退出碼；
成功提交時會顯示工作 ID，但提交成功還不足以證明程式結果正確。
工作最多請求兩分鐘、一個節點、一個 Slurm task、每個 task 一個 CPU 及 64 MiB 記憶體，
會短暫佔用 `debug` 分區資源，並建立 `/home/a2264/proc-snapshot-<工作 ID>.out`。
它不修改 Slurm 設定或雲端資源；可用工作 ID 找到並移除該輸出檔，
但腳本與輸出保留到核對完成為止。

**實際提交與結果：**

```text
$ sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch --wait /home/a2264/proc-snapshot.sbatch'; printf 'sbatch_exit=%s\n' "$?"
Submitted batch job 7
sbatch_exit=0
```

Slurm 接受工作 7，`sbatch --wait` 等到批次工作正常結束；
還須檢查 `/home/a2264/proc-snapshot-7.out`，才能確認執行位置與程式輸出。
這次確定要在 VM 執行的唯讀指令是：

```bash
sudo -u a2264 -- cat /home/a2264/proc-snapshot-7.out
```

它只讀取工作 7 的標準輸出檔，不修改檔案、Slurm 服務或雲端資源。
應能用 `job_id`、`node` 核對工作身分與節點，
再檢查 `pid`、`name`、`state`、`vmrss` 是否為工具的有效輸出；
實際值以檔案內容為準。

**工作輸出與判讀：**

```text
$ sudo -u a2264 -- cat /home/a2264/proc-snapshot-7.out
job_id=7
node=instance-20260923-104239
pid=37809
name=proc_snapshot
state=R (running)
vmrss=3224 kB
```

工作 7 在 `instance-20260923-104239` 執行，與 `sinfo -N` 顯示的唯一節點相同。
`name=proc_snapshot` 表示 `exec` 後的 PID 37809 確實屬於 C++ 工具；
`R (running)` 是它讀取當下的狀態，`3224 kB` 是當時約略常駐記憶體。
搭配 `sbatch_exit=0`，可確認這份編譯產物在單節點 Slurm 工作內正常執行、
輸出所需欄位。這不構成跨節點、MPI 或 GPU 工作的證據。

## 序列版與 MPI 版計算前的工具確認

接下來要用已知答案的 `1` 到 `N` 加總，比對單一程序與 MPI 多個 rank 的結果。
先查 VM 的 shell 能否找到 MPI 編譯器 `mpicc` 與啟動器 `mpirun`，
避免假定工具鏈已安裝或已加入命令搜尋路徑。
這次確定要在 VM 執行的指令是：

```bash
type -a mpicc mpirun
```

`type -a` 會列出目前 shell 能找到的所有同名命令位置；
若某個命令找不到，也會明確回報。它只查詢 shell 的命令搜尋結果，
不安裝套件、建立檔案、提交工作或修改服務。
查到位置後仍須確認實際版本及與 Slurm 的啟動方式，
才能決定後續編譯與執行指令。

**實際查詢與結果：**

```text
$ type -a mpicc mpirun
-bash: type: mpicc: not found
-bash: type: mpirun: not found
```

目前 shell 找不到這兩個命令；這還不能單憑命令搜尋結果判定套件未安裝，
因為 MPI 工具也可能安裝在尚未加入 `PATH` 的目錄。
後續先核對套件及相容來源，再決定是否需要安裝。

### MPICH 安裝與命令路徑

已從 AlmaLinux 10.2 AppStream 安裝 `mpich-4.1.2-15.el10.x86_64` 與
`mpich-devel-4.1.2-15.el10.x86_64`。
同次安裝的相依套件為
`environment-modules-5.6.1-2.el10.x86_64`、
`gcc-gfortran-14.3.1-4.4.el10.alma.2.x86_64`、
`hwloc-libs-2.11.1-4.el10.x86_64`、
`libfabric-2.3.1-1.el10.x86_64`、
`libgfortran-14.3.1-4.4.el10.alma.2.x86_64`、
`libibverbs-61.0-1.el10.x86_64`、
`libquadmath-14.3.1-4.4.el10.alma.2.x86_64`、
`libquadmath-devel-14.3.1-4.4.el10.alma.2.x86_64`、
`librdmacm-61.0-1.el10.x86_64`、
`ocl-icd-2.3.2-8.el10.x86_64`、
`rpm-mpi-hooks-8-10.el10.noarch` 與
`tcl-1:8.6.13-4.el10.x86_64`。

套件把 `mpicc`、`mpirun` 放在 `/usr/lib64/mpich/bin`，
但此路徑不在安裝前 shell 的命令搜尋路徑中。

這裡的 **Environment Modules** 是 MPICH 安裝時帶入的環境管理套件，
`module` 是它提供的 shell 指令，與 Slurm task、MPI rank 或 Python module 無關。
它解決的是「套件已安裝，但目前 shell 的 `PATH` 找不到命令」這個問題。
套件提供 `/usr/share/modulefiles/mpi/mpich-x86_64` 設定檔；
執行 `module load mpi/mpich-x86_64` 時，`module` 讀取該檔，
為目前 shell 把 `/usr/lib64/mpich/bin` 加入 `PATH`、
把 `/usr/lib64/mpich/lib` 加入 `LD_LIBRARY_PATH`。
前者讓 shell 找到 `mpicc`、`mpirun`，後者讓執行中的 MPI 程式找到函式庫。
這是使用此套件的環境準備，不是本模組要驗證的 MPI 計算能力；
它不會重新安裝 MPICH，也不會永久改寫所有帳號的環境。

因為目前 shell 是在安裝 Environment Modules **之前**開啟的，
須先讀取新套件提供的初始化檔，讓這個 shell 認得 `module` 指令。
這次確定要在 VM 執行的是：

```bash
source /etc/profile.d/modules.sh
```

`source` 在目前 shell 執行該檔，建立 `module` 所需的 shell 函式；
這只更新目前 shell 的環境與函式定義，不建立檔案、提交工作或修改服務。
完成後才載入 MPICH 模組並核對實際命令位置。

**實際執行與結果：**

```text
$ source /etc/profile.d/modules.sh
$
```

指令沒有顯示錯誤並返回提示字元；下一步載入 MPICH 模組。
這次確定要在同一個 VM shell 執行的是：

```bash
module load mpi/mpich-x86_64
```

它會依已安裝的模組檔調整目前 shell 的 `PATH` 與 `LD_LIBRARY_PATH` 等變數，
讓後續命令找到 MPICH 的編譯器與函式庫。
變更只作用於這個 shell 及其子程序；關閉 shell 即不再保留，
可用 `module unload mpi/mpich-x86_64` 提前撤回。
這條指令不編譯、不提交工作，也不修改服務或雲端資源。

**實際執行與結果：**

```text
$ module load mpi/mpich-x86_64
$
```

指令沒有顯示錯誤並返回提示字元；這表示載入動作沒有回報失敗，
仍須核對目前 shell 實際找到的命令路徑。
這次確定要在同一個 VM shell 執行的唯讀驗證指令是：

```bash
type -a mpicc mpirun
```

這次應能看到 MPICH 的命令路徑；若仍找不到，須依實際輸出排查。
指令只查目前 shell 的搜尋結果，不編譯、不提交工作，也不修改檔案或服務。

**實際查詢與結果：**

```text
$ type -a mpicc mpirun
mpicc is /usr/lib64/mpich/bin/mpicc
mpirun is /usr/lib64/mpich/bin/mpirun
```

目前 shell 已能找到 MPICH 的編譯器與啟動器；
這只確認命令路徑，還未驗證 MPI 程式的編譯或執行。

## 已知答案的序列計算

[sum_serial.c](../project/workloads/sum_serial.c) 是單程序 C 程式，
用來建立 MPI 版本的正確性對照。
先在這台 VM 用 `gcc` 編譯成 `/tmp/sum_serial`，
再以 `sum_serial N` 提供一個 `0` 到 `10000000` 的十進位整數。
程式逐一加總 `1` 到 `N`，輸出 `n` 和 `sum`；
例如 `N=10` 的答案必須是 `55`，`N=0` 時總和是 `0`。
它只使用 CPU，沒有檔案輸入，也不修改資料或服務。

程式先檢查參數數量、每個字元和數值範圍，無效輸入會印錯誤並回傳 `2`；
有效輸入回傳 `0`。`N` 上限限制迴圈工作量，也保證總和可放入
`uint64_t`（64 位元無號整數）。
日後 MPI 版須在 `0`、`1`、`10`、不能平均分配給 rank 的 `11`，
以及無效輸入等案例與序列版比對，不能只看 MPI 工作有沒有正常退出。

這次確定要在 VM 執行的編譯指令是：

```bash
gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_serial /root/hpc-arch/project/workloads/sum_serial.c
```

它以 C11 標準編譯，開啟常見警告並保留除錯資訊；
成功時建立或覆蓋 `/tmp/sum_serial`，不執行計算、提交 Slurm 工作，
也不修改服務或雲端資源。實際編譯結果以 VM 輸出為準。

**實際編譯與結果：**

```text
$ gcc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_serial /root/hpc-arch/project/workloads/sum_serial.c
$
```

指令沒有顯示警告或錯誤並返回提示字元；
這表示已產生可執行檔，還不能判斷總和是否正確。
先用已知答案的 `N=10` 驗證一般輸入。
這次確定要在 VM 執行的指令是：

```bash
/tmp/sum_serial 10
```

`1` 到 `10` 的總和是 `55`，預期程式印出 `n=10`、`sum=55`；
實際結果仍以 VM 輸出為準。這條指令只執行本機 CPU 計算，
不建立檔案、提交工作或修改服務。

**實際執行與結果：**

```text
$ /tmp/sum_serial 10
n=10
sum=55
```

`N=10` 得到已知答案 `55`，確認一般輸入的序列計算結果。
接著對同一執行檔做相關的唯讀驗證：

```bash
/tmp/sum_serial 0
/tmp/sum_serial 1
/tmp/sum_serial 11
/tmp/sum_serial abc; printf 'exit=%s\n' "$?"
```

`0` 驗證沒有待加總數字，預期總和為 `0`；
`1` 驗證單筆，預期總和為 `1`；
`11` 預期總和為 `66`，日後可用來測三個 MPI rank 不能整除的分工。
`abc` 應被拒絕並顯示 `exit=2`；`printf` 立即讀取前一條程式的退出碼。
這些指令只執行程式並讀取輸出，不建立檔案或修改服務。

**實際執行與結果：**

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

空區間、單筆及 `N=11` 的總和分別為 `0`、`1`、`66`；
非數字輸入被拒絕並回傳 `2`。這些是後續 MPI 版可核對的基準。

## MPI 分工版

[sum_mpi.c](../project/workloads/sum_mpi.c) 由 MPI 啟動器在 VM 上啟動多個 rank，
每個 rank 只計算 `1` 到 `N` 的一段，最後把部分總和交給 rank 0 合併。
使用時提供與序列版相同的 `N`；正常輸出包含每個 rank 的編號、主機名、
起點、數量、部分總和，以及最終 `n`、`sum`。
讀取 `count=0` 時，表示該 rank 沒分到數字；各 rank 輸出的先後順序不保證固定。
無效輸入由 rank 0 報錯，並通知其他 rank 一起結束，避免有人等在通訊步驟。
程式只做 CPU 計算及 MPI 通訊，不修改檔案或服務；
多個 rank 若都顯示同一主機名，只能證明單節點分工。

分工方式是先算每個 rank 至少拿到的 `N / rank 數` 個數字，
再把餘數逐一分給前面的 rank。
例如 `N=11`、三個 rank 時，分配 `1–4`、`5–8`、`9–11`，
部分答案為 `10`、`26`、`30`，合併後應是 `66`。
`MPI_Bcast` 把輸入及其有效性從 rank 0 傳給所有 rank；
`MPI_Reduce` 把各 rank 的部分答案加到 rank 0。

這些函式由 `#include <mpi.h>` 宣告，編譯時 `mpicc` 會連結 MPICH 函式庫。
程式中的呼叫依序是：

| 函式或名稱 | 在這個程式中的作用 |
|---|---|
| `MPI_Init` | 建立 MPI 執行環境，必須先於其他 MPI 操作。 |
| `MPI_COMM_WORLD` | 代表這次一起啟動的整組 rank。 |
| `MPI_Comm_rank` | 取得目前程序的 rank 編號。 |
| `MPI_Comm_size` | 取得這組 rank 的總數，不是 CPU 數。 |
| `MPI_Bcast` | 由 rank 0 把有效性與 `N` 傳給所有 rank。 |
| `MPI_Get_processor_name` | 取得目前 rank 所在位置的名稱，供核對節點分布。 |
| `MPI_Reduce` | 用 `MPI_SUM` 加總各 rank 的部分答案，結果交給 rank 0。 |
| `MPI_Finalize` | 所有 rank 完成後結束 MPI 環境。 |

`MPI_UINT64_T` 表示傳送的數值對應 C 的 `uint64_t`；
無效輸入也會先把判斷結果通知全部 rank，再一起結束，避免有人等不到通訊。

這次確定要在已載入 MPICH 模組的 VM shell 執行的編譯指令是：

```bash
mpicc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_mpi /root/hpc-arch/project/workloads/sum_mpi.c
```

`mpicc` 會帶入 MPICH 所需的標頭與函式庫設定；
成功時建立或覆蓋 `/tmp/sum_mpi`，不執行 MPI 工作、
提交 Slurm 工作或修改服務。編譯結果仍以 VM 輸出為準。

**實際編譯與結果：**

```text
$ mpicc -std=c11 -Wall -Wextra -Wpedantic -O0 -g -o /tmp/sum_mpi /root/hpc-arch/project/workloads/sum_mpi.c
$
```

指令沒有顯示警告或錯誤並返回提示字元；
這表示已產生 MPI 執行檔，尚未驗證分工和答案。
先在這台 VM 直接啟動三個 rank，測試不能平均分配的 `N=11`。
這次確定要在已載入 MPICH 模組的 VM shell 執行的是：

```bash
mpirun -n 3 /tmp/sum_mpi 11
```

`-n 3` 讓 MPICH 啟動三個 rank；這是本機 MPI 執行，尚未交給 Slurm。
預期 rank 0、1、2 分別拿到 `1–4`、`5–8`、`9–11`，
部分總和為 `10`、`26`、`30`，合併總和應為 `66`，與序列版相同。
各 rank 的輸出順序可能不同，實際主機名以 VM 輸出為準。
這條指令會短暫啟動三個本機程序，不建立檔案、修改服務或雲端資源。

**實際執行與結果：**

```text
$ mpirun -n 3 /tmp/sum_mpi 11
rank=0 size=3 host=instance-20260923-104239 first=1 count=4 partial=10
rank=1 size=3 host=instance-20260923-104239 first=5 count=4 partial=26
rank=2 size=3 host=instance-20260923-104239 first=9 count=3 partial=30
n=11
sum=66
```

三個 rank 分別處理 `1–4`、`5–8`、`9–11`，沒有漏算或重疊；
`10 + 26 + 30 = 66`，與序列版 `N=11` 的結果一致。
三個 rank 的主機名相同，因此這是單節點 MPI 執行，尚未驗證 Slurm 啟動或跨節點。
同一套程式還須核對空區間、少於 rank 數的輸入、一般輸入與錯誤輸入；
以下是相關的唯讀驗證指令，可一起執行：

```bash
mpirun -n 3 /tmp/sum_mpi 0
mpirun -n 3 /tmp/sum_mpi 1
mpirun -n 3 /tmp/sum_mpi 10
mpirun -n 3 /tmp/sum_mpi abc; printf 'mpirun_exit=%s\n' "$?"
```

預期總和依序為 `0`、`1`、`55`，與序列版相同；
`N=0` 時所有 rank 的 `count` 都應是 `0`，`N=1` 時只有一個 rank 分到數字。
`abc` 應被拒絕，程式中的各 rank 會以 `2` 結束；
`mpirun` 的最終退出碼與額外診斷以實際輸出為準。
這些指令只短暫執行本機 MPI 程序，不建立檔案、提交 Slurm 工作或修改服務。

**實際驗證與輸出：**

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

`N=0` 時所有 rank 的 `count=0`、總和為 `0`；
`N=1` 時只有 rank 0 處理數字 `1`，其餘 rank 沒有工作。
`count=0` 時顯示的 `first` 只是公式算出的下一個位置，不代表處理了該數字。
`N=10` 分配 `1–4`、`5–7`、`8–10`，部分答案 `10 + 18 + 27 = 55`，
與序列版相同。`abc` 被拒絕，`mpirun_exit=2`。
這些證據涵蓋本機 MPICH 的分工、空區間、一般輸入及無效輸入，
仍未證明 Slurm 啟動或跨節點執行。

### 啟動參數與部分總和

`mpirun -n 3 /tmp/sum_mpi 10` 中，`mpirun` 先讀取自己的 `-n 3`，
啟動三個 `/tmp/sum_mpi` 程序；程式後面的 `10` 才是各程序收到的 `argv[1]`。
每個程序執行 `MPI_Init` 後，`MPI_Comm_size` 查到這組程序共有三個，
因此 `size=3`；`MPI_Comm_rank` 則讓它們分別取得 rank 0、1、2。
rank 0 將字串 `"10"` 解析成 `n=10`，再傳給另外兩個 rank。

`first` 是該 rank 從哪個數字開始，`count` 是連續處理幾個數字，
`partial` 是這些數字的部分總和。因此 `N=10` 時，
rank 0 算 `1+2+3+4=10`，rank 1 算 `5+6+7=18`，
rank 2 算 `8+9+10=27`；合併得到 `10+18+27=55`。
各 rank 的輸出順序可以不同，不影響分工或答案。

## 準備透過 Slurm 啟動 MPI 工作

本機的 `mpirun` 已證明程式能算對，但還沒有證明 Slurm 能啟動這三個 rank。
Slurm 的 `srun` 可在獲得的工作資源內啟動程序；
它與 MPI 的啟動配合方式須先查看這台 VM 實際提供的選項，
再決定工作腳本要使用哪種方式。

這次先在 VM 執行一條唯讀查詢：

```bash
srun --mpi=list
```

`--mpi=list` 要求 `srun` 列出此安裝提供的 MPI 啟動類型。
這條指令不分配資源、不啟動 MPI 工作、不建立檔案，
也不修改 Slurm 服務、設定或雲端資源。
實際可用的類型以 VM 輸出為準；確認後才編寫與提交工作腳本。

**實際查詢與輸出：**

```text
$ srun --mpi=list
MPI plugin types are...
        none
        cray_shasta
        pmi2
```

此安裝列出 `pmi2`，可先作為單節點 MPICH 工作啟動的候選。
`none` 不提供這項 MPI 啟動配合；`cray_shasta` 對應另一類系統環境。
清單只證明 Slurm 有這個選項，尚未證明目前的 MPICH 程式能透過它正確執行。

### 單節點 MPI 工作腳本

[sum-mpi.sbatch](../project/workloads/sum-mpi.sbatch) 讓一般帳號 `a2264`
在目前 VM 的 `debug` 分區申請一個節點、兩個 Slurm task，
每個 task 一個 CPU，合計 128 MiB 記憶體與兩分鐘上限。
批次 shell 先載入已安裝的 MPICH 模組，再用 `srun --mpi=pmi2`
為每個 task 啟動 `/tmp/sum_mpi 10`。
`10` 是交給程式的 `N`；兩個 task 分別成為一個 MPI rank。
預期 rank 0 計算 `1–5`，部分總和為 `15`；
rank 1 計算 `6–10`，部分總和為 `40`，合併後為 `sum=55`。
腳本也印出工作 ID 與批次節點，供核對執行位置。

執行節點必須已有 `/tmp/sum_mpi` 與 MPICH 模組；目前只準備了這一台 VM。
這份腳本只能驗證單節點 Slurm 啟動；`pmi2` 與 MPICH 是否配合成功，
須等實際工作完成並檢查退出碼與輸出才能判斷。
提交時輸出將寫在提交目錄的 `sum-mpi-<工作 ID>.out`，
腳本本身不修改 Slurm 設定或雲端資源。

一般帳號不能穿過 `/root` 讀取專案腳本，因此先由 root
把目前版本複製到其家目錄。這次確定要在 VM 執行的指令是：

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/sum-mpi.sbatch /home/a2264/sum-mpi.sbatch
```

它會覆蓋 `/home/a2264/sum-mpi.sbatch`，設為 `a2264` 擁有、權限 `0644`；
不提交工作、不建立輸出檔或修改服務。若不再需要，可移除家目錄中的副本，
專案內原稿仍會保留。複製結果以 VM 回傳為準，之後核對副本內容與權限。

**實際複製與結果：**

```text
$ install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/sum-mpi.sbatch /home/a2264/sum-mpi.sbatch
$
```

指令沒有回報錯誤並返回提示字元；還須確認副本的擁有者、權限與內容。
同一次複製的兩項唯讀核對可一起執行：

```bash
stat -c '%U:%G %a %n' /home/a2264/sum-mpi.sbatch
cmp /root/hpc-arch/project/workloads/sum-mpi.sbatch /home/a2264/sum-mpi.sbatch && echo same
```

`stat` 應顯示 `a2264:a2264` 與 `644`；`cmp` 完全相同時才印出 `same`。
兩條指令不提交工作，也不修改檔案或服務。

**實際核對與輸出：**

```text
$ stat -c '%U:%G %a %n' /home/a2264/sum-mpi.sbatch
a2264:a2264 644 /home/a2264/sum-mpi.sbatch
$ cmp /root/hpc-arch/project/workloads/sum-mpi.sbatch /home/a2264/sum-mpi.sbatch && echo same
same
```

副本由 `a2264` 擁有、權限為 `644`，內容與專案中的新版腳本相同；
可以提交，尚未驗證 Slurm 內的 MPI 執行。

### 提交兩個 rank 的 Slurm 工作

這次確定要在 VM 執行的指令是：

```bash
sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch /home/a2264/sum-mpi.sbatch'
```

`sudo -u` 讓一般帳號提交；`cd` 將工作輸出放在 `/home/a2264`。
`sbatch` 提交後回傳工作 ID，不會等待工作結束；
須再依該 ID 查看狀態、退出碼與 `sum-mpi-<工作 ID>.out`，
才能判斷兩個 rank 是否正常啟動、主機名是否相同、部分總和是否合為 `55`。
工作最多申請兩分鐘、一個節點、兩個 task、每個 task 一個 CPU 及 128 MiB 記憶體，
會短暫使用 `debug` 分區的本機節點並建立一份工作輸出檔，
不修改 Slurm 設定、其他服務或雲端資源。

**實際提交與結果：**

```text
$ sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch /home/a2264/sum-mpi.sbatch'
Submitted batch job 9
```

Slurm 接受了工作 9；提交成功不等於工作已執行或答案正確。
先讀取對應輸出檔，核對兩個 rank 的主機、分工與合併結果。
這次確定要在 VM 執行的唯讀指令是：

```bash
sudo -u a2264 -- cat /home/a2264/sum-mpi-9.out
```

它只讀取工作 9 的輸出，不修改檔案、工作或服務。
預期可見工作 ID、批次節點、rank 0 與 1 的部分總和及 `sum=55`；
若工作尚未完成或輸出有錯誤，須依實際內容判讀。

**實際工作輸出：**

```text
$ sudo -u a2264 -- cat /home/a2264/sum-mpi-9.out
job_id=9
batch_node=instance-20260923-104239
rank=0 size=2 host=instance-20260923-104239 first=1 count=5 partial=15
rank=1 size=2 host=instance-20260923-104239 first=6 count=5 partial=40
n=10
sum=55
```

兩個 rank 都位於 `instance-20260923-104239`，
分別處理 `1–5` 與 `6–10`，沒有漏算或重複。
部分總和 `15+40=55`，與序列版及本機 MPI 版的 `N=10` 答案一致。
這是**單節點 Slurm 啟動 MPI** 的計算輸出，不能當作跨節點證據。
輸出內容正確後，仍須確認 Slurm 記錄的工作最終狀態與退出碼。
這次確定要在 VM 執行的唯讀指令是：

```bash
scontrol show job 9
```

它查詢工作 9 的 `JobState`、`ExitCode` 與資源配置，不修改工作或服務。
已完成的工作只在控制器保留一段時間；若查不到，需改用可用的歷史紀錄方式。

**工作 9 的最終狀態與配置：**

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

`COMPLETED` 與 `ExitCode=0:0` 表示 Slurm 記錄這份批次工作正常結束；
實際配置與請求同為一個節點、兩個 task、兩個 CPU、128 MiB 記憶體。
搭配工作輸出的兩個 rank、相同主機名和 `sum=55`，
可確認這份 MPI 程式已在**單節點 Slurm 工作**中正常啟動並算對已知答案。
這份結果不包含獨立節點、跨節點通訊或 GPU 計算的驗證。
