# 模組 02：Linux 問題判斷與 Python 健檢工具

[能力路線](ROADMAP.md)｜職缺核心：Linux 與程式開發；支撐能力：獨立診斷節點。

## 目前成果

| 項目 | 已驗證的結果 |
|---|---|
| 程式 | [node_preflight.py](../project/healthcheck/node_preflight.py) 與 [使用說明](../project/healthcheck/README.md) 已建立 |
| 執行環境 | AlmaLinux VM 的 Python 3.12.14；程式使用標準函式庫 |
| 正常案例 | 工作帳號 `a2264`、可存取目錄、1 CPU／256 MiB：`pass` |
| 條件不符 | 請求 3 CPU 超過節點設定 2 CPU：`fail`；`a2264` 無法存取 `/root`：`fail` |

**`pass` 是提交前檢查通過，不保證 Slurm 當下能排到工作。**
CPU 與記憶體比較的是節點設定總量，不是剩餘可用量。

## 這支程式解決什麼問題

在提交 Slurm 工作前，使用工作帳號執行健檢 CLI，
讓它檢查工作目錄、節點狀態、CPU 和記憶體需求。
它只讀取權限與 Slurm 資料，不提交工作或修改服務。

| 輸入 | 用途 |
|---|---|
| `--node` | 要查的 Slurm 節點 |
| `--path` | 工作將使用的目錄；以執行程式的帳號判斷權限 |
| `--cpus`、`--memory-mib` | 工作需要的 CPU 數與記憶體 MiB |

結果輸出一行 JSON。先看整體 `status`，再看 `checks` 中各項原因：

| `status` | 意思 |
|---|---|
| `pass` | 列出的檢查都通過 |
| `fail` | 至少一項明確不符 |
| `unknown` | 沒有已知不符，但資料不足或檢查失敗，不能判定可執行 |

例如目錄確定不存在是 `fail`；連權限資料都讀不到則是 `unknown`。
若有一項確定失敗，即使另一項查詢逾時，整體仍是 `fail`，
細項保留逾時原因。
程式保留退出碼 `2` 給無效命令列參數，`unknown` 使用 `3`；
詳細用法見[使用說明](../project/healthcheck/README.md)。

### 用到的概念與檢查工具

程序是正在執行的程式；服務通常由系統管理並長期運作。
退出碼表示命令如何結束，管線最後一步成功不代表前面也成功。
路徑存取要通過每一層目錄權限，root 可讀不代表工作帳號可讀。
主機總資源、程序 `ulimit` 和 cgroup 配額也是不同限制。

| 指令 | 用途 | 限制 |
|---|---|---|
| `id`、`namei -l` | 查使用者身分與目錄逐層權限 | root 的結果不能代替工作帳號 |
| `ulimit -a`、`/proc/self/cgroup` | 查程序與 cgroup 邊界 | 不等於 Slurm 分配結果 |
| `df`、`findmnt` | 查容量與掛載 | 掛載存在仍須驗證權限 |
| `python3 --version` | 確認直譯器版本 | 不驗證程式功能 |
| `sinfo -N -h -n ... -o ...` | 讀 Slurm 節點設定值 | 不表示當下剩餘資源 |

只在檢查邏輯需要時使用這些工具；上表不表示全部都已在本模組執行。

## VM 上的必要輸入資料

確認 Python 版本的唯讀命令與結果：

```text
$ python3 --version
Python 3.12.14
```

健檢程式從 Slurm 讀取節點名、狀態、CPU 與記憶體設定值。
在這台 VM 使用下列唯讀格式查詢：

```bash
sinfo -N -h -n instance-20260923-104239 -o '%N|%T|%c|%m'
```

```text
instance-20260923-104239|idle|2|3000
```

當時節點為 `idle`，設定總量為 2 CPU、3000 MiB。
這些數值只支持「需求是否超過設定總量」的判斷。

## 部署與實測

原始碼放在專案中；工作帳號無法穿越 `/root` 讀取它，
所以在 VM 上複製一份到 `/home/a2264`：

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/healthcheck/node_preflight.py /home/a2264/node_preflight.py
```

這會建立或覆蓋工作帳號可讀的部署副本，不修改 Slurm 或雲端資源。
以下三個案例都以 `a2264` 身分執行，從 JSON 擷取的必要結果列於表中。

```bash
sudo -iu a2264 python3 /home/a2264/node_preflight.py --node instance-20260923-104239 --path /home/a2264 --cpus 1 --memory-mib 256
```

```bash
sudo -iu a2264 python3 /home/a2264/node_preflight.py --node instance-20260923-104239 --path /home/a2264 --cpus 3 --memory-mib 256
```

```bash
sudo -iu a2264 python3 /home/a2264/node_preflight.py --node instance-20260923-104239 --path /root --cpus 1 --memory-mib 256
```

| 工作目錄 | 請求 | 實際 `status` | 重要 `checks` 欄位與判讀 |
|---|---|---|---|
| `/home/a2264` | 1 CPU、256 MiB | `pass` | `effective_uid=1000`；目錄可進入、節點 `idle`、1 ≤ 2 CPU、256 ≤ 3000 MiB |
| `/home/a2264` | 3 CPU、256 MiB | `fail` | `cpus=fail`：需求 3 大於節點設定 2 |
| `/root` | 1 CPU、256 MiB | `fail` | `work_directory=fail`：`a2264` 無法讀寫並進入 `/root` |

這兩個 `fail` 是刻意驗證工具能辨認真實的不符合條件，
不是部署失敗。測試沒有建立假目錄或提交新工作。

## 完成範圍

程式、使用說明、正常與兩種條件不符的 VM 證據已交付。
工具能在提交前指出明顯問題；真正能否排程和完成，仍以 Slurm 工作結果為準。
