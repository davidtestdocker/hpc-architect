# 模組 02：Linux 問題判斷與 Python 健檢工具

[能力路線](ROADMAP.md)｜職缺核心：Linux 使用與程式開發；支撐能力：獨立診斷叢集節點。

## 先教會的概念

程序是一次執行中的程式，服務是由系統管理並可能長期運行的程序。退出狀態表示命令是否按約定成功；管線中的最後一個成功不保證前面的步驟成功。路徑存取要逐層通過目錄權限；sudo 授權與普通工作帳號能否讀寫資料是兩回事。主機總資源、程序的 ulimit 和 cgroup 配額是不同層的限制，不能看到 free 記憶體就斷言某工作一定能跑。這些概念只對照實際健檢需求補教，不重做無意義的純指令練習。

Python CLI 要有清楚的輸入、穩定的輸出格式、退出狀態和錯誤分類。「條件不符」與「檢查本身失敗」不同；部分節點無回應不能把全部結果寫成 OK。測試不是只跑一次成功案例，而是用可控輸入驗證正常、缺資料、權限拒絕、逾時和格式錯誤。

例：指定的資料路徑確實不存在是「條件不符」；工具連權限資訊都讀不到是「無法判斷」。兩者都不能輸出 OK，但後續處理方式不同。

## 指令先講清楚，再操作

首次用到時說明 id／namei -l 查身分和路徑每一層，ulimit -a 與 /proc/self/cgroup 查程序及 cgroup 邊界，df／findmnt 查檔案系統；它們觀察的層次不同。python3 --version 查直譯器，python3 -m venv 建專案隔離環境，python3 -m unittest 或選定測試器跑測試，工具的 --help 應說明參數。只有當檢查邏輯需要某命令時才使用；環境與版本確定後再寫本次精確指令。

## 實作主線與過關證據

在 project/healthcheck/ 做一個可重跑的 Python 工具：接受工作路徑與資源需求，回報觀察值、限制來源和判定；輸出 JSON 供後續監控使用。使用 argparse、例外處理、逾時與明確退出碼；檢查命令失敗時保留錯誤訊息但不洩漏秘密。用真實 VM 做正常案例，用安全、可控的缺失路徑和無效參數等案例驗證錯誤處理；不建立純測試目錄或施加高記憶體負載。

過關需有原始碼、使用說明和自動測試；至少能區分可執行、條件不符、無法判斷三類，測試覆蓋正常與多種失敗。能說明每個判定由什麼證據支持，以及哪些情況工具不能保證。Git 只在管理這個真實程式時教分支、提交和回復，不拿現有工作樹的其他變更練習。

開始帶練前，先在本文件追加本次確定的 VM 指令、目的及檔案影響；執行後才記錄輸出與判讀。現在沒有程式成果。

## 第一次帶練：確認 Python 執行環境

本模組要把現有單節點 Slurm 環境的健檢需求做成可重跑的 Python CLI。
開始寫程式前，先確認 VM 上的 Python 版本，才能選擇相容的標準函式庫用法；
目前不安裝套件，也不建立虛擬環境。

第一條確定要在 VM 執行的指令是 `python3 --version`。
它只印出 `python3` 直譯器版本，不建立或修改檔案，
不影響 Slurm、MUNGE、其他服務或雲端資源。
收到實際輸出後再決定工具的檔案結構與實作方式。

實際執行與輸出：

```console
# python3 --version
Python 3.12.14
```

VM 已有 Python 3.12.14；本工具可先使用標準函式庫，不需為此安裝套件。

## 第二次帶練：確認 Slurm 節點資料

健檢程式需要用結構化欄位讀取排程器看到的節點狀態，而非解析給人看的表格。
JSON 是以欄位名稱與值表示資料的格式；先看這台 VM 的實際輸出，
再決定程式要讀哪些欄位及如何處理缺欄位。

本次確定要在 VM 執行的指令是
`scontrol --json show node instance-20260923-104239`。
`show node` 讀取指定節點的 Slurm 資料，`--json` 要求 JSON 輸出。
此指令不建立或修改檔案，也不變更節點、工作、服務或雲端資源。
收到實際輸出後，才記錄有用欄位並設計 CLI 的判斷。

實際執行與輸出：

```console
# scontrol --json show node instance-20260923-104239
scontrol: fatal: serializer_required: could not find plugin for application/json
```

