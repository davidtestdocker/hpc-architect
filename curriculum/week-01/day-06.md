# W01 D6：程序資源限制與 cgroup

[課程總表](../ROADMAP.md) · [參考教材](../../RESOURCES.md) · [進度](../../PROGRESS.md)

狀態：未開始｜實際日期：待填｜實際時間：待填

## 今日目標與課前筆記

W01 D01 已完成 OS、CPU、記憶體與檔案系統盤點，本日不重跑相同指令。改確認 shell 對單一程序施加的資源限制，以及 cgroup 對目前工作負載可用 CPU 與記憶體的限制。

## 學習方式

帶練時一次只執行一條指令；輸出確認後，再進到下一步。

## 實作

讀取 shell resource limit 與 cgroup 的 CPU、記憶體限制，解釋它們和 D01 VM 資源快照的差別。

## 執行前計畫

本日不建立或修改任何檔案；所有輸出與解讀直接記錄在本文件。

1. `ulimit -a`：列出目前 shell 對程序施加的限制；重點查看 open files、stack size 與 max user processes。
2. `cat /sys/fs/cgroup/cpu.max`：讀取目前 cgroup 的 CPU 配額；`max` 表示未設定 CPU 時間配額，數字則表示每個週期可用的 CPU 時間。
3. `cat /sys/fs/cgroup/memory.max`：讀取目前 cgroup 的記憶體上限；`max` 表示未設定 cgroup 記憶體上限。


## 實作紀錄

帶練時追加實際命令、重點輸出與解釋。
