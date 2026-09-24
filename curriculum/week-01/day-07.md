# W01 D7：退出狀態與管線錯誤

[課程總表](../ROADMAP.md)

狀態：已完成｜實際日期：2026-09-24

學習 shell 指令的退出狀態、`$?`、管線對錯誤的處理方式，以及為何維運腳本不能只看畫面有沒有輸出。

## 先理解這兩個概念

每條命令結束時都會交給 shell 一個數字，叫「退出狀態」：`0` 通常表示成功，非 `0` 表示失敗。`$?` 會取得**上一條剛結束的命令**的退出狀態，所以要在下一條命令改寫它之前立即讀取。例如稍後的 `echo "status=$?"` 會顯示前一段管線的狀態。

管線符號 `|` 會把前一個命令的正常輸出交給後一個命令。本日的 `ls 不存在的路徑 | wc -l` 中，`ls` 會失敗並印出錯誤，`wc -l` 仍能正常計算收到的行數。Bash 預設以管線**最後一個命令**的狀態作為整段管線的狀態，因此可能顯示 `0`。`pipefail` 會讓管線在任一段失敗時回報非 `0`，這有助於腳本察覺前段錯誤。

## 實作方向

觀察成功與失敗命令的退出狀態，再比較一般管線與 `pipefail`。用一個小型、可安全重現的失敗案例說明錯誤可能如何被後段命令掩蓋。

## 執行前計畫

本日不建立或修改檔案。沿用 D05 已確認不存在的路徑，觀察錯誤如何經由管線傳遞；指令中的 `bash -c` 只啟動暫時的子 shell，不改動目前 shell 的設定。

1. `bash -c 'ls /tmp/w01d05-path-does-not-exist | wc -l; echo "status=$?"'`：讓 `ls` 失敗、`wc` 仍正常結束，觀察管線預設回報哪個命令的退出狀態。
2. `bash -o pipefail -c 'ls /tmp/w01d05-path-does-not-exist | wc -l; echo "status=$?"'`：在子 shell 啟用 `pipefail`，比較相同失敗案例的退出狀態。

執行後將實際輸出與解釋追加在本文件。

## 實作紀錄

### 1. 管線的預設退出狀態

**實際指令**

```bash
bash -c 'ls /tmp/w01d05-path-does-not-exist | wc -l; echo "status=$?"'
```

**實際輸出**

```text
ls: cannot access '/tmp/w01d05-path-does-not-exist': No such file or directory
0
status=0
```

**結果解釋**

`ls` 因路徑不存在而失敗，錯誤訊息直接顯示在終端機；它沒有提供正常輸出給 `wc -l`，所以 `wc` 計得 0 行並成功結束。Bash 預設取管線最後一個命令 `wc` 的退出狀態，因此 `$?` 顯示 `0`，前段 `ls` 的失敗沒有反映在整段管線的狀態中。

### 2. 啟用 `pipefail` 比較結果

**實際指令**

```bash
bash -o pipefail -c 'ls /tmp/w01d05-path-does-not-exist | wc -l; echo "status=$?"'
```

**實際輸出**

```text
ls: cannot access '/tmp/w01d05-path-does-not-exist': No such file or directory
0
status=2
```

**結果解釋**

`wc` 仍收到零行，但 `pipefail` 使管線反映前段 `ls` 的非零退出狀態，這次是 `2`。因此腳本可藉管線狀態發現錯誤。此示範在顯示狀態後又執行了 `echo`；`echo` 通常成功，所以外層 `bash -c` 最終仍可能回報 `0`。真正撰寫腳本時若要把失敗傳給呼叫者，需保存該狀態並以它結束腳本。
