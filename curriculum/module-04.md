# 模組 04：多節點網路與共享資料路徑

[能力路線](ROADMAP.md)｜職缺核心：網路設定與管理；支撐能力：叢集架構規劃。

## 這個模組在做什麼

這個模組要讓台灣的控制節點和東京的 GPU 節點一起工作。
最後要交付：兩台 VM 能互連、讀寫同一份資料，
工作能實際跨節點執行，並確認 GPU 裝置。
先交代為什麼建 GPU VM、連線時遇到什麼需求，再看驗證結果與實際指令。

## 從跨節點工作到對外連線

| VM | 位置 | 私有 IP | 角色 |
|---|---|---|---|
| `instance-20260923-104239` | 台灣 | `10.140.0.2` | 控制節點 |
| `compute-gpu01` | 東京 | `10.146.0.3` | GPU 節點 |

**先處理叢集內的連線。** 為了讓控制節點以後能把工作交給 GPU 節點，
先建立東京 GPU VM，並確認它能連上台灣控制節點。
兩台 VM 在同一個 Google Cloud 虛擬網路（VPC）裡，
用私有 IP `10.146.0.3` 和 `10.140.0.2` 通訊。
從東京 GPU VM 對台灣控制節點 `10.140.0.2` 執行 `ping`：
送出三個測試封包，收到三個來自 `10.140.0.2` 的回覆。
這表示兩台 VM 當時能透過私有網路交換封包。

**接著出現另一個需求：GPU VM 要連 GitHub。**
往後若要從網際網路取得安裝所需的軟體，GPU VM 必須能主動連外。
建 VM 時使用 `--no-address`，所以它只有私有 IP，沒有外部 IP。
私有 IP 可以用於上述兩台 VM 間的連線，卻不能直接當作
GitHub 回覆時使用的網際網路位址。

**因此才新增東京的 Public Cloud NAT。** 它替 GPU VM 的對外連線
使用一個外部 IP，讓 GitHub 的回應能回到 GPU VM。
建立後，在 GPU VM 對 GitHub 發送 HTTPS 請求，回報 HTTP `200`。
這項結果證明 GPU VM 的對外出口可用。

### Public Cloud NAT 和 Cloud Router 到底做什麼