這個 `scontrol` 無法載入 JSON 序列化外掛，因此沒有取得節點資料。
先用 Slurm 現有的自訂輸出格式讀取需要的欄位，不為健檢工具額外安裝外掛。

下一條確定要在 VM 執行的指令是
`sinfo -N -h -n instance-20260923-104239 -o '%N|%T|%c|%m'`。
`-N` 按節點列出、`-h` 不印表頭、`-n` 指定節點，`-o` 指定欄位：
節點名、完整狀態、設定 CPU 數及設定記憶體 MiB。
豎線作欄位分隔，供之後的程式辨識；數量是 Slurm 的節點設定值，
不是當下可分配給工作的剩餘量。
這條指令只讀取排程資訊，不建立或修改檔案，也不影響服務或雲端資源。

實際執行與輸出：

```console
# sinfo -N -h -n instance-20260923-104239 -o '%N|%T|%c|%m'
instance-20260923-104239|idle|2|3000
```

Slurm 目前回報此節點為 `idle`，設定總量為 2 CPU、3000 MiB 記憶體。
這些數字足以判斷「需求是否超過節點設定」，不能保證工作當下有足夠剩餘資源，
也不能代替分區限制與實際 `srun`／`sbatch` 驗證。

## 健檢 CLI 第一版

已建立 [程式](../project/healthcheck/node_preflight.py)、
[測試](../project/healthcheck/test_node_preflight.py)與
[使用說明](../project/healthcheck/README.md)。
程式以執行者的 UID/GID 檢查工作目錄，並用 `sinfo` 讀取指定節點狀態與設定總量。
`pass` 表示目前檢查的前置條件通過，不代表工作必然能被排程；
`fail` 是已知條件不符，`unknown` 是查詢逾時、失敗或資料不足。
詳細參數與退出碼見使用說明；此處只記帶練命令與實際證據。

本工作區的自動測試命令為
`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s project/healthcheck -p 'test_*.py' -v`。
它只在專案中使用模擬的 Slurm 回應驗證分類，不操作 VM 的 Slurm 服務，
環境變數使 Python 不產生 `__pycache__` 檔案。
實際結果：5 項測試通過，包含正常、CPU 需求超額、控制器查詢失敗、
路徑缺失且查詢逾時，以及資料格式錯誤。

在 VM 上用工作帳號驗證前，先將程式複製到它可讀取的位置。
下一條確定要在 VM 執行的指令是
`install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/healthcheck/node_preflight.py /home/a2264/node_preflight.py`。
它建立或覆蓋 `/home/a2264/node_preflight.py`，內容取自版本庫中的程式；
不執行程式、不修改 Slurm／MUNGE 服務，也不新增雲端資源。
日後更新程式可用同一條指令重新複製，移除部署檔即可復原。

實際執行：

```console
# install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/healthcheck/node_preflight.py /home/a2264/node_preflight.py
#
```

指令沒有錯誤輸出，已在 `/home/a2264/` 部署第一版程式；
此步尚未驗證 `a2264` 執行結果。

依學員要求，原始程式與測試的每個函式已補中文用途註解，
並將此要求寫入 `AGENTS.md`。部署檔仍是註解更新前的版本，
下一條確定要在 VM 執行的指令仍是
`install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/healthcheck/node_preflight.py /home/a2264/node_preflight.py`。
這次會覆蓋同一檔案，使部署檔與專案原始碼一致；
不執行程式、不變更服務或雲端資源，必要時可移除部署檔復原。

實際再次執行：

```console
# install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/healthcheck/node_preflight.py /home/a2264/node_preflight.py
```

指令沒有錯誤輸出，部署檔已更新為含每個函式中文註解的版本。

下一條確定要在 VM 執行的指令是
`sudo -iu a2264 python3 /home/a2264/node_preflight.py --node instance-20260923-104239 --path /home/a2264 --cpus 1 --memory-mib 256`。
`sudo -iu a2264` 使檢查以工作使用者身分執行；`--node` 指定 Slurm 節點，
`--path` 是要檢查的工作目錄，`--cpus` 與 `--memory-mib` 是本次工作需求。
程式會印出一行 JSON 並用退出碼表示結果；這次只讀取目錄權限與 Slurm 資料，
不建立或修改檔案、不提交工作、不變更服務或雲端資源。
