# 模組 04：多節點網路與共享資料路徑

[能力路線](ROADMAP.md)｜職缺核心：網路設定與管理；支撐能力：叢集架構規劃。

## 目前做到哪裡

| 項目 | 已確認的結果 |
|---|---|
| 控制節點 | 台灣 `asia-east1-b`，私有 IP `10.140.0.2` |
| GPU 節點 | `compute-gpu01` 已建於東京 `asia-northeast1-c`，私有 IP `10.146.0.3` |
| GPU VM 狀態 | 2026-10-01 手動停止後查得 `TERMINATED`；40 GiB 開機磁碟保留 |
| 本模組下一步 | 使用時啟動 GPU VM，驗證私網、共享資料、跨節點工作與 GPU 裝置 |

**停止 VM 仍會產生磁碟費用。** 開機磁碟設定 `autoDelete: true`，
代表刪除 VM 時會一併刪除；停止 VM 不會刪除磁碟。
目前的成果是節點建立與位址核對；本模組仍在進行。

## 這個模組要驗證什麼

資料要從控制節點交給 GPU 節點上的工作，至少要過四關：

1. **找到節點**：確認私有 IP、名稱解析與路由。
2. **連上服務**：確認 SSH 等服務有監聽，雲端與 VM 內的防火牆允許連線。
3. **讀到相同資料**：確認共享路徑已掛載，使用者 ID 和每層目錄權限相符。
4. **用到 GPU**：確認驅動辨認裝置，再由實際工作驗證排程分配與輸出。

例如，名稱解析得到 GPU 節點的 IP，只證明「找到節點」；
SSH 仍可能被路由、防火牆或服務狀態擋住。能 SSH 也不代表
共享路徑可讀，`nvidia-smi` 能看到卡也不代表 Slurm 已把卡分給工作。

### 檢查時用哪個指令

以下是各層會用到的工具。**本節是用途對照，不表示每條都已執行**；
實際執行的命令與結果在後面的日期紀錄中。

| 要確認的事 | 指令 | 看什麼、不能據此推論什麼 |
|---|---|---|
| 本機 IP 與介面 | `ip -br addr` | 看介面是否啟用、取得哪個 IP；介面的 `/32` 不等於 VPC 子網範圍 |
| 封包下一跳 | `ip route` | 看預設閘道與路由；有路由仍不代表對方服務可連 |
| 名稱解析 | `getent hosts <主機名>` | 看作業系統會解析成哪個 IP；不測試連線 |
| 服務連線 | `ssh <主機名>`、`ss` | 分別測試 SSH 與查看本機監聽；失敗時還要分查雲端和 VM 防火牆 |
| 共享檔案 | `findmnt <路徑>`、`namei -l <路徑>` | 分別查掛載與路徑每層權限；還要核對兩端 UID/GID |
| GPU 裝置 | `nvidia-smi` | 查驅動是否辨認卡及當下狀態；不能代替 GPU 工作或 Slurm 分配驗證 |

`<主機名>` 和 `<路徑>` 是待實作時才會確定的參數，不是已執行的命令。
不會只憑一次 ping 成功宣稱整條工作路徑正常。

### 共享路徑與驗收範圍

NFS 是讓多台 VM 透過網路使用同一份檔案的方式；
案例包含伺服器匯出、用戶端掛載、兩端 UID/GID（使用者與群組的數字 ID）
及逐層權限。
NFS 有單點故障、快取與效能限制，不能代表所有 HPC 儲存。
時間或身分不一致也可能造成叢集服務或檔案存取失敗。

這個教學叢集可讓管理、運算與儲存流量共用網路；
擴大規模時才依安全邊界、頻寬、延遲與故障影響評估分流。
GPU 的資料路徑還包含網路、主機記憶體與 GPU 記憶體。
單卡雲端 VM 無法驗證實體交換器、RDMA 或多卡互連。

本模組以兩台獨立 VM 的互通、共享資料讀寫、跨節點工作與 GPU 裝置辨認
作為過關證據，並能指出連線或存取故障位於哪一層。
`project/docs/` 保存實際拓撲、位址與通訊矩陣、身分與權限設計，
以及 GPU 型號和成本假設。
連通與資料讀寫驗證後，再安排可復原的名稱解析、連線或 NFS 故障，
留下觀察、定位、修復和復測證據；操作前先定好復原方式，
不把叢集服務暴露到公網。

