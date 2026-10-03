# 模組 04：多節點網路與共享資料路徑

[能力路線](ROADMAP.md)｜職缺核心：網路設定與管理；支撐能力：叢集架構規劃。

## 這個模組在做什麼

實際叢集的控制節點要把工作交給計算節點，計算節點還要讀到工作所需的
程式與輸入資料，並把結果留在控制節點能取得的位置。如果兩台機器只能
互相 `ping`，卻不能登入、找不到資料或無法執行工作，叢集仍不能使用。

這個模組用台灣的控制節點與東京的 GPU 節點，處理三個實際工作問題：

| 工作問題 | 本模組要交付的證據 | 對目標職缺的幫助 |
|---|---|---|
| 節點之間能否連線並由控制節點操作計算節點 | 私有網路連線、SSH 登入與遠端命令 | 網路設定、連線故障定位與節點管理 |
| 工作在另一台機器上能否取得同一份輸入並留下結果 | 共享資料路徑及跨節點工作結果 | 叢集資料路徑規劃與工作部署 |
| GPU 節點是否真的辨認到 GPU | 驅動與裝置辨認結果 | GPU 節點建置與資源驗收 |

**目前已做到：** 兩台 VM 的私有網路可互通；控制節點能以 SSH 登入
GPU VM 並執行命令；GPU VM 能連外取得軟體，驅動能辨認一張 L4。
這些結果分別練到連線分層判斷（網路通不等於登入成功）、
節點登入金鑰配置、無外部 IP 的出口設計，以及 GPU 節點驗收。
共享資料與跨節點工作還沒有實作結果。

**共享資料路徑**是兩台機器各自用同一個目錄位置，讀寫同一份實際資料。
例如控制節點準備工作輸入，GPU 節點執行時讀取該輸入，完成後把結果
寫回同一處，控制節點就能收集結果。這解決了工作換到另一台機器就
找不到檔案、或各節點複製品不同步的問題。這會用 NFS 作第一個案例：
一台 VM 提供資料目錄，另一台 VM 掛載後使用。它是工作資料的通道，與 SSH
用來登入和執行遠端命令的用途不同；此處先解釋目的，尚未把共享資料
或跨節點工作寫成已完成。

**這次的實作範圍與限制：** 在現有兩台 VM 上，由台灣控制節點提供
`/srv/hpc-share`，東京 GPU VM 透過私有網路掛載，只用小型工作檔確認
兩邊讀寫同一份資料。已量到跨區往返約 35–40 毫秒；NFS 的多次檔案操作
會反覆經過這條路徑，因此不能把這次結果當成低延遲或高吞吐量儲存的證據。
跨區傳輸可能產生費用；控制節點若停止，GPU VM 也無法讀取這個共享目錄。
這是共享資料機制的實作與故障判斷練習，不是生產規模的儲存設計。

Slurm 決定工作在哪個節點執行；NFS 讓不同節點能從共享目錄讀寫工作檔案。
兩者可以搭配，但 NFS 不負責排程，Slurm 也不會替工作自動同步檔案。
這次在已有的兩台 VM 上設定 NFS，是為了確認匯出、掛載、權限與實際資料
讀寫。Google Cloud Cluster Toolkit 可以自動部署與掛載既有 NFS；
它是後續重建叢集時可用的自動化工具，不是另一種共享檔案協定。

**安裝準備：** 控制節點與 GPU VM 均已安裝
`nfs-utils-1:2.8.3-5.el10_2.x86_64`，兩次套件交易皆回報 `Complete!`。
此時尚未設定匯出目錄、啟動 NFS 服務或掛載共享目錄。

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

為確認目前的 VM 位址，唯讀查詢狀態、私有 IP 與 VM 外部 IP：

```bash
gcloud compute instances describe compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --format='value(status,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)'
```

```text
RUNNING  10.146.0.3
```

第三個欄位（VM 外部 IP）為空：**GPU VM 本身沒有外部 IP**。
前述 Public Cloud NAT 使用的外部 IP 不會掛在 VM 的網路介面上。

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

Cloud Router 名稱為 `gpu-egress-router`；掛在其上的 Public Cloud NAT
名稱為 `gpu-egress-nat`，為沒有外部 IP 的 GPU VM 提供對外出口。

### 建立紀錄

以下命令在控制節點執行，建立東京 GPU VM 的對外出口。

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

**判讀：** NAT 建立成功；下方用 GPU VM 的對外連線檢查效果。

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

## 從控制節點登入 GPU VM

