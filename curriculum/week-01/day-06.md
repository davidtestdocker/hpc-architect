# W01 D6：程序資源限制與 cgroup

[課程總表](../ROADMAP.md) · [參考教材](../../RESOURCES.md) · [進度](../../PROGRESS.md)

狀態：已完成｜實際日期：2026-09-24

## 今日目標與課前筆記

W01 D01 已完成 OS、CPU、記憶體與檔案系統盤點，本日不重跑相同指令。改確認 shell 對單一程序施加的資源限制，以及 cgroup 對目前工作負載可用 CPU 與記憶體的限制。

### 先理解 cgroup

cgroup（control group）是 Linux 核心將多個程序歸成一組、對整組程序統計與限制資源的機制。像 `session-7.scope` 這樣的工作階段會有自己的 cgroup；systemd 服務和日後的 Slurm 工作也可能各有一組。`/proc/self/cgroup` 顯示目前程序屬於哪一組，`/sys/fs/cgroup/...` 則顯示那組的設定與統計。

這與 `ulimit` 的作用範圍不同：`ulimit` 是目前 shell 的程序限制，子程序通常會繼承；cgroup 的限制作用於群組內程序的合計用量。cgroup 有父子階層，子層沒有設限時仍可能受父層限制。`cpu.max` 控制一段時間內這組程序可使用多少 CPU 時間，`memory.max` 設定這組程序的記憶體上限；兩者都不代表資源已預留給它。`max` 只表示該層沒有設定該項上限，VM 的實際 CPU 與 RAM 仍是邊界。

## 學習方式

帶練時一次只執行一條指令；輸出確認後，再進到下一步。

## 實作

讀取 shell resource limit 與目前 shell 所在 cgroup 的 CPU、記憶體限制，並用 D01 已記錄的 2 vCPU、3.8 GiB RAM、無 swap 判斷工作需求是否合理。能說出「VM 可見資源」、「程序限制」、「cgroup 配額」各自限制哪一層，才算完成本日。

## 執行前計畫

本日不建立或修改任何檔案；所有輸出與解讀直接記錄在本文件。

1. `ulimit -a`：列出目前 shell 對程序施加的限制；重點查看 open files、stack size 與 max user processes。
2. `cat /proc/self/cgroup`：取得目前程序所屬的 cgroup 路徑；若不是 cgroup v2，依實際輸出調整後續讀取方式。
3. `grep -H . /sys/fs/cgroup/user.slice/user-1000.slice/session-7.scope/{cpu,memory}.max`：用第二步確認的實際路徑，一次讀取此層的 CPU 配額與記憶體上限，並在輸出附上檔名。`max` 表示該層未設定對應上限；若需判斷有效上限，還須考慮父層 cgroup。
4. `grep -H . /sys/fs/cgroup/user.slice/{cpu,memory}.max /sys/fs/cgroup/user.slice/user-1000.slice/{cpu,memory}.max`：讀取兩層父 cgroup 的配額，確認是否有上層限制。若其中一層已取得結果，只補查缺少的那層。

完成觀察後，依實際數值判讀：若一個程式要求 4 個 CPU、4 GiB 記憶體，需求與 VM 可見資源和已觀察到的限制有何衝突？`max` 只表示該層沒有額外上限，不代表可以超過 VM 資源，也不能排除父層或日後排程器的限制。這項判讀直接使用已有輸出，不重跑 D01 盤點。


## 實作紀錄

帶練時追加實際命令、重點輸出與解釋。

### 1. 目前 shell 的程序資源限制

**實際指令**

```bash
ulimit -a
```

**重點輸出**

```text
core file size              (blocks, -c) 0
open files                          (-n) 1024
stack size                  (kbytes, -s) 8192
max user processes                  (-u) 15153
cpu time                   (seconds, -t) unlimited
virtual memory              (kbytes, -v) unlimited
```

**結果解釋**