## 2026-09-30：控制節點基線

專案為 `project-78b8a95c-a2c0-461f-a08`。
控制節點位於台灣 `asia-east1-b`，使用 `default` VPC。
先查位址與路由，建立之後對照 GPU 節點的基線。
兩條命令都只讀，不改檔案、服務或雲端資源。

**位址：**

```bash
ip -br addr
```

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             10.140.0.2/32 fe80::2725:28ff:b62c:9e10/64
```

`eth0` 已啟用，私有 IPv4 為 `10.140.0.2`。
`/32` 是客體介面顯示值，不能拿來推論 VPC 子網大小。

**路由：**

```bash
ip route
```

```text
default via 10.140.0.1 dev eth0 proto dhcp src 10.140.0.2 metric 100
10.140.0.1 dev eth0 proto dhcp scope link src 10.140.0.2 metric 100
```

`10.140.0.1` 是預設下一跳。Compute Engine API 顯示控制節點位於
`default` VPC 的 `asia-east1/default` 子網，子網 CIDR 為
`10.140.0.0/20`。

控制節點的開機映像為 `almalinux-cloud/almalinux-10-v20260811`，
磁碟為 10 GiB `pd-balanced`。G2 要求開機磁碟至少 40 GiB，
所以 GPU 節點不能直接複製控制節點的磁碟大小。

## 2026-10-01：東京 GPU 節點建立

建成的節點是 `compute-gpu01`：`g2-standard-4`（4 vCPU、16 GiB、
一張 NVIDIA L4），位於東京 `asia-northeast1-c`。
使用 AlmaLinux 10、`default` VPC、40 GiB `pd-balanced` 開機磁碟；
只配置私有 IP，不配置 VM 服務帳戶。設定單次執行最多 2 小時後停止。
建立 VM 與磁碟會產生費用，停止後磁碟仍計費；
東京與台灣節點間的流量也可能計費。

### 建立命令與結果

```bash
gcloud compute instances create compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --machine-type=g2-standard-4 \
  --image-project=almalinux-cloud \
  --image=almalinux-10-v20260811 \
  --boot-disk-type=pd-balanced \
  --boot-disk-size=40GB \
  --network=default \
  --subnet=default \
  --no-address \
  --no-service-account \
  --no-scopes \
  --maintenance-policy=TERMINATE \
  --max-run-duration=2h \
  --instance-termination-action=STOP \
  --quiet
```

建機成功。輸出的必要欄位：

```text
NAME           ZONE               MACHINE_TYPE   INTERNAL_IP  EXTERNAL_IP  STATUS
compute-gpu01  asia-northeast1-c  g2-standard-4  10.146.0.3               RUNNING
```

映像原本為 10 GiB；日後進入 VM 時，要確認根分割區是否擴展至 40 GiB。

### 建立後核對

以下命令唯讀查詢 VM 實際設定：

```bash
gcloud compute instances describe compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --format='json(name,status,zone,machineType,networkInterfaces,serviceAccounts,disks,resourcePolicies,terminationTime,maxRunDuration,instanceTerminationAction,scheduling)'
```

| 欄位 | 實際結果 | 意義 |
|---|---|---|
| `status` | `RUNNING` | 查詢當時 VM 已啟動 |
| `networkIP`／外部 IP | `10.146.0.3`／無 | 只有私有位址 |
| `maxRunDuration.seconds` | `7200` | 單次執行最長 2 小時 |
| `instanceTerminationAction` | `STOP` | 到時停止 VM |
| 開機磁碟 | 40 GiB、`autoDelete: true` | 刪除 VM 時連磁碟一併刪除 |
| `serviceAccounts` | 回傳沒有此欄位 | 符合建機時不配置服務帳戶的設定 |

## 2026-10-01：依要求停止 VM

建機後當天先停止 VM，以免繼續累積運算費；
這個操作保留開機磁碟，日後可再啟動。

```bash
gcloud compute instances stop compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --quiet
```

停止命令回報 `Updated`。再以唯讀命令核對：

```bash
gcloud compute instances describe compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --format='value(status)'
```

```text
TERMINATED
```

**判讀：** VM 已停止，未刪除 VM 或磁碟；磁碟仍保留並計費。
下一次使用前要再啟動 VM，先確認私網與客體系統，
再進行共享資料和 GPU 驅動驗證。
