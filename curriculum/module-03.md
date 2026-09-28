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
Slurm 的 `ntasks` 指啟動的程序數，`cpus-per-task` 指每個程序分配的 CPU 數，兩者不能互換。
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

[proc-snapshot.sbatch](../project/workloads/proc-snapshot.sbatch) 讓 Slurm 在 `debug`
分區啟動一個行程，執行已編好的 `/tmp/proc_snapshot`，
藉此核對 C++ 工具是否能在排程工作內讀取程序狀態。
它由一般帳號 `a2264` 從自己的家目錄提交；
腳本申請一個節點、一個工作行程、一個 CPU、64 MiB 記憶體與兩分鐘上限。
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
工作最多請求兩分鐘、一個節點、一個行程、一個 CPU 及 64 MiB 記憶體，
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
