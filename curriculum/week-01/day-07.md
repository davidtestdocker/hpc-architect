# W01 D7：退出狀態與管線錯誤

[課程總表](../ROADMAP.md)

狀態：未開始｜實際日期：待填

學習 shell 指令的退出狀態、`$?`、管線對錯誤的處理方式，以及為何維運腳本不能只看畫面有沒有輸出。

## 實作方向

觀察成功與失敗命令的退出狀態，再比較一般管線與 `pipefail`。用一個小型、可安全重現的失敗案例說明錯誤可能如何被後段命令掩蓋。

## 執行前計畫

本日不建立或修改檔案。沿用 D05 已確認不存在的路徑，觀察錯誤如何經由管線傳遞；指令中的 `bash -c` 只啟動暫時的子 shell，不改動目前 shell 的設定。

1. `bash -c 'ls /tmp/w01d05-path-does-not-exist | wc -l; echo "status=$?"'`：讓 `ls` 失敗、`wc` 仍正常結束，觀察管線預設回報哪個命令的退出狀態。
2. `bash -o pipefail -c 'ls /tmp/w01d05-path-does-not-exist | wc -l; echo "status=$?"'`：在子 shell 啟用 `pipefail`，比較相同失敗案例的退出狀態。

執行後將實際輸出與解釋追加在本文件。
