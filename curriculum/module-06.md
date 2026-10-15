# 模組 06：叢集維運、Zabbix 監控與故障復原

[能力路線](ROADMAP.md)｜對應叢集維運、故障定位與管理能力。

## 要解決的問題與交付物

已有的控制節點和 GPU 運算節點曾透過 Slurm 完成可核對答案的工作。
模組 05 已把 OpenStack 的 `compute-cpu01` 納入為獨立 CPU 運算節點，
並以 `srun hostname` 驗證基本排程與工作啟動。
本模組開始故障演練前須先核對兩台運算節點當時的在線狀態與工作結果。
運算節點出問題時，只看到服務重啟或告警消失，仍無法確定排程與計算已恢復。
本模組要建立一條可重跑的維運流程，並指出各階段由誰負責。

交付一條完整的證據鏈：**健康訊號 → 故障告警 → 排程隔離與定位 →
修復 → 恢復條件 → 工作結果核對**。Zabbix 要實際收集叢集資料並產生
Problem 與 OK 事件；單張儀表板截圖或單次服務重啟不算完成。
模組 07 會把 GKE 的工作與告警接入這套事件處理流程。

## 目前狀態與已有基礎

**已完成本模組的節點、佇列與三台 Slurm 服務基準查詢。**
模組 01 已做過單節點控制服務停止與復原；
模組 02 已有提交前健檢 CLI；模組 05 已用 Ansible 部署原有兩節點 Slurm，
並執行可核對答案的 L4 工作。`compute-cpu01` 已在 Slurm `cpu` 分區註冊，
基本工作已從控制節點派送到該客體。模組 05 最後一次核對時，
CPU 與 GPU 兩台獨立運算節點同時顯示 `idle`。
這些是先前成果；故障演練前仍須重新核對
VM、服務、工作及費用狀態，不把先前成功當成目前在線。
本模組重點是**運算節點故障的持續監控、告警與工作恢復**，不重做
單節點服務演練。節點恢復不代表故障中的工作會從中斷處繼續；
本次以重新提交已知答案工作核對完整通路。若兩台獨立運算節點
都可接受同一類 CPU 工作，再驗證其中一台故障時新工作是否能到另一台；
控制節點兼任的 `debug` 分區不能冒充第二台獨立運算節點。
若評估自動重新排隊，
還要指出它是否從頭執行，以及輸出是否會重複或覆寫。

## 需要看見哪些狀態

| 層次 | 要回答的問題 | 本模組要留下的證據 |
|---|---|---|
| 服務 | Slurm 服務是否運作？程序退出時會否自動重啟？ | 實際服務設定、狀態、必要日誌與時間 |
| 排程 | 故障節點何時停止接工作，何時重新開放？ | Slurm 節點狀態、原因、健康條件與變更紀錄 |
| 監控 | Zabbix 是否持續辨認故障與恢復？ | 故障前後資料、觸發條件、Problem 與 OK 事件 |
| 工作 | 故障期間新 CPU 工作能否到另一台獨立運算節點？修復後原節點能否再接工作？ | 同類工作在兩台運算節點的資源條件、輸入、執行主機、退出狀態與答案 |

Zabbix 的 **item** 是持續收集的數值或狀態，**trigger** 判斷何時有問題，
**event** 記錄問題出現與恢復的時間。監控資料與 Slurm 自己的狀態
要互相對照。告警不等於修復；服務重新啟動後，仍須由實際工作驗證
排程與共享資料通路；若演練 GPU 節點，再核對 GPU 通路。

## 實作順序與過關證據

1. 確認模組 05 已讓 `compute-cpu01` 接受 Slurm CPU 工作，再核對當時
   控制節點、CPU／GPU 運算節點、Slurm 狀態、現有工作及自動重啟設定。
   若要驗證跨節點工作轉移，先證明兩台獨立運算節點都能接同一類 CPU 工作；
   GPU 節點若已停止，先確認啟動費用和本次使用時間。
2. 確認 Zabbix 版本、部署位置與資源需求，再部署監控。
   健康訊號須直接反映運算節點或 Slurm 能否接工作；記下採樣、
   告警與恢復條件，分清暫時失聯與需要排障的故障。
