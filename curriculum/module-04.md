# 模組 04：多節點網路與共享資料路徑

[能力路線](ROADMAP.md)｜職缺核心：網路設定與管理；支撐能力：叢集架構規劃。

## 目前做到哪裡

| 項目 | 已確認的結果 |
|---|---|
| 控制節點 | 台灣 `asia-east1-b`，私有 IP `10.140.0.2` |
| GPU 節點 | `compute-gpu01` 已建於東京 `asia-northeast1-c`，私有 IP `10.146.0.3` |
| GPU VM 狀態 | 2026-10-01 手動停止後查得 `TERMINATED`；40 GiB 開機磁碟保留 |
| 尚未驗證 | 登入 GPU VM、兩節點私網互通、共享資料、GPU 驅動與工作 |

**停止 VM 仍會產生磁碟費用。** 開機磁碟設定 `autoDelete: true`，
代表刪除 VM 時會一併刪除；停止 VM 不會刪除磁碟。
目前只有兩台 VM 的建機與位址證據，不能把跨節點或 GPU 工作寫成已完成。

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

要完成本模組，還需要兩台獨立 VM 的互通、共享資料讀寫與 GPU 裝置證據，
並能指出故障位於哪一層。`project/docs/` 應保存實際拓撲、
位址與通訊矩陣、身分與權限設計，以及 GPU 型號和成本假設；
真實故障處理才寫入 `project/incidents/`。這些成果目前尚未建立。
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

### 配額與登入

當天以控制 VM 的服務帳戶查 Compute Engine API：

| 範圍 | 配額 | 上限 | 已用 |
|---|---|---:|---:|
| 專案全域 | `GPUS_ALL_REGIONS` | 1 | 0 |
| 專案全域 | `CPUS_ALL_REGIONS` | 24 | 2 |
| 台灣 `asia-east1` | `NVIDIA_L4_GPUS` | 1 | 0 |
| 台灣 `asia-east1` | `CPUS` | 100 | 2 |
| 台灣 `asia-east1` | `INSTANCES` | 24 | 1 |

數量足以提出一張 L4、4 vCPU 的建機請求，**配額不保證即時容量**。
[Google 官方 GPU 地點表](https://docs.cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
列出 `asia-east1-b` 支援 G2。

控制 VM 的服務帳戶只有 `compute.readonly` 等唯讀 API scope；
起初 root 和一般帳號的 `gcloud` 都沒有使用者登入，無法建立 VM。
之後 root 執行：

```bash
gcloud auth login --no-launch-browser
```

完成瀏覽器授權後，登入憑證保存在 root 的 gcloud 設定中；
這條命令沒有建立 VM。授權碼與 token 沒有寫入文件。

## 2026-09-30：台灣 GPU 容量測試

候選節點名為 `compute-gpu01`。第一個方案是
`g2-standard-4`（4 vCPU、16 GiB、一張 NVIDIA L4），
同樣使用 AlmaLinux 10、`default` VPC、40 GiB `pd-balanced` 磁碟。
不配置外部 IP 或 VM 服務帳戶；設定連續執行最多 2 小時後停止。
成功建機會產生 VM 與磁碟費用；停止後磁碟仍計費。

### G2／L4

先在 `asia-east1-b` 使用以下命令：

```bash
gcloud compute instances create compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-east1-b \
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
  --instance-termination-action=STOP
```

第一次送出時原命令漏了 `--no-scopes`；
gcloud 在本機參數檢查要求它與 `--no-service-account` 一起指定，
所以第一次沒有送出建機請求。上面是補正後實際送出的版本。

補正後依序試三個 zone。後兩次只更換上述命令的 `--zone`；
每次確認未建成才試下一個，避免建立多台 VM。

| Zone | 結果 | 判讀 |
|---|---|---|
| `asia-east1-b` | `ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS` | G2＋L4 即時容量不足 |
| `asia-east1-a` | 同上 | 即時容量不足 |
| `asia-east1-c` | 同上 | 即時容量不足；另提醒 40 GiB 磁碟可能需要檢查根分割區擴展 |

三次都沒有建立 VM 或磁碟；錯誤原因是容量，並非前述配額不足。

### N1／T4

同區域 `NVIDIA_T4_GPUS` 配額上限 1、已用 0。
[官方 GPU 地點表](https://docs.cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
列出 `asia-east1-a` 支援 N1＋T4，於是改試一張 T4、
4 vCPU 的 `n1-standard-4`。網路、映像、磁碟和停止設定保持相同。

```bash
gcloud compute instances create compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-east1-a \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
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
  --instance-termination-action=STOP
```

| Zone | 變更 | 結果 |
|---|---|---|
| `asia-east1-a` | 上述命令 | `ZONE_RESOURCE_POOL_EXHAUSTED` |
| `asia-east1-c` | 只改 `--zone=asia-east1-c` | `ZONE_RESOURCE_POOL_EXHAUSTED` |

兩次都沒有建立 VM 或磁碟。當天暫停時，台灣三個 L4 zone、
兩個 T4 zone 均無即時容量。
當時查得東京、新加坡、首爾與孟買各有一張 L4 的區域配額；
2026-09-30 沒有在那些區域提出建機請求。

## 2026-10-01：東京 GPU 節點建立

當天確認登入有效，專案中沒有 `compute-gpu01`。
東京 `asia-northeast1` 的配額如下：

| 配額 | 上限 | 已用 |
|---|---:|---:|
| `NVIDIA_L4_GPUS` | 1 | 0 |
| `CPUS` | 100 | 0 |
| `INSTANCES` | 24 | 0 |

東京 `asia-northeast1-a` 支援 G2，因此先試該 zone。
沿用私有 IP、無 VM 服務帳戶、40 GiB 磁碟和 2 小時停止設定。
若成功，會建立付費 VM 與磁碟；跨東京與台灣的流量也可能計費。

### 第一次：`asia-northeast1-a`

```bash
gcloud compute instances create compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-a \
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

回報 `ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS`：
這個 zone 當下沒有 G2＋L4 容量，沒有建立 VM。
錯誤訊息建議改試 `asia-northeast1-c` 或 `asia-northeast1-b`。

### 第二次：`asia-northeast1-c`

只改 zone，其餘設定相同：

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

這次建立成功。建機輸出的必要欄位：

```text
NAME           ZONE               MACHINE_TYPE   INTERNAL_IP  EXTERNAL_IP  STATUS
compute-gpu01  asia-northeast1-c  g2-standard-4  10.146.0.3               RUNNING
```

40 GiB 磁碟大於映像原本的 10 GiB；gcloud 提醒日後要進入 VM
確認根分割區是否自動擴展。這不是建機失敗。

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

建立後尚未登入客體，也沒有安裝驅動或測試私網、共享資料、
GPU 工作。當天先停止 VM，以免繼續累積運算費；
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
