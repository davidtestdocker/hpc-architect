# 模組 04：多節點網路與共享資料路徑

[能力路線](ROADMAP.md)｜職缺核心：網路設定與管理；支撐能力：叢集架構規劃。

## 這個模組在做什麼

把獨立 GPU VM 接入現有教學叢集，檢查兩台 VM 如何找到彼此、
能否連上服務、讀到相同資料，以及工作能否跨節點執行。
本模組也要在 GPU VM 上辨認實際裝置，留下可核對的節點與資料證據。

## 目前做到哪裡

| 節點 | 已確認的位址與位置 | 目前有的證據 |
|---|---|---|
| 控制節點 `instance-20260923-104239` | 台灣 `asia-east1-b`，`10.140.0.2` | 客體位址與路由輸出 |
| GPU 節點 `compute-gpu01` | 東京 `asia-northeast1-c`，`10.146.0.3` | 建機結果；使用者開機後的客體位址與路由輸出 |

**目前進度：** 已保存兩台 VM 各自的本機位址與路由輸出，還沒有驗證彼此連線。
下一步是在 GPU VM 查控制節點名稱 `instance-20260923-104239` 的解析結果。
歷史上曾停止 GPU VM；那次 `TERMINATED` 輸出不是現在的狀態。

## 要驗證的工作路徑

控制節點要把工作交給 GPU 節點，工作還要讀得到資料。
從「找到主機」到「工作完成」是不同關卡，不能用一條 `ping` 代替整條路徑。

| 關卡 | 用什麼看 | 要得到的證據 |
|---|---|---|
| 位址與路由 | `ip -br addr`、`ip route` | 各 VM 的私有 IP、介面與下一跳；有路由不等於服務可連 |
| 名稱與連線 | `getent hosts`、`ssh`、`ss` | 名稱解析到預期 IP、SSH 實際連線；必要時分查雲端及客體防火牆 |
| 共享資料 | `findmnt`、`namei -l`、兩端 UID/GID | 同一路徑可讀寫，掛載與逐層權限相符 |
| GPU 與工作 | `nvidia-smi`、實際工作輸出 | 裝置可見、工作取得資源且答案正確；看見 GPU 不等於排程已分配 |

NFS 讓兩台 VM 使用同一份檔案，但有單點故障與效能限制。
本模組的完成證據是兩台獨立 VM 互通、共享資料讀寫、跨節點工作，
以及 GPU 裝置辨認；單卡 VM 不代表多卡互連或 RDMA 已驗證。
可重跑設定與拓撲決策放在 [project/docs/](../project/docs/)。

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

## 2026-10-01：東京 GPU 節點建立

建成的節點是 `compute-gpu01`：`g2-standard-4`（4 vCPU、16 GiB、
一張 NVIDIA L4），位於東京 `asia-northeast1-c`。
使用 AlmaLinux 10、`default` VPC、40 GiB `pd-balanced` 開機磁碟；
只配置私有 IP，不配置 VM 服務帳戶。
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

### 建立後核對

以下命令唯讀查詢 VM 實際設定：

```bash
gcloud compute instances describe compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --format='json(name,status,zone,machineType,networkInterfaces,serviceAccounts,disks,resourcePolicies,terminationTime,maxRunDuration,instanceTerminationAction,scheduling)'
```

從實際回傳擷取必要欄位，省略其他 API 欄位：

```json
{
  "name": "compute-gpu01",
  "status": "RUNNING",
  "machineType": "https://www.googleapis.com/compute/v1/projects/project-78b8a95c-a2c0-461f-a08/zones/asia-northeast1-c/machineTypes/g2-standard-4",
  "networkInterfaces": [{"networkIP": "10.146.0.3"}],
  "disks": [{"boot": true, "diskSizeGb": "40", "autoDelete": true}],
  "scheduling": {
    "maxRunDuration": {"seconds": "7200"},
    "instanceTerminationAction": "STOP"
  }
}
```

**判讀：** 查詢當時為 `RUNNING`，私有 IP `10.146.0.3`，
回傳沒有外部 IP 或服務帳戶欄位。開機磁碟為 40 GiB；
`autoDelete: true` 表示刪除 VM 時會刪除該磁碟。
`7200` 秒與 `STOP` 是當時查得的單次執行限制及到時動作，
不能用這次建立後的查詢結果代表現在的 VM 狀態。

## 2026-10-01：依要求停止 VM

建機後當天先停止 VM，以免繼續累積運算費；
這個操作保留開機磁碟，日後可再啟動。

```bash
gcloud compute instances stop compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --quiet
```

停止命令的完成訊息：

```text
Updated [https://compute.googleapis.com/compute/v1/projects/project-78b8a95c-a2c0-461f-a08/zones/asia-northeast1-c/instances/compute-gpu01].
```

再以唯讀命令核對：

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
之後使用者自行開機；以下客體命令及輸出證明開機後進入過 GPU VM，
但沒有再查 Compute Engine 的最新 `status`。

## GPU VM 開機後：先核對客體網路位址

在 `compute-gpu01` 的終端執行 `ip -br addr`，確認實際啟用的網路介面
與客體系統取得的私有 IP，對照建機紀錄的 `10.146.0.3`。
這條命令只讀網路狀態，不改 VM、介面、服務或檔案。

```bash
ip -br addr
```

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             10.146.0.3/32 fe80::e8c5:bdc0:3c16:4b48/64
```

**判讀：** `eth0` 已啟用，客體私有 IPv4 `10.146.0.3`
與建機時的位址相符。介面上的 `/32` 不代表整個 VPC 子網的大小。

接著在同一台 GPU VM 查路由表，確認送往其他位址時會使用的下一跳。
這條命令只讀，不改路由、介面或檔案。

```bash
ip route
```

```text
default via 10.146.0.1 dev eth0 proto dhcp src 10.146.0.3 metric 100
10.146.0.1 dev eth0 proto dhcp scope link src 10.146.0.3 metric 100
```

**判讀：** `eth0` 使用 `10.146.0.1` 作預設下一跳，來源位址為
`10.146.0.3`。有路由只表示本機知道把封包交給誰，尚未證明控制節點可達。

### 下一條：控制節點名稱解析（尚未執行）

控制節點先前執行工作時的主機名是 `instance-20260923-104239`。
在 GPU VM 查系統目前會把這個名稱解析成哪個位址；
若沒有輸出或不是 `10.140.0.2`，先定位名稱解析設定，不直接假設網路故障。
這條命令只讀，不改 DNS、`/etc/hosts` 或網路設定。

```bash
getent hosts instance-20260923-104239
```
