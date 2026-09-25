# Slurm 節點工作前檢查

`node_preflight.py` 用執行者的 UID/GID 檢查工作目錄是否存在且可讀、寫、進入，
並以 `sinfo` 讀取指定節點的狀態、設定 CPU 數與記憶體 MiB。
僅用 Python 標準函式庫；執行時需要可查詢控制器的 `sinfo`。

```bash
python3 node_preflight.py --node instance-20260923-104239 --path /home/a2264 --cpus 1 --memory-mib 256
```

程式輸出一行 JSON。整體 `status` 為 `pass`、`fail` 或 `unknown`，
退出碼分別是 0、1、2；`checks` 列出每項證據，`effective_uid` 表示實際檢查路徑的身分。
`fail` 表示已觀察到條件不符；`unknown` 表示查詢失敗、逾時、資料格式異常，
或目前節點狀態不足以判斷。工作路徑不存在時即使 Slurm 同時查詢失敗，
整體仍是 `fail`，但 `checks` 會保留兩項結果。

CPU／記憶體比對的是 Slurm 的節點設定總量，`pass` 只表示這些前置條件通過；
它不保證當下剩餘資源、分區政策或工作實際排程成功。
本階段是單節點檢查；以後若檢查多節點，須在各節點檢查路徑並保留個別結果。
程式不會提交工作、建立檔案、修改節點或變更服務。

在專案根目錄執行自動測試：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s project/healthcheck -p 'test_*.py' -v
```