在控制節點執行下列命令，以目前帳號登入 `10.146.0.3`，
並讓 GPU VM 回傳自己的主機名。首次連線可能詢問主機金鑰，
接受後會寫入控制節點的 `~/.ssh/known_hosts`；登入會留下 SSH 日誌。

```bash
ssh -o ConnectTimeout=5 10.146.0.3 hostname
```

實際輸出中的關鍵行：

```text
ED25519 key fingerprint is SHA256:lauNURUrtIZzUXcqNIrRCrITbYvmuZ4rK57HF7cT/6c.
Warning: Permanently added '10.146.0.3' (ED25519) to the list of known hosts.
root@10.146.0.3: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

控制節點當時以 `root` 帳號嘗試登入；GPU VM 的 SSH 服務有回應，
但拒絕了這個帳號提供的認證。主機金鑰已寫入控制節點的 `~/.ssh/known_hosts`。

專案 SSH 登入設定列有帳號 `a2264`。在控制節點改用該帳號測試登入，
成功時讓 GPU VM 回傳主機名。`BatchMode=yes` 不詢問密碼；
命令不改 VM 設定或檔案，GPU VM 可能記錄一次登入嘗試。

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 a2264@10.146.0.3 hostname
```

```text
a2264@10.146.0.3: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

`a2264` 的登入認證也被拒絕；SSH 服務有回應，問題位於認證階段。
控制節點後續 `ping` GPU VM 三次皆收到回覆，但 SSH 已回報認證拒絕；
這個 ICMP 結果沒有改變故障定位。

### 修復登入並驗證遠端執行

控制節點的 `root` 只有 `known_hosts`，`a2264` 的 `.ssh` 目錄只有
`authorized_keys`；兩者都沒有可用於登入 GPU VM 的私鑰。
因此在控制節點替 `a2264` 建立專用金鑰，再把**公鑰**加入
`compute-gpu01` 的執行個體中繼資料；原有的專案共用 SSH 金鑰未修改。

在控制節點建立金鑰：

```bash
sudo -u a2264 -- ssh-keygen -t ed25519 -N '' \
  -f /home/a2264/.ssh/hpc_gpu_ed25519 \
  -C a2264@instance-20260923-104239
```

輸出確認私鑰位於 `/home/a2264/.ssh/hpc_gpu_ed25519`，
公鑰位於同名 `.pub` 檔，指紋為
`SHA256:AMM2zBstxpEzT/150e/m12tGzgOEC6dt+pQ51rgWpWw`。
私鑰只留在控制節點。

把公鑰整理成 `a2264:ssh-ed25519 ...` 的執行個體中繼資料格式；
這條命令沒有終端輸出：

```bash
awk '{print "a2264:" $0}' /home/a2264/.ssh/hpc_gpu_ed25519.pub \
  > /tmp/compute-gpu01-a2264-ssh-keys-20261003
```

只更新 GPU VM 的 `ssh-keys` 執行個體中繼資料：

```bash
gcloud compute instances add-metadata compute-gpu01 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --metadata-from-file=ssh-keys=/tmp/compute-gpu01-a2264-ssh-keys-20261003 \
  --quiet
