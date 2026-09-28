# Slurm 節點工作前檢查

## 這支程式是什麼

`node_preflight.py` 是提交 Slurm 工作前的簡單檢查表。
你給它工作目錄、指定節點和資源需求，它會找出明顯的阻礙；它不會提交工作。
程式只使用 Python 標準函式庫，執行時需要可查詢 Slurm 的 `sinfo`。

## 執行健檢

以下例子使用模組二已部署到 `/home/a2264/` 的程式，
讓工作帳號 `a2264` 檢查一個需要 1 CPU、256 MiB 記憶體的工作：

```bash
sudo -iu a2264 python3 /home/a2264/node_preflight.py --node instance-20260923-104239 --path /home/a2264 --cpus 1 --memory-mib 256
```

`sudo -iu a2264` 讓目錄權限按工作帳號判斷；如果用 root 執行，檢查到的是 root 的權限。
`--node` 指定 Slurm 節點；`--path` 指定工作目錄；
`--cpus` 和 `--memory-mib` 是這份工作的需求。
可選的 `--timeout` 指定 `sinfo` 最多等待幾秒，預設為 5。
用 `python3 /home/a2264/node_preflight.py --help` 可查看全部參數。

程式會查四件事：工作帳號能否讀、寫、進入目錄；Slurm 回報的節點狀態；
CPU 需求是否超過節點設定總量；記憶體需求是否超過節點設定總量。
節點 `idle` 通過，`mixed` 無法判斷，其他狀態不通過；
不通過不一定代表節點故障，也可能只是正在被使用。

## 讀懂結果

程式印出一行 JSON。先看整體 `status`，再看 `checks` 中每項的原因。
`requested` 是輸入的資源需求，`observed` 是成功查到的 Slurm 節點資料；
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