這些是目前 shell 顯示的資源限制，子程序通常會繼承。單一程序可開啟的檔案描述符上限為 1024；單一執行緒的 stack 上限為 8192 KiB（8 MiB）；core file size 為 0，表示預設不寫出 core dump。`max user processes` 顯示 15153，但以 root 執行時不能直接把它當成一般使用者的實際可用程序數。`cpu time` 與 `virtual memory` 的 `unlimited` 只表示此層沒有設定相應上限，仍受 VM 資源與其他限制約束。

### 2. 確認目前工作階段的 cgroup

**實際指令**

```bash
cat /proc/self/cgroup
```

**重點輸出**

```text
0::/user.slice/user-1000.slice/session-7.scope
```

**結果解釋**

`0::` 表示使用 cgroup v2；目前程序屬於 `/user.slice/user-1000.slice/session-7.scope`。路徑中的 `user-1000.slice` 是工作階段的 cgroup 名稱，不能取代 `id` 判斷有效使用者；先前的 `id` 已確認當時的 shell 是 root。下一步讀取此層的配額設定。

### 3. 讀取目前工作階段的配額

**實際指令**

```bash
grep -H . /sys/fs/cgroup/user.slice/user-1000.slice/session-7.scope/{cpu,memory}.max
```

**重點輸出**

```text
/sys/fs/cgroup/user.slice/user-1000.slice/session-7.scope/cpu.max:max 100000
/sys/fs/cgroup/user.slice/user-1000.slice/session-7.scope/memory.max:max
```

**結果解釋**

這一層未設定 CPU 時間配額；`100000` 是 CPU 配額週期，單位為微秒。記憶體上限也未在此層設定。`max` 只描述此層設定，父層 cgroup 仍可能對工作階段施加上限，因此下一步檢查父層。

### 4. 父層查詢的實際錯誤與已取得結果

**實際輸入與重點輸出**

```text
grep -H . /sys/fs/cgroup/{cpu,memory}.max /sys/fs/cgroup/user.slice/{cpu,memory}.max /sys/fs/cgroup/user.slice/user-1000.slice/
  {cpu,memory}.max
grep: /sys/fs/cgroup/cpu.max: No such file or directory
grep: /sys/fs/cgroup/memory.max: No such file or directory
/sys/fs/cgroup/user.slice/cpu.max:max 100000
/sys/fs/cgroup/user.slice/memory.max:max
grep: /sys/fs/cgroup/user.slice/user-1000.slice/: Is a directory
-bash: cpu.max: command not found
```

**結果解釋**

原指令錯把根 cgroup 的 `.max` 檔當成存在，且過長的輸入在 `user-1000.slice/` 後換行，使 Bash 把後段當成新命令；這是課程指令設計錯誤，沒有修改系統。已成功確認 `user.slice` 沒有 CPU 或記憶體配額；只需補查 `user-1000.slice` 這一層。

### 5. 補查父層並判讀工作資源

**實際指令**

```bash
grep -H . /sys/fs/cgroup/user.slice/user-1000.slice/{cpu,memory}.max
```

**重點輸出**

```text
/sys/fs/cgroup/user.slice/user-1000.slice/cpu.max:max 100000
/sys/fs/cgroup/user.slice/user-1000.slice/memory.max:max
```

**結果解釋**

`user-1000.slice` 與已查過的 `user.slice`、`session-7.scope` 都沒有設定 CPU 或記憶體 `.max` 配額；這只代表目前工作階段所經過的這三層沒有額外配額。D01 的 VM 仍只有 2 個邏輯 CPU、3.8 GiB RAM 且沒有 swap。要求 4 個 CPU 的程式可以建立 4 條執行緒，但不能同時取得 4 個 VM 可見的 CPU；要求實際占用 4 GiB 記憶體則超過 VM 的總 RAM，還須扣除系統與其他程序用量，存在記憶體不足風險。`ulimit` 中的 `open files=1024` 等限制也仍有效；日後由 systemd 或 Slurm 啟動的工作需另查其執行環境，不能直接套用這個 shell 的結果。