3. 核對 Slurm 對故障節點的隔離及重新開放條件，評估服務程序自動重啟、
   節點健康檢查與工作重新排隊是否適合目前叢集。對要啟用的機制，
   先說明觸發條件、重試上限或人工接手條件、對執行中工作的影響，
   再驗證效果；未啟用的機制只記原因，不寫成已具備的能力。
4. 選一個可復原的**運算節點故障**。確認沒有重要工作、估計影響，
   準備復原方式後才演練；不破壞驅動或硬體。具體故障及指令
   依當時服務與監控設定決定。只有完成兩台獨立運算節點的同類工作
   前置驗證，才把故障期間新工作落到另一台稱為跨節點轉移。
5. 留下同一次故障的 Zabbix Problem、Slurm 節點狀態、服務與必要日誌，
   說明誰偵測、誰隔離、誰修復。修復後核對 Slurm 重新接受工作與
   Zabbix OK 事件，再提交已知答案的 CPU 工作，核對節點、
   退出狀態及結果。若 GPU 節點在線且本次演練涉及它，另重跑已知答案
   GPU 工作；若有重試，核對輸出沒有錯誤重複或覆寫。

過關須能按時間串起**健康訊號、告警、隔離、原因、修復、重新開放與
工作結果**，並用證據區分自動動作與人工動作。跨節點轉移另須有
兩台獨立運算節點的同類工作證據；一張 GPU 無法證明 GPU 工作轉移。
只有服務恢復、
沒有排程狀態或工作結果，都不算完成。
事件紀錄需包含平台、時間、受影響節點與工作、健康訊號、處理者、
恢復條件與驗收結果，供後續 GKE 事件使用相同欄位對照。
Zabbix 的非敏感設定保存在 `project/monitoring/`；真實演練紀錄放在
`project/incidents/`。若現有健檢 CLI 缺少這次定位必需的跨節點檢查，
才擴充 `project/healthcheck/`，並驗證正常、故障及查詢失敗時的結果。

模組 07 沿用本模組的事件欄位與驗收順序，加入 GKE 工作及共同告警入口；
本模組先把現有 Slurm 叢集的流程做完整。
開始實作前，先在本文件記下確定要執行的命令、目標節點、影響及復原方式；
實際執行後才記錄輸出與判讀。

## 1. 先確認排程器眼中的節點狀態

**叢集裡誰做什麼：** Slurm 是這個叢集的工作排程系統。
控制節點 `10.140.0.2` 上的 `slurmctld` 是排程控制程序：
接收工作請求、決定交給哪台節點，並記錄節點是 `idle` 還是 `down`。
GPU VM `compute-gpu01` 和 CPU 客體 `compute-cpu01` 各自執行
`slurmd`，負責接收控制端分派的工作並在本機啟動程序。
控制端會與各節點的 `slurmd` 通訊，掌握節點是否回應及能否接工作，
再由 `slurmctld` 維護排程用的節點狀態。控制節點上執行的 `sinfo`
讀的是這份排程狀態，並非直接查詢每台運算節點的 systemd 服務狀態。
所以要查 `slurmctld` 程序是否在跑，就在控制節點查；
要查某台 `slurmd` 程序是否在跑，就到那台運算節點查。
節點在 `sinfo` 顯示 `idle`，也不能單靠這個值證明實際工作一定成功。

**目的與影響：** 模組 05 的
[三節點設定](../project/slurm/three-node-slurm.conf)
把 `compute-cpu01` 放在 `cpu` 分區、`compute-gpu01` 放在 `gpu` 分區。
這是工作樹中的設定來源；控制節點的 `slurmctld` 實際讀取自己的
`/etc/slurm/slurm.conf`。設定有列出節點，不保證節點現在能接工作；
重開機後即使 `slurmd` 已啟動，Slurm 仍可能保留 `DOWN` 狀態。

因此先在**控制節點**向正在運行的 `slurmctld` 查目前狀態，
作為後續監控與故障演練的起點。這條指令只讀，不修改設定、服務、
工作或雲端資源，也不需要復原。

