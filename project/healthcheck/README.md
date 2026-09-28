# Slurm 節點工作前檢查

## 這兩支程式在做什麼

`node_preflight.py` 是提交工作前的唯讀檢查工具。
它接收節點名稱、工作目錄、CPU 與記憶體需求，依序做四件事：

1. 以**執行程式的使用者**身分，檢查工作目錄是否存在、是否為目錄，以及能否讀、寫、進入。
2. 執行 `sinfo`，讀取指定節點的狀態、設定 CPU 數和設定記憶體 MiB。
3. 把目錄、節點狀態、CPU 和記憶體各自的結果記在 `checks`，再合併成整體 `status`。
4. 輸出一行 JSON，並用退出碼讓呼叫它的腳本知道結果。

程式中的 `positive_int` 檢查數值參數，`check_directory` 與 `read_node` 取得兩種證據，
`inspect` 彙整判定，`main` 處理命令列與輸出。
它只使用 Python 標準函式庫；執行時需要可查詢 Slurm 控制器的 `sinfo`。
程式不會提交工作、建立檔案、修改節點或變更服務。

`test_node_preflight.py` 是這些判定規則的自動測試。
測試用 `patch` 暫時替換目錄檢查和 `sinfo` 回應，
再呼叫 `inspect` 或 `main`，以 `assertEqual` 核對結果；
因此不需改動真實 Slurm 或工作目錄。
六個案例涵蓋通過、CPU 超額、查詢失敗、目錄缺失且查詢逾時、資料格式錯誤，以及退出碼區分。

## 執行健檢

以下命令應由實際要使用工作目錄的帳號執行；若用 root 執行，
目錄權限檢查反映的會是 root，而非工作帳號。

```bash
python3 node_preflight.py --node instance-20260923-104239 --path /home/a2264 --cpus 1 --memory-mib 256
```

`--node` 指定 Slurm 節點；`--path` 指定工作目錄；
`--cpus` 和 `--memory-mib` 是工作的需求，不是工具要占用的資源。
可選的 `--timeout` 指定 `sinfo` 最多等待幾秒，預設為 5。
用 `python3 node_preflight.py --help` 可查看全部參數。

## 讀懂結果

JSON 的 `requested` 是輸入的資源需求，`observed` 是成功查到的 Slurm 節點資料；
若查詢失敗，`observed` 為空，原因會寫在 `checks`。
`effective_uid` 是執行程式時的有效使用者 ID；`checks` 保留每項結果和理由。

| 整體 `status` | 意義 | 退出碼 |
| --- | --- | --- |
| `pass` | 本工具檢查的條件都通過 | 0 |
| `fail` | 至少一項已知不符 | 1 |
| `unknown` | 沒有已知不符，但至少一項無法判斷 | 3 |

無效命令列參數由 `argparse` 回報，退出碼為 2。
若工作目錄不存在，同時 `sinfo` 逾時，整體仍為 `fail`；
`checks` 會分別保留目錄的 `fail` 和節點查詢的 `unknown`。
這樣既不掩蓋已知問題，也不把未查到的資料當作通過。

CPU／記憶體比對的是 Slurm 的節點設定總量，`pass` 只表示這些前置條件通過；
它不保證當下剩餘資源、分區政策或工作實際排程成功。
本階段是單節點檢查；以後若檢查多節點，須在各節點檢查路徑並保留個別結果。

## 執行自動測試

在專案根目錄執行；`PYTHONDONTWRITEBYTECODE=1` 避免產生 `__pycache__`：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s project/healthcheck -p 'test_*.py' -v
```
