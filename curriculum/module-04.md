# 模組 04：多節點網路與共享資料路徑

[能力路線](ROADMAP.md)｜職缺核心：網路系統設定與管理；支撐能力：叢集架構規劃。

## 先教會的概念

每個節點都需要可預期的位址、名稱、路由、時間和身分。位址可達不等於服務可用；DNS 解析成功也不等於防火牆允許連線。雲端防火牆與 VM 內部防火牆在不同層，排障要分開。管理、運算與儲存流量可共用教學網路，但在較大規模可能需要分開，原因是安全邊界、頻寬、延遲和故障影響。GPU 節點還要規劃資料如何從儲存經網路與主機記憶體送到 GPU；單卡 GCP VM 不能假裝驗證了實體交換器、RDMA 或多卡互連。

共享資料路徑有伺服器匯出、用戶端掛載、UID/GID 與逐層權限。NFS 能作教學案例，但不能代表所有 HPC 儲存；要知道它的單點故障、快取和效能限制。時間不一致或使用者身分不一致也可能表現為叢集服務或檔案存取失敗。

例：getent hosts 能解析 compute01，但 SSH 連不上時，下一步應查路由、服務監聽與兩層防火牆；不能再把它單純歸咎為 DNS。

## 指令先講清楚，再操作

ip addr 查介面位址，ip route 查路由；getent hosts 查系統實際名稱解析，ss 查本機監聽或連線；ssh 驗證身分和連線；findmnt 查掛載，namei -l 看路徑每層權限。GPU VM 上的 nvidia-smi 查驅動可否辨認裝置與當下狀態，不能單憑它證明 Slurm 已正確分配 GPU。這些命令各自只能觀察一層，不能單憑 ping 成功宣布整條工作路徑正常。雲端規則與客體防火牆的檢查方法依實際環境選定。

## 實作主線與過關證據

新增 VM 前先確認學員實際 GPU 型號配額、vCPU 配額、區域／zone、即時容量、機型完整費用、預計開機時數及網路範圍；配額不保證一定能建立。候選是一台一張卡的 G2／L4 compute-gpu01，若實際配額、價格或工作型態不合再比較其他機型。未經同意不建付費資源。先做控制／CPU／GPU 運算節點間的位址、名稱、時間、SSH 和所需連接埠驗證，再建立共享工作資料路徑。GPU VM 裝驅動前先核對映像和版本，安裝與可能重啟須另獲同意；以 nvidia-smi 辨認卡型和驅動，以一般工作帳號驗證資料讀寫。安排可復原的名稱解析、連線或 NFS 故障，從觀察到定位、修復與復測；事前寫明回復方式，不暴露叢集服務到公網。

project/docs/ 應有實際拓撲、位址與通訊矩陣、身分／權限設計、GPU VM 型號與成本假設；project/incidents/ 有真實故障紀錄。過關須有至少兩台獨立 VM（其中一台 GPU 節點）的互通、共享資料與裝置辨認證據，並能指出故障發生在哪一層。只有一台 CPU VM 時可以先學概念與單機部分，但 GPU 和跨節點能力標為未驗證。

開始帶練前，先在本文件追加本次確定的 VM 指令、目的及檔案／雲端資源影響；執行後記錄輸出與判讀。

## 第二節點規劃的已知條件

目前控制節點位於 `asia-east1-b`，使用專案
`project-78b8a95c-a2c0-461f-a08`。候選 GPU 節點為
`g2-standard-4`，配備 4 vCPU、16 GiB 主記憶體與一張 NVIDIA L4。

