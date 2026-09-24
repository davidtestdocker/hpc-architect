# W01 D6：程序資源限制與 cgroup

[課程總表](../ROADMAP.md) · [參考教材](../../RESOURCES.md) · [進度](../../PROGRESS.md)

狀態：未開始｜實際日期：待填｜實際時間：待填

## 今日目標與課前筆記

W01 D01 已完成 OS、CPU、記憶體與檔案系統盤點，本日不重跑相同指令。改確認 shell 對單一程序施加的資源限制，以及 cgroup 對目前工作負載可用 CPU 與記憶體的限制。

## 學習方式

帶練時一次只執行一條指令；輸出確認後，再進到下一步。

## 實作

讀取 shell resource limit 與目前 shell 所在 cgroup 的 CPU、記憶體限制，並用 D01 已記錄的 2 vCPU、3.8 GiB RAM、無 swap 判斷工作需求是否合理。能說出「VM 可見資源」、「程序限制」、「cgroup 配額」各自限制哪一層，才算完成本日。

## 執行前計畫

本日不建立或修改任何檔案；所有輸出與解讀直接記錄在本文件。

1. `ulimit -a`：列出目前 shell 對程序施加的限制；重點查看 open files、stack size 與 max user processes。
2. `cat /proc/self/cgroup`：取得目前程序所屬的 cgroup 路徑；若不是 cgroup v2，依實際輸出調整後續讀取方式。
3. `cat /sys/fs/cgroup/<上一步的 cgroup 路徑>/cpu.max`：讀取該 cgroup 的 CPU 配額；實際指令中的路徑要依第二步輸出填入，不照抄尖括號。`max` 表示此層未設定 CPU 時間配額。
4. `cat /sys/fs/cgroup/<上一步的 cgroup 路徑>/memory.max`：讀取該 cgroup 的記憶體上限；實際路徑同上。`max` 表示此層未設定記憶體上限。若需判斷有效上限，還須檢查父層 cgroup。

完成觀察後，依實際數值判讀：若一個程式要求 4 個 CPU、4 GiB 記憶體，需求與 VM 可見資源和已觀察到的限制有何衝突？`max` 只表示該層沒有額外上限，不代表可以超過 VM 資源，也不能排除父層或日後排程器的限制。這項判讀直接使用已有輸出，不重跑 D01 盤點。


## 實作紀錄

帶練時追加實際命令、重點輸出與解釋。