**已執行指令｜控制節點：**

```bash
sinfo -N -o '%N %T %c %m %P'
```

`-N` 讓每台節點各占一行；格式依序顯示節點名稱、Slurm 狀態、
可排程 CPU 數、可排程記憶體 MiB 和分區。
重點是核對 CPU、GPU 兩台獨立運算節點各自所在的分區與狀態；
`idle` 表示目前可接工作，`down` 則須先查節點原因。
這項查詢不證明工作已成功，也不證明兩台能執行同一類工作。

**實際輸出：**

```text
NODELIST STATE CPUS MEMORY PARTITION
compute-cpu01 idle 1 1400 cpu
compute-gpu01 idle 4 14000 gpu
instance-20260923-104239 idle 2 3000 debug*
```

**判讀：** CPU 客體與 GPU VM 此刻都可由各自分區接工作；
數字是 Slurm 設定的可排程資源，不是即時硬體用量。
`debug*` 是控制節點的預設分區，不算第二台獨立運算節點。

### 核對目前是否有工作

**目的與影響：** 故障演練前先查排隊與執行中的工作，
確認是否有人或工作會受影響。`squeue` 讀取控制節點的工作佇列；
欄位依序是工作 ID、分區、狀態、提交者及分配節點。
這條指令不提交、取消或更改工作。

**已執行指令｜控制節點：**

```bash
squeue -o '%i %P %T %u %N'
```

若只有標題而沒有工作列，表示查詢當下佇列是空的；
若有工作，先讀狀態與節點，再決定下一步。

**實際輸出：**

```text
JOBID PARTITION STATE USER NODELIST
```

**判讀：** 查詢當下沒有排隊或執行中的 Slurm 工作。
這是安排後續演練的基準，不代表演練時佇列必然仍為空。

### 核對三台節點的 Slurm 服務

**目的與影響：** 分別查控制節點的 `slurmctld`、GPU VM 與 CPU 客體的
`slurmd`，比較目前運行、開機啟動及程序退出後的重啟設定。
`Restart=` 是 systemd 的程序重啟策略，與 `slurm.conf` 的排程設定
及開機啟動設定是不同的事。下列查詢只讀，不修改服務。

**已執行指令｜控制節點查 `slurmctld`：**

```bash
systemctl show slurmctld -p ActiveState -p SubState -p UnitFileState -p Restart
```

**實際輸出：**

```text
Restart=no
ActiveState=active
SubState=running
UnitFileState=enabled
```

**判讀：** 控制節點的服務查詢成功；四個欄位與下方兩台運算節點一起比較。

**已執行指令｜控制節點的 `project/ansible` 目錄查 GPU VM 的 `slurmd`：**

```bash
ansible gpu_compute -m command -a 'systemctl show slurmd -p ActiveState -p SubState -p UnitFileState -p Restart' -o
```

**實際輸出：**

```text
compute-gpu01 | CHANGED | rc=0 | (stdout) Restart=no\nActiveState=active\nSubState=running\nUnitFileState=enabled
```

**判讀：** `rc=0`，GPU VM 查詢成功；四個欄位與控制節點相同。

**已執行指令｜控制節點的 `project/ansible` 目錄查 CPU 客體的 `slurmd`：**

```bash
ansible cpu_compute -m command -a 'systemctl show slurmd -p ActiveState -p SubState -p UnitFileState -p Restart' -o
```

**實際輸出：**

```text
compute-cpu01 | CHANGED | rc=0 | (stdout) Restart=no\nActiveState=active\nSubState=running\nUnitFileState=enabled
```

**判讀：** `rc=0`，CPU 客體查詢成功；四個欄位也與前兩台相同。
兩次 Ansible 查詢的 `CHANGED` 是 `command` 模組的執行標記；
實際執行的 `systemctl show` 只讀，沒有更改服務。