2026-09-30 以目前 VM 的服務帳戶查詢 Compute Engine API：
專案全域 `GPUS_ALL_REGIONS` 上限 1、使用 0；
`CPUS_ALL_REGIONS` 上限 24、使用 2，尚餘 22。
`asia-east1` 的 `NVIDIA_L4_GPUS` 上限 1、使用 0，
`CPUS` 上限 100、使用 2，`INSTANCES` 上限 24、使用 1。
因此配額數量足以容納候選的一張 L4、4 vCPU VM；
但 G2 機型是否能建立，仍取決於目標 zone 的即時容量與其他限制。
[Google 官方 GPU 地點表](https://docs.cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
列出 `asia-east1-b` 提供 G2。

建立第二台 VM 前仍須核對機型及磁碟費用、預計開機時間和預算。
目前尚未建立第二節點，跨節點與 GPU 工作均未驗證。

## 本次網路基線檢查

在現有控制 VM 執行 `ip -br addr`，確認目前介面名稱、狀態和私有位址，
以便之後對照新節點的通訊。這是唯讀命令，不修改檔案、服務或雲端資源。

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             10.140.0.2/32 fe80::2725:28ff:b62c:9e10/64
```

`eth0` 已啟用，私有 IPv4 位址為 `10.140.0.2`。
介面顯示 `/32`，不能單靠這行推論 VPC 子網範圍；還需檢查實際路由與雲端子網設定。

接著執行唯讀 VM 指令 `ip route`，查看預設閘道與現有路由；
不修改檔案、服務或雲端資源。

```text
default via 10.140.0.1 dev eth0 proto dhcp src 10.140.0.2 metric 100
10.140.0.1 dev eth0 proto dhcp scope link src 10.140.0.2 metric 100
```

`10.140.0.1` 是目前 VM 的預設下一跳；
Compute Engine API 顯示它位於 `default` VPC 的 `asia-east1/default` 子網，
子網 CIDR 為 `10.140.0.0/20`。現有 VM 的開機映像為
`almalinux-cloud/almalinux-10-v20260811`，10 GiB `pd-balanced` 磁碟。
G2 機型要求開機磁碟至少 40 GiB，候選新節點因此不能直接複製目前磁碟大小。

VM 的服務帳戶只有 `compute.readonly` 等唯讀 API scope；
起初 root 與一般帳號的 `gcloud` 都沒有已登入的使用者帳號，
因此當時無法代為建立 GPU VM。
之後 root 執行 `gcloud auth login --no-launch-browser` 並完成瀏覽器授權；
這條命令在 root 的 gcloud 設定中保存登入憑證，沒有建立 VM。
授權碼及 token 未寫入此文件。

## GPU 節點建立測試的準備

候選 `compute-gpu01`：`asia-east1-b` 的 `g2-standard-4`，
使用現有 `default` VPC／子網、相同的 AlmaLinux 10 映像、
40 GiB `pd-balanced` 開機磁碟。只給私有位址，從現有 VM 走內網；
不配置外部 IP 或 VM 服務帳戶。建立後才知道當下是否有容量。
設定最長執行 2 小時後自動停止，以控制測試時數；
停止後磁碟仍計費，後續若不使用須刪除 VM 與磁碟。

最初使用的建機命令如下。成功時會建立付費 VM 與磁碟，
並消耗一張 L4 及四顆 vCPU 的配額；
執行前先核對登入身分、當時價格與可接受費用。

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

首次送出建機命令時，gcloud 在本機參數檢查階段回報：
使用 `--no-service-account` 時也必須指定 `--no-scopes`。
未送出雲端建機請求，故上方命令已補齊參數後再嘗試。

補齊參數後實際送出 `asia-east1-b` 建機請求，Compute Engine 回報
`ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS`：
`g2-standard-4` 加一張 L4 在該 zone 當下無庫存。
這是即時容量不足，非配額不足；請求未建立 VM。

接著只把同一建機命令的 `--zone` 依序改為 `asia-east1-a`、
`asia-east1-c` 進行容量測試；其餘機型、VPC、磁碟、私有 IP、
無服務帳戶及 2 小時自動停止設定相同。
每次只在前一個 zone 未建成時才試下一個，避免建立兩台付費 VM。

`asia-east1-a` 與 `asia-east1-c` 的 L4／G2 請求也都回報
`ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS`；三個 zone 都未建成 VM。
`asia-east1-c` 額外提醒映像原大小 10 GiB、開機磁碟指定 40 GiB，
若映像未自動擴展根分割區，建成後需另行檢查；這不是此次失敗原因。

同區域的 `NVIDIA_T4_GPUS` 配額為 1、使用 0。
下一個容量候選改用 `asia-east1-a` 的 N1／T4，
依 [Google 官方 GPU 地點表](https://docs.cloud.google.com/compute/docs/regions-zones/gpu-regions-zones)
此 zone 支援 N1＋T4；其餘私有網路、映像、40 GiB 磁碟、
不配外部 IP／服務帳戶及 2 小時自動停止設定維持相同。
此命令若成功將建立付費 VM 與磁碟並消耗一張 T4、四顆 vCPU 配額。

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

`asia-east1-a` 的 N1＋T4 請求亦回報 `ZONE_RESOURCE_POOL_EXHAUSTED`，
沒有建成 VM。下一步只把同一命令的 `--zone` 改為 `asia-east1-c` 再試一次；
該 zone 也列為 N1＋T4 可用地點，其餘設定與費用上限不變。

`asia-east1-c` 的 N1＋T4 請求同樣回報 `ZONE_RESOURCE_POOL_EXHAUSTED`。
至此同區域三個 L4／G2 zone 與兩個 T4／N1 zone 的建機請求均未成功，
沒有建立 VM 或磁碟。

Compute Engine API 顯示東京 `asia-northeast1`、
新加坡 `asia-southeast1`、首爾 `asia-northeast3` 和孟買 `asia-south1`
各有 L4 區域配額 1、已用 0。**尚未在這些區域送出建機請求。**
下次可先核對東京 `asia-northeast1-a` 的當時配額、費用與容量；
官方 GPU 地點表列出該 zone 支援 G2。若決定建立，
命令可沿用前述 G2 設定，將 `--zone` 改為 `asia-northeast1-a`；
若成功就不再嘗試其他 zone。
跨區域 VM 會使用東京的子網；與台灣控制 VM 的流量可能增加延遲與費用，
後續量測必須註明。若建立，仍使用 2 小時自動停止及私有 IP 設定。

2026-09-30 依要求暫停：今天未建立 GPU VM，也未留下新磁碟。
下次先確認登入仍有效、目標區域配額與預算，再嘗試跨區域建機；
成功後才進行私網互通、共享資料和 GPU 裝置辨認。

## 2026-10-01 東京 GPU 節點建機

已確認目前登入帳號有效，專案中沒有 `compute-gpu01`；東京區域的
`NVIDIA_L4_GPUS` 配額為 1、已用 0，`CPUS` 配額為 100、已用 0，
`INSTANCES` 配額為 24、已用 0。配額不保證 zone 即時有容量。
東京 `asia-northeast1-a` 支援 G2。以下命令嘗試建立一台
`g2-standard-4` GPU VM；成功時會建立 40 GiB 開機磁碟並開始計費。
沿用私有 IP、無 VM 服務帳戶、2 小時後停止的設定；停止後磁碟仍計費。
需要清除費用時，後續刪除 VM 時也要確認刪除其開機磁碟。

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

`asia-northeast1-a` 的建機請求回報
`ZONE_RESOURCE_POOL_EXHAUSTED_WITH_DETAILS`：該 zone 當下沒有
`g2-standard-4` 加一張 L4 的容量，沒有建立 VM。錯誤訊息建議改試
`asia-northeast1-c` 或 `asia-northeast1-b`。

下一次請求只把上述命令的 `--zone` 改為 `asia-northeast1-c`；
其餘機型、映像、磁碟、網路與 2 小時停止設定相同。
若成功會在該 zone 建立付費 VM 和開機磁碟。

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

`asia-northeast1-c` 的請求成功建立 `compute-gpu01`，建機輸出的必要欄位：

```text
NAME           ZONE               MACHINE_TYPE   INTERNAL_IP  EXTERNAL_IP  STATUS
compute-gpu01  asia-northeast1-c  g2-standard-4  10.146.0.3               RUNNING
```

建機時另有提醒：40 GiB 磁碟大於 10 GiB 映像；若作業系統未自動擴展根分割區，
進入 VM 後須再檢查檔案系統大小。此提醒不影響建機成功。

建立後以唯讀命令核對實際設定：

```bash
gcloud compute instances describe compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --format='json(name,status,zone,machineType,networkInterfaces,serviceAccounts,disks,resourcePolicies,terminationTime,maxRunDuration,instanceTerminationAction,scheduling)'
```

結果顯示 VM 為 `RUNNING`，私有位址 `10.146.0.3`、沒有外部位址；
`scheduling.maxRunDuration.seconds` 為 `7200`，
`instanceTerminationAction` 為 `STOP`，即執行滿 2 小時後停止。
開機磁碟為 40 GiB、`autoDelete: true`，刪除 VM 時會一併刪除；
單純停止 VM 時磁碟仍保留並計費。回傳結果沒有 `serviceAccounts` 欄位。
目前只確認雲端 VM 與設定，尚未登入客體系統，也未驗證驅動、
私網互通、共享資料或 GPU 工作。

## 停止 GPU VM

目前不使用 GPU 節點，先執行下列命令停止
`asia-northeast1-c` 的 `compute-gpu01`，避免繼續累積 VM 運算費。
這會關閉 VM；40 GiB 開機磁碟保留並繼續計費，日後可再啟動。
停止後再用唯讀查詢確認狀態。

```bash
gcloud compute instances stop compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --quiet
```

```bash
gcloud compute instances describe compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --format='value(status)'
```

停止命令回報 `Updated`；隨後狀態查詢回傳 `TERMINATED`，
確認 VM 已停止。開機磁碟仍保留，未刪除 VM 或磁碟。