```

```text
Updated [https://www.googleapis.com/compute/v1/projects/project-78b8a95c-a2c0-461f-a08/zones/asia-northeast1-c/instances/compute-gpu01].
```

最後從控制節點以 `a2264` 身分登入並執行遠端命令：

```bash
sudo -u a2264 -- ssh -i /home/a2264/.ssh/hpc_gpu_ed25519 \
  -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=5 a2264@10.146.0.3 hostname
```

```text
Warning: Permanently added '10.146.0.3' (ED25519) to the list of known hosts.
compute-gpu01
```

`compute-gpu01` 是 GPU VM 回傳的主機名；控制節點現已能以
`a2264` 金鑰登入 GPU VM 並執行遠端命令。

## 確認 GPU VM 能否辨認裝置

以下 GPU 驅動操作當時從 GPU VM 自己的終端執行，
不是控制節點透過 SSH 遠端執行。

在 GPU VM 執行 NVIDIA 驅動提供的 `nvidia-smi -L`，
列出驅動目前辨認到的 GPU 型號與識別碼。
這條命令只讀，不修改 VM 設定；若工具不存在或驅動無法工作，
輸出會指出下一步需查的是工具或驅動。

```bash
nvidia-smi -L
```

```text
-bash: nvidia-smi: command not found
```

目前系統找不到 `nvidia-smi` 指令。這是工具可用性的結果，
接著直接查 PCI 裝置，確認 GPU 硬體是否呈現在 VM 裡。

Linux 在 `/sys/bus/pci/devices/` 列出目前辨認到的 PCI 裝置；
每個 `vendor` 檔案記錄廠商代碼，`0x10de` 代表 NVIDIA。
在 GPU VM 讀取這些檔案並尋找 NVIDIA 代碼，不修改裝置或設定。

```bash
grep -H '^0x10de$' /sys/bus/pci/devices/*/vendor
```

```text
/sys/bus/pci/devices/0000:00:03.0/vendor:0x10de
```

VM 的 PCI 清單中有一個 NVIDIA 裝置（`0000:00:03.0`）。
硬體已呈現在客體系統裡；下一步需安裝驅動與 `nvidia-smi` 工具，
讓 GPU 能實際供計算程式使用。

## GPU 驅動安裝

已在 GPU VM 安裝套件庫設定包 `almalinux-release-nvidia-driver-10-5.el10_1.x86_64`；
本次一併安裝 `epel-release-10-6.el10.noarch`、
`selinux-policy-extra-42.1.18-4.el10_2.3.noarch`、
`selinux-policy-targeted-extra-42.1.18-4.el10_2.2.noarch`。
套件交易回報 `Complete!`。

GPU VM 的驅動安裝交易回報 `Complete!`；與 GPU 使用直接相關的已安裝套件：

| 套件 | 版本 |
|---|---|
| `nvidia-open-kmod`、`kmod-nvidia-open` | `615.71.09-1.el10_2` |
| `nvidia-driver`、`nvidia-driver-cuda` | `3:615.71.09-1.el10` |

安裝後要重開 GPU VM，讓新驅動隨開機載入；這會暫時中斷
GPU VM 的終端連線，不影響控制節點或雲端網路設定。

```bash
reboot
```

`reboot` 沒有可保存的終端輸出；重新進入 GPU VM 後，`a2264` 執行：

```bash
nvidia-smi -L
```

```text
GPU 0: NVIDIA L4 (UUID: GPU-a04f3d30-d585-9db4-0b68-795091a5d8ce)
```

NVIDIA 驅動已能辨認一張 L4，且一般帳號 `a2264` 能讀到裝置資訊。

## NFS 共享：先確認帳號身分

NFS 讀寫權限會用數字 UID／GID 判斷。先在 GPU VM 查 `a2264` 的身分，
再對照控制節點，避免掛載後因兩邊同名帳號的數字不同而無法寫入。
這條命令只讀帳號資訊，不更改檔案、服務或雲端資源：

```bash
id a2264
```

```text
uid=1000(a2264) gid=1005(a2264) groups=1005(a2264),4(adm),39(video),1000(google-sudoers),1001(dip),1002(docker),1003(lxd),1004(plugdev)
```

GPU VM 的 UID/GID 是 `1000/1005`，與控制節點先前查得的值相同。
這次讓 `a2264` 擁有共享目錄即可讀寫，不需要讓所有帳號都能寫。

### 建立共享目錄

在控制節點以 root 建立 `/srv/hpc-share`，設為 `a2264` 擁有、
權限 `0750`：擁有者能讀寫與進入，群組只能讀取與進入，其他帳號無權限。
命令只建立或調整這個目錄，不啟動服務或修改雲端資源；
成功時不會有終端輸出。

```bash
install -d -o a2264 -g a2264 -m 0750 /srv/hpc-share
```

執行成功，終端沒有輸出。`/srv/hpc-share` 已建立，之後由控制節點
提供給 GPU VM 掛載；此時尚未啟動 NFS。

### 設定允許掛載的節點

NFS 的「匯出」是指定哪個本機目錄能被哪些遠端主機掛載。
[匯出設定檔](../project/nfs/hpc-share.exports) 只列 GPU VM 私有 IP
`10.146.0.3`，允許它讀寫 `/srv/hpc-share`；設定檔中的註解說明其餘選項。
在控制節點以 root 將這份設定複製到 `/etc/exports.d/`：

```bash
cp /root/hpc-arch/project/nfs/hpc-share.exports /etc/exports.d/hpc-share.exports
```

這條命令只新增或覆寫 `/etc/exports.d/hpc-share.exports`，
不會立即啟動 NFS 服務；成功時沒有終端輸出。

執行成功，終端沒有輸出；控制節點已有匯出設定檔。

### 啟動控制節點的 NFS 服務

在控制節點以 root 啟動 `nfs-server`，並設定重開機後自動啟動。
服務會讀取上述匯出設定，讓 GPU VM 能透過私有網路掛載共享目錄；
這一步不修改 GPU VM。若要停止並取消開機自動啟動，
可在控制節點執行 `systemctl disable --now nfs-server`。

```bash
systemctl enable --now nfs-server
```