| 三台服務都回傳的值 | 意義與結論 |
|---|---|
| `Restart=no` | 程序退出後，systemd 不會依此設定自動重啟該服務。 |
| `ActiveState=active` | 服務單元目前處於啟用狀態；單看這個值還不能確認程序正在運行。 |
| `SubState=running` | 搭配 `active`，表示三台各自的 Slurm 程序當時都正在運行。 |
| `UnitFileState=enabled` | 下次正常開機時，systemd 會嘗試啟動各自的服務；這與程序退出後的重啟策略不同。 |

## 2. 新增監控兼運算節點

控制節點的根檔案系統僅剩 1.9 GiB 可用空間。
[Zabbix 7.0 LTS 官方需求](https://www.zabbix.com/documentation/7.0/en/manual/installation/requirements)
以 2 vCPU、8 GiB 記憶體作為小型部署的參考規格；現有控制節點只有
4 GiB 記憶體。官方也說資料庫磁碟用量取決於監控項目、採樣頻率與
保留時間；控制節點僅餘 1.9 GiB，不適合再放監控資料庫。
`openstack-lab01` 雖有 8 GiB，已承載 DevStack 與
`compute-cpu01`，沒有再提供 8 GiB 監控客體的餘裕。
因此新建 GCP CPU VM `compute-cpu02`，規格 2 vCPU、8 GiB 記憶體、
40 GiB 開機磁碟；已把它加入 Slurm `cpu` 分區，之後在同台部署
Zabbix 伺服器。Zabbix 套件與監控服務目前尚未安裝。
官方 8 GiB 是獨立小型部署的起始範例；這台 VM 同時接 Slurm 工作，
上線監控後須量測兩者的記憶體峰值，再決定是否擴容或限制工作並行。
VM 與開機磁碟會持續計費，停機後磁碟仍會計費。

### 建機前限定新 VM 的入站流量

**目的與影響：** 新 VM 放在東京的 `default` VPC 子網，
使用 `hpc-monitor-cpu` 網路標籤。東京既有 `gpu-egress-nat`
涵蓋這個子網，新 VM 無須對外 IPv4 就能下載套件。
以下兩條規則只匹配這個標籤：
先允許 GCP 私有位址來源，再拒絕其他 IPv4 入站。
前者優先權 `800` 高於後者的 `900`，不修改現有 VM。

**已執行指令｜控制節點：**

```bash
gcloud compute firewall-rules create hpc-monitor-cpu-internal --project=project-78b8a95c-a2c0-461f-a08 --network=default --direction=INGRESS --priority=800 --source-ranges=10.128.0.0/9 --target-tags=hpc-monitor-cpu --allow=tcp:0-65535,udp:0-65535,icmp --quiet
```

**實際結果：** GCP 回報 `Created`；規則位於 `default` 網路，
`INGRESS`、優先權 `800`、允許 TCP／UDP／ICMP，`DISABLED=False`。
這只建立防火牆規則，尚未建立新 VM。

這條建立只適用於新 VM 標籤的內網允許規則；若要復原，可刪除
`hpc-monitor-cpu-internal`，但須先確認新 VM 不再需要內網管理。

**已執行指令｜控制節點：**

```bash
gcloud compute firewall-rules create hpc-monitor-cpu-external-deny --project=project-78b8a95c-a2c0-461f-a08 --network=default --direction=INGRESS --priority=900 --source-ranges=0.0.0.0/0 --target-tags=hpc-monitor-cpu --action=deny --rules=tcp:0-65535,udp:0-65535,icmp --quiet
```

**實際結果：** GCP 回報 `Created`；規則位於 `default` 網路，
`INGRESS`、優先權 `900`、拒絕 TCP／UDP／ICMP，`DISABLED=False`。

這條阻擋新 VM 的外部主動連線；允許的內網來源會先匹配優先權 `800`。
復原時可刪除 `hpc-monitor-cpu-external-deny`，不影響沒有此標籤的 VM。

### 建立 CPU VM

**目的與影響：** 在東京 `asia-northeast1-c` 建立 `compute-cpu02`，
採用 AlmaLinux 10.2 的官方 x86_64 映像、`e2-standard-2`、
40 GiB `pd-standard` 開機磁碟和 `default` VPC。
既有 SSH 公鑰由控制節點 `/tmp/compute-gpu01-a2264-ssh-keys-20261003`
送入新 VM 的中繼資料，不包含私鑰；
`hpc-monitor-cpu` 標籤套用前述兩條防火牆規則。
VM 只取得內網位址，套件下載走既有 Cloud NAT。
新 VM 與開機磁碟會產生費用，使用 Cloud NAT 也可能增加流量費；
若要復原，須先從 Slurm 移除節點，再停止或刪除 VM，
刪除開機磁碟會失去其本機資料。

**已執行指令｜控制節點：**

```bash
gcloud compute instances create compute-cpu02 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --machine-type=e2-standard-2 \
  --image-project=almalinux-cloud \
  --image=almalinux-10-v20261013 \
  --boot-disk-type=pd-standard \
  --boot-disk-size=40GB \
  --network=default \
  --subnet=default \
  --tags=hpc-monitor-cpu \
  --no-address \
  --no-service-account \
  --no-scopes \
  --metadata-from-file=ssh-keys=/tmp/compute-gpu01-a2264-ssh-keys-20261003 \
  --quiet
```

**實際結果：** GCP 回報 `Created`；`compute-cpu02` 位於
`asia-northeast1-c`，機型 `e2-standard-2`，內網 IP `10.146.0.5`，
無外部 IP，狀態 `RUNNING`。開機磁碟為 40 GiB；GCP 提醒映像原始
大小是 10 GiB，實際根檔案系統容量待進入 VM 核對。

`--tags` 指定上述防火牆規則的目標；`--no-address` 不配對外 IPv4。
此時尚未把新 VM 寫進 Slurm 設定或啟動監控服務。

### 核對新 VM

**目的與影響：** [Ansible inventory](../project/ansible/inventory/hosts.yml)
已加入 `compute-cpu02` 的實際內網 IP。從控制節點的 `project/ansible`
讀取新 VM 的作業系統資訊，同時驗證既有公鑰的管理連線。
這條查詢不安裝套件或改動服務。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible monitor_cpu -m command -a 'cat /etc/os-release' -o
```

**實際輸出節錄：** `compute-cpu02 | CHANGED | rc=0`，內容包含
`NAME="AlmaLinux"`、`VERSION_ID="10.2"`、`PLATFORM_ID="platform:el10"`。

**判讀：** 控制節點已能透過 Ansible 管理新 VM，客體是 AlmaLinux 10.2。
`CHANGED` 是 `command` 模組的標記，這次 `cat` 查詢只讀。

**目的與影響：** 核對新 VM 的根檔案系統實際容量，確認 GCP 的 40 GiB
開機磁碟已由客體使用。查詢只讀，不調整分割區或檔案系統。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible monitor_cpu -m command -a 'df -h /' -o
```

**實際輸出：** `compute-cpu02 | CHANGED | rc=0`；根檔案系統
`/dev/sda2` 為 40 GiB，已用 2.7 GiB，尚有 38 GiB，使用率 7%。

**判讀：** 客體已使用完整 40 GiB 開機磁碟，不需另外擴容。
這次 `df` 查詢只讀。

**目的與影響：** 確認新 VM 透過東京既有 Cloud NAT 能連到 Zabbix
官方套件站，再開始套件安裝。Ansible `uri` 只發送 HTTPS HEAD
請求，不下載或安裝套件。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible monitor_cpu -m uri -a 'url=https://repo.zabbix.com/ method=HEAD status_code=200 timeout=10' -o
```

**實際結果：** `compute-cpu02 | SUCCESS`，`changed=false`，
`status=200`，網址為 `https://repo.zabbix.com/`。

**判讀：** 新 VM 的 HTTPS 出站可達 Zabbix 官方套件站；
這次 HEAD 請求沒有安裝套件或變更 VM。

### 安裝新節點的 Slurm 基礎

新 VM 已在 Ansible inventory 的 `cpu_compute` 與 `monitor_cpu` 群組；
以下沿用模組 05 已驗證的 CPU 節點安裝檔，只以
`--limit compute-cpu02` 管理新 VM。

**目的與影響：** [套件 playbook](../project/ansible/slurm-cpu-packages.yml)
先在新 VM 建立 `/var/tmp/hpc-slurm-rpms`，再從控制節點工作樹的
`project/packages/slurm/` 複製兩個 Slurm 26.05.4 RPM 到該目錄，
由 AlmaLinux 倉庫安裝 `munge`，最後在新 VM 安裝 Slurm 共用套件
與 `slurm-slurmd`。本步會寫入新 VM 的套件資料庫與暫存檔，
不修改既有節點，也不啟動服務。若需復原，可在新 VM 移除這些套件
與暫存 RPM；目前不執行復原。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible-playbook slurm-cpu-packages.yml --limit compute-cpu02
```

**實際結果：** 只處理 `compute-cpu02`，recap 為
`ok=6 changed=4 unreachable=0 failed=0`。安裝版本是
`munge 0.5.15-11.el10_1.x86_64`、
`slurm 26.05.4-1.el10.x86_64` 和
`slurm-slurmd 26.05.4-1.el10.x86_64`。

**判讀：** 套件已安裝到新 VM；MUNGE 金鑰與 `slurmd` 服務尚未設定。

**目的與影響：** [身分 playbook](../project/ansible/slurm-cpu-identity.yml)
只在新 VM 建立或核對 `slurm` 群組 GID 800 與服務使用者 UID 800，
不改其他 VM。數字身分需與控制節點一致，供服務讀取相同的 Slurm
設定及驗證工作憑證。若要復原，須先停止新 VM 上的 Slurm 服務，
再移除該帳號與群組；目前不執行復原。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible-playbook slurm-cpu-identity.yml --limit compute-cpu02
```

**實際結果：** `id slurm` 回報
`uid=800(slurm) gid=800(slurm) groups=800(slurm)`；
recap 只有 `compute-cpu02`，`ok=4 changed=2 failed=0`。

**判讀：** 新 VM 的 Slurm 服務身分已與控制節點一致。

**目的與影響：** [MUNGE playbook](../project/ansible/munge-cpu.yml)
先在新 VM 建立或核對 `/etc/munge` 等服務目錄，再從控制節點自己的
`/etc/munge/munge.key` 將同一把金鑰送到新 VM 的同名路徑。
金鑰不進工作樹與終端輸出；變更時由 handler 重啟新 VM 的 `munge`，
並設定下次開機自啟。其他節點的金鑰與服務不變。
若要復原，先停止新 VM 的 `munge`，再移除其金鑰；目前不執行復原。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible-playbook munge-cpu.yml --limit compute-cpu02
```

**實際結果：** `compute-cpu02` 的目錄核對為 `ok`，金鑰複製、服務啟動
與金鑰變更後的 handler 重啟為 `changed`；recap 為
`ok=4 changed=3 unreachable=0 failed=0`。

**判讀：** 新 VM 的 MUNGE 已啟動並持有控制節點提供的叢集金鑰；
金鑰內容未進入輸出或工作樹。

**目的與影響：** 在新 VM 以 `slurmd -C` 讀取 CPU 拓撲與可見記憶體，
作為新增 Slurm 節點設定的依據。這條指令只輸出硬體資訊，
不啟動 `slurmd` 或修改服務。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible monitor_cpu -m command -a 'slurmd -C' -o
```

**實際輸出：**

```text
compute-cpu02 | CHANGED | rc=0 | (stdout) NodeName=compute-cpu02 CPUs=2 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=2 RealMemory=7932\nUpTime=0-00:07:13
```

**判讀：** 新 VM 可見 2 個邏輯 CPU、1 核／2 執行緒與 7932 MiB
記憶體。Slurm 宣告實測的 2 個邏輯 CPU，但只把 4000 MiB
記憶體交給排程；同台 Zabbix 與工作仍可能競爭 CPU。

### 更新四節點 Slurm 設定

**目的與影響：** [四節點設定來源](../project/slurm/four-node-slurm.conf)
在 `cpu` 分區加入 `compute-cpu02`，地址為建機結果 `10.146.0.5`，
宣告 2 CPU、4000 MiB。檔案目前只在控制節點工作樹；
Slurm 服務尚未讀到它。[部署 playbook](../project/ansible/slurm-four-node.yml)
正式執行時先查佇列為空，再核對三台運算 VM 的
`/etc/slurm` 與 `/var/spool/slurmd` 目錄，將來源複製到各自的
`/etc/slurm/slurm.conf` 並執行 `slurmd -G`；
三台通過後，才替換控制節點自己的同名檔案並執行 `scontrol reconfigure`，
最後只重啟設定有變更的 `slurmd`。複製任務會在各 VM 留下舊檔備份；
此變更會短暫重啟三台運算節點的 `slurmd`，因此 playbook 會先拒絕
在有工作時執行。若需復原，應依備份還原每台設定，重新載入控制端
並重啟受影響的運算服務；目前不執行復原。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible-playbook slurm-four-node.yml --syntax-check
```

**實際結果：** `playbook: slurm-four-node.yml`，退出碼為 0。

**判讀：** playbook 語法通過；尚未複製設定或更動任何服務。

**目的與影響：** 正式執行前述 playbook，將四節點設定分別寫到三台
運算 VM 與控制節點，重新載入 `slurmctld`，重啟設定變更的 `slurmd`。
新節點會因此開始向控制端註冊；完成後再查節點狀態與實際 CPU 工作。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
ansible-playbook slurm-four-node.yml
```

**實際結果：** `squeue` 為空；三台運算 VM 的設定複製、`slurmd -G`
檢查與 `slurmd` 重啟成功，控制節點設定複製與
`scontrol reconfigure` 成功。recap：

| 主機 | ok | changed | unreachable | failed |
|---|---:|---:|---:|---:|
| `compute-cpu01` | 7 | 2 | 0 | 0 |
| `compute-cpu02` | 7 | 4 | 0 | 0 |
| `compute-gpu01` | 7 | 2 | 0 | 0 |
| 控制節點 | 3 | 2 | 0 | 0 |

**判讀：** 四台 VM 各自的 `/etc/slurm/slurm.conf` 已更新；
控制端重新讀取設定，三台運算服務已重啟。`slurmd -G` 自動核對
退出碼、`error:` 與 GPU 設備名稱 `nvidia_l4`；
節點是否實際可排程仍需向控制端查詢。

**目的與影響：** 控制節點讀取 Slurm 目前認得的節點、狀態、
可排程 CPU／記憶體與分區，確認新節點已註冊且舊節點仍在線。
這條查詢只讀，不提交工作或變更節點狀態。

**已執行指令｜控制節點：**

```bash
sinfo -N -o '%N %T %c %m %P'
```

**實際輸出：**

```text
NODELIST STATE CPUS MEMORY PARTITION
compute-cpu01 idle 1 1400 cpu
compute-cpu02 idle 2 4000 cpu
compute-gpu01 idle 4 14000 gpu
instance-20260923-104239 idle 2 3000 debug*
```

**判讀：** 新節點已在 `cpu` 分區註冊為 `idle`，資源額度符合設定；
原有 CPU、GPU 與控制節點也仍為 `idle`。

**目的與影響：** 從控制節點向 `cpu` 分區提交一個指定在
`compute-cpu02` 執行的短暫工作，讀取執行主機名；
`-D /tmp` 指定新 VM 上確定存在的工作目錄，避免沿用控制節點的
`/root/hpc-arch` 路徑。
這能核對 Slurm 分配、MUNGE 驗證與新節點啟動程序的基本通路。
工作結束後不保留運算程序，也不修改設定檔。

**已執行指令｜控制節點：**

```bash
srun -D /tmp -p cpu -w compute-cpu02 -N1 -n1 hostname
```

**實際輸出：** `compute-cpu02`，退出碼為 0，沒有其他終端輸出。

**判讀：** Slurm 已把指定工作交給新 VM，並由它啟動程序。
新節點加入與基本派工驗證完成；Zabbix 部署和故障告警仍屬本模組後續工作。