**NAT 是改寫連線位址的機制。** GPU VM 用私有 IP `10.146.0.3`
發出連線；Google Cloud 把對外顯示的來源改成 NAT 的外部 IP，
記住這條連線屬於 GPU VM，再把 GitHub 的回應送回它。
Public Cloud NAT 只允許這種主動連線及其回應；
外部主機不能因此主動連入 GPU VM。
[Public NAT 官方說明](https://docs.cloud.google.com/nat/docs/public-nat)

**Cloud Router 保存 NAT 的設定。** 建立這個 NAT 時，Google Cloud
要求先有同一區域、同一 VPC 的 Cloud Router。
它不是另一台 VM，也不是封包會經過的實體路由器。
這次真正要解決「沒有外部 IP 怎麼連 GitHub」的是 Public Cloud NAT；
Cloud Router 是放置其設定的必要資源。
[Cloud Router 官方說明](https://docs.cloud.google.com/network-connectivity/docs/router/concepts/overview)

## 控制節點的網路基線

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

第一行 `default via 10.140.0.1 dev eth0` 的意思是：
控制節點要連到路由表沒有另外列出的位址時，
先從 `eth0` 把封包交給 `10.140.0.1`，由網路繼續轉送。
例如要連東京 GPU VM `10.146.0.3`，封包的目的地仍是
`10.146.0.3`；`10.140.0.1` 只是它先交給的位址。

## 東京 GPU 節點的配置

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

## GPU VM 的客體網路位址與連線

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
與建機時的位址相符。

### 直接測試控制節點的私有 IP

在 GPU VM 向控制節點已知的私有 IP `10.140.0.2` 送三個 ICMP 封包。
這繞過名稱解析，先檢查網路路徑是否容許這種流量；
命令只產生少量封包，不改設定、檔案或雲端資源。

```bash
ping -c 3 -W 2 10.140.0.2
```

實際收到的輸出如下；提供的紀錄沒有結尾統計行：

```text
PING 10.140.0.2 (10.140.0.2) 56(84) bytes of data.
64 bytes from 10.140.0.2: icmp_seq=1 ttl=64 time=39.6 ms
64 bytes from 10.140.0.2: icmp_seq=2 ttl=64 time=38.6 ms
64 bytes from 10.140.0.2: icmp_seq=3 ttl=64 time=38.5 ms
```

**判讀：** 三個序號都有來自控制節點私有 IP 的回覆，
各次往返約 38–40 ms。ICMP 封包可往返。

### 看這條連線的路由

在同一台 GPU VM 執行 `ip route`，查看封包送往其他位址時，
系統會先交給哪個位址。這條命令只讀，不改網路設定。

```bash
ip route
```

```text
default via 10.146.0.1 dev eth0 proto dhcp src 10.146.0.3 metric 100
10.146.0.1 dev eth0 proto dhcp scope link src 10.146.0.3 metric 100
```

**判讀：** 對控制節點 `10.140.0.2` 的封包，GPU VM 從 `eth0`
交給 `10.146.0.1`，再由網路轉送。

## 東京 GPU VM 的對外出口：建立與驗證

GPU VM 位於東京 `default` 子網 `10.146.0.0/20`。
建立的 NAT 只涵蓋這個子網的主要 IP 範圍，不涵蓋台灣控制節點。
同一範圍內日後新增的無外部 IP VM，也可能使用這個出口。

Cloud Router 名稱為 `gpu-egress-router`；掛在其上的 Public Cloud NAT
名稱為 `gpu-egress-nat`。NAT 外部 IP 由 Google Cloud 自動分配，
本紀錄沒有查到實際數值。NAT 及使用的外部 IP 可能持續計費；
若要移除此出口，須考慮同一範圍內其他 VM 的連線。
[Cloud NAT 計價](https://cloud.google.com/nat/pricing)

### 建立與核對紀錄

以下命令在控制節點執行，作用於專案
`project-78b8a95c-a2c0-461f-a08`，不更改 GPU VM 的外部 IP、
入站防火牆或客體檔案。

**建立 Cloud Router：**

```bash
gcloud compute routers create gpu-egress-router \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --region=asia-northeast1 \
  --network=default \
  --quiet
```

```text
Creating router [gpu-egress-router]...
......done.
NAME               REGION           NETWORK
gpu-egress-router  asia-northeast1  default
```

**判讀：** Router 已建立在東京 `default` VPC，用來承載後面的 NAT 設定。

**建立 Public Cloud NAT：**

```bash
gcloud compute routers nats create gpu-egress-nat \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --router=gpu-egress-router \
  --region=asia-northeast1 \
  --nat-custom-subnet-ip-ranges=default \
  --auto-allocate-nat-external-ips \
  --quiet
```

```text
Creating NAT [gpu-egress-nat] in router [gpu-egress-router]...
......done.
```

**判讀：** NAT 建立命令成功；下方記錄其涵蓋範圍與連線結果。

**核對 NAT 設定：**

```bash
gcloud compute routers nats describe gpu-egress-nat \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --router=gpu-egress-router \
  --region=asia-northeast1
```

實際輸出中與出口範圍有關的欄位：

```text
name: gpu-egress-nat
natIpAllocateOption: AUTO_ONLY
subnetworks:
- name: https://www.googleapis.com/compute/v1/projects/project-78b8a95c-a2c0-461f-a08/regions/asia-northeast1/subnetworks/default
  sourceIpRangesToNat:
  - PRIMARY_IP_RANGE
type: PUBLIC
```

**判讀：** NAT 類型為 Public，對外 IP 自動分配；
作用範圍是東京 `default` 子網的主要 IP 範圍。

### 從 GPU VM 驗證 HTTPS 對外連線

在 GPU VM 向 GitHub 發送 HTTPS HEAD 請求，只讀取回應標頭，
確認 DNS、TCP、TLS 與 HTTP 路徑可用。
`--max-time 15` 限制等待十五秒；命令不下載檔案、不改客體設定。

```bash
curl --head --max-time 15 https://github.com
```

**實際回報：** HTTP `200`；本次沒有提供完整回應標頭，
因此不補寫其他 `curl` 輸出。

**判讀：** GPU VM 完成 HTTPS 請求，GitHub 回傳成功狀態；
對外路徑可用。
