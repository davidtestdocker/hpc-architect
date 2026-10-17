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

[Zabbix 7.0 LTS 官方需求](https://www.zabbix.com/documentation/7.0/en/manual/installation/requirements)
以 2 vCPU、8 GiB 記憶體作為小型部署的起始範例；資料庫磁碟用量取決於監控項目與保留時間。
控制節點只有 4 GiB 記憶體，根檔案系統僅餘 1.9 GiB。
OpenStack 宿主機雖有 8 GiB，已承載 DevStack 和 `compute-cpu01`，因此另建 GCP VM。

| 名稱 | 規格 | 內網 IP | Slurm 分區 | 狀態 |
|---|---|---|---|---|
| `compute-cpu02` | AlmaLinux 10.2；2 vCPU、8 GiB 記憶體、40 GiB 磁碟 | `10.146.0.5` | `cpu`：2 CPU、4000 MiB 可排程記憶體 | `idle`；指定節點的工作已成功執行 |

**目的與影響：** 列出 Slurm 目前認得的節點，核對
`compute-cpu02` 是否出現在 `cpu` 分區，以及它目前的狀態、CPU 數與可排程記憶體。
此指令只讀，不改動節點或工作。

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
instance-20260923-104239 idle 2 3000 debug
```

**判讀：** `%N` 是節點名稱、`%T` 是狀態、`%c` 是 CPU 數、
`%m` 是可排程記憶體 MiB、`%P` 是分區。
`compute-cpu02` 確實列在 `cpu` 分區，為 `idle`，有 2 CPU 與 4000 MiB
可供 Slurm 排程；其餘三個節點此時也都是 `idle`。

**新增檔案：** [四節點 Slurm 設定](../project/slurm/four-node-slurm.conf)、
[四節點部署 playbook](../project/ansible/slurm-four-node.yml)。

**修改檔案：** [Ansible inventory](../project/ansible/inventory/hosts.yml)，加入 `compute-cpu02`。

這台 VM 同時接 Slurm 工作；啟動監控後須依實際記憶體用量調整可排程工作或 VM 規格。

## 3. 安裝 Zabbix 套件

Slurm 已能接收並執行工作，接下來需要 Zabbix 持續收集狀態與記錄告警。
Zabbix server 負責收集和判斷，資料庫保存歷史與事件，網頁介面用來查看；
之後再讓各節點提供健康資料。
已從[Zabbix 官方 AlmaLinux 10 套件庫](https://repo.zabbix.com/zabbix/7.0/alma/10/x86_64/)
在 `compute-cpu02` 安裝以下套件；版本經 VM 的套件資料庫核對。

| 套件 | 已安裝版本 | 用途 |
|---|---|---|
| `zabbix-release` | `7.0-7.el10` | 加入官方 7.0 LTS 套件來源與簽章公鑰 |
| `zabbix-server-mysql` | `7.0.31-release1.el10` | 收集資料、計算告警條件；使用 MariaDB 後端 |
| `mariadb-server` | `10.11.18-1.el10_2.alma.2` | 儲存監控歷史和事件 |
| `zabbix-web`、`zabbix-web-mysql`、`zabbix-apache-conf` | `7.0.31-release1.el10` | Zabbix 網頁介面與 Apache 設定；相依套件也安裝了 `httpd 2.4.63`、`PHP-FPM 8.4.24` |
| `zabbix-sql-scripts` | `7.0.31-release1.el10` | 提供稍後建立資料庫表格的 SQL，尚未匯入 |
| `zabbix-selinux-policy` | `7.0.31-release1.el10` | 提供服務所需的 SELinux 政策 |
| `zabbix-agent2` | `7.0.31-release1.el10` | 供這台 VM 提供自身的健康資料；其他節點尚未安裝 |

**目前狀態：** 套件已安裝；Zabbix 資料庫尚未建立，Zabbix 與網頁服務
尚未設定或啟動。

## 4. 啟動資料庫

**目的與影響：** 在 `compute-cpu02` 啟動 MariaDB，供後續建立 Zabbix
資料庫；本步不設定開機自動啟動。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl start mariadb
```

**實際結果：** 沒有終端輸出，MariaDB 已啟動。

## 5. 建立 Zabbix 資料庫

MariaDB 程序已運行，但 Zabbix 專用資料庫與帳號尚未建立。
先進入新 VM 上的 MariaDB 命令列，後續 SQL 才會送到這台資料庫服務。

**目的與影響：** 以本機管理者身分連上 MariaDB；進入互動式 SQL 提示字元，
這一步本身不建立或修改資料庫。退出時可輸入 `exit`。

**已執行指令｜`compute-cpu02`：**

```bash
sudo mariadb
```

**實際結果：** 顯示 `Server version: 10.11.18-MariaDB`，並進入
`MariaDB [(none)]>` 提示字元。已連上本機資料庫服務，尚未建立 Zabbix 資料庫。

**目的與影響：** 建立名為 `zabbix` 的資料庫，供監控歷史和事件使用。
`utf8mb4` 可儲存完整 Unicode，`utf8mb4_bin` 是 Zabbix 安裝指引採用的校對規則。
這條 SQL 只建立資料庫，不建立帳號或資料表。

**已執行指令｜`compute-cpu02` 的 `MariaDB [(none)]>` 提示字元：**

```sql
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
```

**實際結果：** `Query OK, 1 row affected (0.001 sec)`。
`zabbix` 資料庫已建立，帳號與資料表尚未建立。

**目的與影響：** 在目前的 MariaDB 連線建立 `zabbix` 資料庫帳號，
只允許從這台 VM 的 `localhost` 使用。這一步只建立帳號，
還不授予它操作 `zabbix` 資料庫的權限。

**已執行指令｜`compute-cpu02` 的 MariaDB 提示字元：**

```sql
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '<DB_PASSWORD>';
```

**實際結果：** `Query OK, 0 rows affected (0.004 sec)`；
`zabbix`@`localhost` 帳號已建立。實際密碼不寫入文件。

**目的與影響：** 讓這個帳號只能操作剛建立的 `zabbix` 資料庫。
這一步授予資料庫權限，不更改帳號密碼，也不建立資料表。

**已執行指令｜`compute-cpu02` 的 MariaDB 提示字元：**

```sql
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
```

`zabbix.*` 指 `zabbix` 資料庫內的表格，不是整台 MariaDB 的所有資料庫。

**實際結果：** `Query OK, 0 rows affected (0.002 sec)`。
`zabbix` 帳號已有其專用資料庫的權限，資料表尚未匯入。

**目的與影響：** 回到 `compute-cpu02` 的 shell 後，核對套件提供的
Zabbix server 資料表腳本是否存在；這條指令只讀，不匯入資料。

**已執行指令｜`compute-cpu02` 的 shell：**

```bash
ls -l /usr/share/zabbix-sql-scripts/mysql/server.sql.gz
```

**實際輸出：**

```text
-rw-r--r--. 1 root root 4240104 Sep 22 00:00 /usr/share/zabbix-sql-scripts/mysql/server.sql.gz
```

Zabbix server 的壓縮 SQL 腳本存在；尚未匯入資料庫。

**目的與影響：** `zcat` 將這個壓縮腳本送到標準輸出，`|` 把 SQL
交給本機 MariaDB 客戶端，後者以 `zabbix` 帳號匯入 `zabbix` 資料庫。
這會建立監控資料表與初始資料，不修改 Slurm 設定。

**已執行指令｜`compute-cpu02` 的 shell：**

```bash
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mariadb --default-character-set=utf8mb4 -uzabbix -p zabbix
```

`--default-character-set=utf8mb4` 使用資料庫的字元集；`-p` 會另外提示輸入
剛建立的資料庫帳號密碼，不把密碼放進指令。

**實際結果：** 出現 `Enter password:`，輸入後返回 shell，沒有顯示錯誤。

**目的與影響：** 只讀查詢 `zabbix` 資料庫的資料表數量和內建帳號數量，
確認 SQL 腳本的結構與初始資料已寫入；不修改資料庫。

**已執行指令｜`compute-cpu02` 的 shell：**

```bash
sudo mariadb -e "SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='zabbix') AS tables, (SELECT COUNT(*) FROM zabbix.users) AS users;"
```

`tables` 是資料表數，`users` 是初始帳號數；兩者應有非零結果。

**實際輸出：**

```text
+--------+-------+
| tables | users |
+--------+-------+
|    203 |     2 |
+--------+-------+
```

**判讀：** 資料表與初始帳號均已寫入 `zabbix` 資料庫。

## 6. 設定 Zabbix server 連接資料庫

Zabbix server 會讀取 `compute-cpu02` 自己的
`/etc/zabbix/zabbix_server.conf`，取得資料庫名稱、帳號和密碼。
先核對套件目前設定的資料庫名稱與帳號，避免修改錯誤欄位。

**目的與影響：** 只讀取 `DBName` 和 `DBUser` 的有效設定行；
不顯示密碼，也不修改設定檔或服務。

**已執行指令｜`compute-cpu02`：**

```bash
sudo grep -nE '^(DBName|DBUser)=' /etc/zabbix/zabbix_server.conf
```

`-n` 顯示行號，方便接下來找到設定；`-E` 讓同一個條件比對兩個欄位。

**實際輸出：**

```text
107:DBName=zabbix
123:DBUser=zabbix
```

**判讀：** Zabbix server 的資料庫名稱與帳號已對上剛建立的資料庫和使用者。

**目的與影響：** 編輯 `compute-cpu02` 上 Zabbix server 實際讀取的設定檔，
加入本機 `zabbix` 資料庫帳號的密碼。只修改這台 VM 的設定檔；
密碼不寫進課程文件或命令列。

**已執行指令｜`compute-cpu02`：**

```bash
sudo vi /etc/zabbix/zabbix_server.conf
```

在編輯器內將 `DBPassword=` 設為建立 `zabbix` 資料庫帳號時使用的密碼；
密碼不記入文件。

**實際結果：** 已回報密碼設定修改完成；編輯器沒有可記錄的終端輸出。
目前尚未以 Zabbix server 啟動結果驗證資料庫連線。

**目的與影響：** 啟動 `compute-cpu02` 的 Zabbix server，
讓它讀取上述設定並連接本機 MariaDB；這會啟動監控服務，
可用 `sudo systemctl stop zabbix-server` 停止。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl start zabbix-server
```

**實際結果：** 指令返回 shell，沒有終端輸出或錯誤訊息。

Zabbix server 目前正在執行。

## 7. 啟動 Zabbix 網頁介面

Zabbix server 已執行；網頁介面還需要 `php-fpm` 執行 PHP 程式，
以及 `httpd` 接收瀏覽器的 HTTP 請求。

**目的與影響：** 在 `compute-cpu02` 啟動網頁介面的兩個服務；
這會讓 HTTP 服務在 VM 上開始監聽。需要停止時可執行
`sudo systemctl stop httpd php-fpm`。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl start php-fpm httpd
```

**實際結果：** 指令返回 shell，沒有終端輸出或錯誤訊息。

## 8. 從自己的電腦開啟網頁初始設定

`compute-cpu02` 沒有外部 IP。Windows 上的 `18081` 已由 VS Code
監聽；沿用 VS Code 對控制節點的埠轉送，從控制節點建立到
`compute-cpu02` 的 SSH 轉接。Windows 上不再啟動另一個 `ssh -L`。

**目的與影響：** 由控制節點登入 `compute-cpu02`，把控制節點的
`127.0.0.1:18081` 轉到監控 VM 的 `127.0.0.1:80`。
只建立持續到終端結束的連線，不改 VM 或防火牆。

**已執行指令｜控制節點的 `a2264` shell：**

```bash
ssh -i ~/.ssh/hpc_gpu_ed25519 -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes -N -L 127.0.0.1:18081:127.0.0.1:80 a2264@10.146.0.5
```

`-i` 指定 Ansible inventory 使用的 SSH 金鑰；`-N` 保持連線但不開遠端 shell；
`-L` 指定控制節點的本機埠和監控 VM 的網頁埠。

**實際結果：** SSH 指令保持執行，沒有終端輸出；
Windows 瀏覽器開啟 `http://127.0.0.1:18081/zabbix/` 後進入
`http://127.0.0.1:18081/zabbix/setup.php` 安裝頁面。
網頁已可達，初始設定尚未完成。

## 9. 設定網頁前端的資料庫連線

**實際畫面：** [資料庫連線設定頁](../project/monitoring/zabbix-prerequisites.png)。
目前顯示 MySQL、`localhost`、連接埠 `0`（使用預設埠）、
資料庫 `zabbix`、使用者 `zabbix`；密碼欄尚未填入。

**已操作｜網頁初始設定：** 在 Password 欄輸入 `zabbix`
資料庫帳號的密碼，按 **Next step**。網頁前端使用這組帳密
連接 MariaDB；密碼不記入本文件。

**實際結果：** [畫面進入 Settings](../project/monitoring/image.png)，
資料庫連線設定已通過，網頁初始設定尚未完成。

## 10. 設定網頁顯示選項

**已操作｜網頁初始設定：** 通過 Settings 頁，完成後續安裝畫面並登入。

**實際結果：** [成功登入後的 Global view](../project/monitoring/success-login.png)
顯示 `Zabbix server is running: Yes`，server 與 frontend 均為 `7.0.31`。
畫面同時顯示 `Linux: Zabbix agent is not available`；
目前只證明網頁登入與 server 運作，尚未證明 agent 監控可用。

## 11. 啟動監控 VM 的 Zabbix agent

`compute-cpu02` 已安裝 `zabbix-agent2`，但儀表板顯示本機 agent 不可用。
agent 在被監控的 VM 上提供主機資料，Zabbix server 再讀取資料並判斷告警。

**目的與影響：** 在 `compute-cpu02` 啟動 agent 服務，讓本機 Zabbix server
能取得這台 VM 的狀態；不修改 Slurm。需要撤回時可執行
`sudo systemctl stop zabbix-agent2`。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl start zabbix-agent2
```

**實際結果：** 指令返回 shell，沒有終端輸出或錯誤訊息。

**網頁結果：** [啟動 agent 後的儀表板](../project/monitoring/zabbix-server-agent.png)
顯示主機可用性 `1 可用、0 無法使用`，並有 CPU 使用率資料；
目前問題清單為空。這證明本機 agent 已能提供資料給 Zabbix server。

## 12. 設定監控服務開機啟動

**目的與影響：** 在 `compute-cpu02` 設定資料庫、Zabbix 伺服器、
網頁服務及本機代理程式開機自動啟動。
`enable` 修改 systemd 的開機設定，不會重啟目前正在執行的服務。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl enable mariadb zabbix-server php-fpm httpd zabbix-agent2
```

**實際結果：** 已回報設定完成；未提供終端輸出。

## 13. 持續收集 `slurmd` 的服務狀態

目前 Zabbix 已收到 `compute-cpu02` 的主機資料；下一步讓它定期收集
這台 VM 的 `slurmd` 狀態，作為 Slurm 服務告警的依據。

**目的與影響：** 先讓 `compute-cpu02` 的代理程式單次讀取
`slurmd.service` 的狀態，確認稍後要使用的監控鍵值可用；
`-t` 只測試這次讀取，不修改服務或監控設定。

**已執行指令｜`compute-cpu02`：**

```bash
zabbix_agent2 -t 'systemd.unit.info[slurmd.service]'
```

**實際輸出：**

```text
systemd.unit.info[slurmd.service]             [s|active]
```

**判讀：** `[s|active]` 表示回傳字串 `active`，可用這個鍵值建立監控項。
建立監控項只修改 Zabbix 的監控設定，不會重啟或修改 `slurmd`。

**已操作｜Zabbix 網頁：** 從「數據收集」→「主機」找到預設主機
「Zabbix 伺服器」，進入該主機的監控項，建立以下項目：

| 欄位 | 值 |
|---|---|
| 名稱 | `Slurm 運算服務狀態` |
| 類型 | Zabbix 代理程式 |
| 鍵值 | `systemd.unit.info[slurmd.service]` |
| 資訊類型 | 字元 |
| 更新間隔 | `1m` |

**實際結果：** 已回報新增成功；項目列表顯示名稱
`Slurm 運算服務狀態`、鍵值 `systemd.unit.info[slurmd.service]`、
更新間隔 `1m`、歷史資料保留 `31d`、類型 `Zabbix agent`，
狀態 `Enabled`。

**實際畫面：** [最新資料中的 `slurmd` 狀態](../project/monitoring/slurmed-service.png)。
畫面篩選主機 `Zabbix server` 和項目 `Slurm 運算服務狀態`，
顯示上次檢查為 `25s` 前、最新值為 `active`。
Zabbix 伺服器已收到這個監控項的資料。

## 14. 設定 `slurmd` 停止時的告警條件

監控項已持續收到狀態，接著用觸發器判斷服務何時不是 `active`。
這只在 Zabbix 建立告警規則，不會停止或重啟 `slurmd`。
狀態恢復 `active` 時，同一條規則會回到正常。

**已操作｜Zabbix 網頁：** 從「數據收集」→「主機」找到
「Zabbix 伺服器」，進入觸發器並建立以下規則：

| 欄位 | 值 |
|---|---|
| 名稱 | `compute-cpu02：slurmd 未執行` |
| 嚴重程度 | 高 |
| 表達式 | `last(/Zabbix server/systemd.unit.info[slurmd.service])<>"active"` |

**實際畫面：** [觸發器建立結果](../project/monitoring/trigger-sluremd-service.png)。
頁面顯示 `Trigger added`；規則嚴重程度為 `High`、狀態為 `Enabled`，
目前值為 `OK`。這確認規則已建立，故障時的 `Problem` 與恢復事件
仍需實際演練核對。

## 15. 演練 `compute-cpu02` 的 `slurmd` 停止與恢復

已確認目前沒有要保留的工作。這次只停止 `compute-cpu02` 的
`slurmd`，讓該節點暫時不能接 Slurm 工作；Zabbix 伺服器、
代理程式及網頁服務會繼續執行，以記錄問題與恢復事件。
不修改設定檔或雲端資源。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl stop slurmd
```

**實際結果：** 指令返回 shell，沒有終端輸出或錯誤訊息。

**Zabbix 問題事件：** [監測頁的故障畫面](../project/monitoring/slurmd-problem.png)
顯示 `compute-cpu02：slurmd 未執行`，嚴重程度 `High`、狀態 `PROBLEM`，
畫面記錄的發生時間為 `11:12:05 AM`。觸發器已偵測到這次服務停止。

**目的與影響：** 在 `compute-cpu02` 重新啟動 `slurmd`，讓該 VM
恢復向 Slurm 控制節點回報狀態；Zabbix 預期於下一次收集後恢復為正常。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl start slurmd
```

**實際結果：** 指令返回 shell，沒有終端輸出或錯誤訊息。

若 Slurm 控制節點仍保留節點 `DOWN` 狀態，再依實際狀態恢復排程。

**目的與影響：** 從控制節點查 `compute-cpu02` 的排程狀態，
確認 `slurmd` 啟動後，Slurm 是否已重新開放該節點；這條指令只讀。

**已執行指令｜控制節點：**

```bash
sinfo -N -n compute-cpu02 -o '%N %T'
```

**實際輸出：**

```text
NODELIST STATE
compute-cpu02 down
```

**判讀：** `slurmd` 已重新啟動，Zabbix 恢復由操作人員回報，
但 Slurm 控制節點仍保留 `DOWN`。現有四節點設定未指定
`ReturnToService`；[Slurm 官方文件](https://slurm.schedmd.com/slurm.conf.html)
說明其預設值 `0` 會保留 `DOWN`，直到管理員明確變更節點狀態。

**目的與影響：** 從控制節點解除 `compute-cpu02` 的 `DOWN`，
讓控制服務要求 `slurmd` 重新註冊；只修改控制端的排程狀態，
不修改 VM 設定或重啟服務。

**已執行指令｜控制節點：**

```bash
scontrol update NodeName=compute-cpu02 State=RESUME
```

**實際結果：** 指令返回 shell，沒有終端輸出或錯誤訊息。

**目的與影響：** 再從控制節點查同一節點的排程狀態，
確認 `RESUME` 後能否重新接工作；這條指令只讀。

**已執行指令｜控制節點：**

```bash
sinfo -N -n compute-cpu02 -o '%N %T'
```

**實際輸出：**

```text
NODELIST STATE
compute-cpu02 idle
```

**判讀：** 控制節點已重新開放 `compute-cpu02` 接受 Slurm 工作。

## 16. 用同一份 CPU 計算核對節點恢復

`idle` 表示節點重新開放排程，接著要看計算工作能否完成。
現有的 `heat2d.cu` 包含 CPU 參考解，但程式仍須呼叫 CUDA 和 GPU，
不能直接放到兩台只有 CPU 的節點執行。
[heat2d_cpu.cpp](../project/workloads/heat2d_cpu.cpp) 沿用相同的中心熱源、
四鄰點更新式及預設的 1024×1024 格、200 次更新；
在兩台 CPU 節點上以相同的 Slurm 資源請求執行同一份程式，
比較執行主機、答案與退出狀態。
它只使用記憶體，不讀寫工作資料檔；預期總和取自模組 05 實測的
`cpu_sum=65535.998004`，容許浮點誤差 `0.1`。

**已執行指令｜控制節點，準備可執行檔：**

```bash
g++ -O2 -std=c++17 -Wall -Wextra -pedantic project/workloads/heat2d_cpu.cpp -o /tmp/heat2d_cpu_module06
```

**實際結果：** 編譯成功，沒有終端輸出；建立控制節點的
`/tmp/heat2d_cpu_module06`。這只是準備程式，沒有提交 Slurm 工作，
也不能用來比較運算節點的資源或計算結果。

**已執行指令｜控制節點，在 `compute-cpu02` 執行：**

```bash
sudo -iu a2264 srun -p cpu -w compute-cpu02 -N1 -n1 -c1 --mem=512M -t 00:02:00 \
  --chdir=/tmp --bcast /tmp/heat2d_cpu_module06
```

**目的與影響：** 申請 `compute-cpu02` 的 1 CPU、512 MiB、最多 2 分鐘，
由 `srun` 把控制節點 `/tmp/heat2d_cpu_module06` 的可執行檔送到該節點的
`/tmp` 後執行，不需在節點安裝編譯器或修改 Slurm 設定。
`--bcast` 會在目標節點建立暫存執行檔；`--chdir=/tmp` 指定其目錄。
**實際輸出：**

```text
host=compute-cpu02 grid=1024x1024 steps=200
sum=65535.998004 expected=65535.998004 abs_error=0.000000
cpu_ms=581.485 validation=PASS
```

**判讀：** 工作在 `compute-cpu02` 完成，總和與已知答案一致。
這是故障恢復後該節點實際接受工作的證據。

**已執行指令｜控制節點，在 `compute-cpu01` 執行：**

```bash
sudo -iu a2264 srun -p cpu -w compute-cpu01 -N1 -n1 -c1 --mem=512M -t 00:02:00 \
  --chdir=/tmp --bcast /tmp/heat2d_cpu_module06
```

**目的與影響：** 在另一台獨立 CPU 運算節點申請相同的 1 CPU、512 MiB、
最多 2 分鐘，並以 `--bcast` 將同一可執行檔放進該節點的 `/tmp` 執行。
這會短暫占用 `compute-cpu01` 資源並留下暫存執行檔，不改設定或服務。
**實際輸出：**

```text
host=compute-cpu01.novalocal grid=1024x1024 steps=200
sum=65535.998004 expected=65535.998004 abs_error=0.000000
cpu_ms=44855.795 validation=PASS
```

**判讀：** 兩台獨立 CPU 運算節點已用相同的 1 CPU、512 MiB 請求
完成同一份熱擴散工作，總和一致且都回報 `PASS`。
`compute-cpu01` 的實際主機名帶 `.novalocal` 後綴；
這裡比較的是工作可完成與答案一致，兩台硬體不同，
不以 `cpu_ms` 判定節點性能。故障期間的新工作轉移仍待驗證。

## 17. 故障期間的新 CPU 工作轉移

兩台獨立 CPU 節點已用相同資源請求完成同一份熱擴散工作。
這次讓 `compute-cpu02` 暫時不能接工作，觀察新提交且不指定節點的
`cpu` 分區工作是否落在 `compute-cpu01`。演練前佇列為空，
`compute-cpu02` 的 Zabbix server、agent 與 `slurmd` 均在執行。

**目的與影響：** 在 `compute-cpu02` 以 `sudo` 停止該 VM 的 `slurmd`。
這會使它暫時無法接 Slurm 工作，
Zabbix 的服務狀態監控預期會告警；不修改設定檔或其他節點。
復原時會在同一台 VM 啟動 `slurmd`，再依控制節點的實際狀態
決定是否執行 `RESUME`。

**已執行指令｜`compute-cpu02`：**

```bash
sudo systemctl stop slurmd
```

`systemctl stop` 只會停止這台 VM 的服務。指令返回後，須向 Slurm 控制端
核對節點狀態，並核對 Zabbix 的 Problem 事件，再提交新工作。

**實際結果：** 沒有終端輸出，已返回 `compute-cpu02` 的 shell 提示字元。
`slurmd` 停止指令已完成；排程器何時把節點標為不可接工作，須另查控制端狀態。

**目的與影響：** 在控制節點用 Slurm 客戶端查它對
`compute-cpu02` 的目前判斷。這條指令只讀；`idle` 表示控制端尚未隔離，
`down` 或帶 `*` 的無回應狀態表示不能把它當成可接工作的節點。

**已執行指令｜控制節點：**

```bash
sinfo -N -n compute-cpu02 -o '%N %T'
```

`-N` 逐節點顯示，`-n` 限定本次故障節點，格式只保留名稱與狀態；
檢查的是 Slurm 控制端的排程狀態，不是本機 systemd 服務狀態。

**實際輸出：**

```text
NODELIST STATE
compute-cpu02 idle
```

**判讀：** 服務剛停止後，控制端仍將節點列為 `idle`，尚未隔離；
此時不可提交新工作來判斷轉移落點。先查控制端的失聯判定時間，
再等待狀態更新。

**目的與影響：** 查目前 Slurm 控制端的 `SlurmdTimeout`，
了解它要等多久才會把未回報的運算節點判為失聯。
這條指令只讀設定，不修改控制端、服務或節點狀態。

**已執行指令｜控制節點：**

```bash
scontrol show config | grep -i '^SlurmdTimeout'
```

`scontrol show config` 讀取正在運行的 Slurm 設定；`grep`
只保留失聯逾時欄位。此值用來判讀稍後 `sinfo` 狀態更新的等待時間。

**實際輸出：**

```text
SlurmdTimeout           = 300 sec
```

**判讀：** 控制端在運算節點停止回報後，可能要約五分鐘才會判定失聯。
在確認 `compute-cpu02` 已離開 `idle` 前，不提交轉移測試工作。

**已執行指令｜控制節點，等待失聯判定後重查：**

```bash
sinfo -N -n compute-cpu02 -o '%N %T'
```

**實際輸出：**

```text
NODELIST STATE
compute-cpu02 down*
```

**判讀：** `down*` 表示控制端已將 `compute-cpu02` 排除可接工作狀態，
且目前沒有收到該節點回報；可以用不指定節點的新工作驗證落點。

本次沿用控制節點現有的 `/tmp/heat2d_cpu_module06`；
程式來源與先前編譯結果見上一節，不重做編譯。

**目的與影響：** 從控制節點提交一個不指定運算節點的 `cpu` 分區工作，
申請 1 CPU、512 MiB、最多 5 分鐘。`srun --bcast` 把現有執行檔
送到獲分配節點的 `/tmp` 並執行；工作會短暫占用該節點資源，
不修改 Slurm 設定或服務。輸出的 `host` 要確認落在
`compute-cpu01`，`sum` 與 `validation` 要核對已知答案。

**已執行指令｜控制節點：**

```bash
srun -p cpu -N1 -n1 -c1 --mem=512M -t 00:05:00 --chdir=/tmp --bcast /tmp/heat2d_cpu_module06
```

沒有使用 `-w` 指定節點，因此落點由 Slurm 從可用的 `cpu` 節點選出；
這次 `compute-cpu02` 已是 `down*`。`--chdir=/tmp` 是工作執行目錄，
`--bcast` 發送控制節點上的現有執行檔。

**實際輸出：**

```text
host=compute-cpu01.novalocal grid=1024x1024 steps=200
sum=65535.998004 expected=65535.998004 abs_error=0.000000
cpu_ms=46616.864 validation=PASS
```

**判讀：** 故障期間新提交且未指定節點的工作落在另一台獨立運算節點
`compute-cpu01`，答案與預期一致；`validation=PASS` 是程式自己的
答案檢查。執行後已回報工作正常完成；未另查 shell 退出碼。

`compute-cpu02` 的 `slurmd` 已由操作人員啟動，控制端仍顯示 `down`；
在目前尚未設定自動恢復的狀態下，服務啟動不會自動清除保留的 `DOWN`。

### 設定失聯後自動恢復

目前四節點設定未指定 `ReturnToService`，預設值 `0` 會保留 `DOWN`。
依 [Slurm 官方說明](https://slurm.schedmd.com/slurm.conf.html)，
`ReturnToService=1` 只讓因失聯而 `DOWN` 的節點在有效重新註冊後
自動開放；其他原因仍須人工判斷，工作結果也須另驗。

**目的與影響：** 在控制節點修改工作樹中的
[four-node-slurm.conf](../project/slurm/four-node-slurm.conf) 來源檔，
加入 `ReturnToService=1`。這一步只改來源檔，
四台 VM 各自的 `/etc/slurm/slurm.conf` 不會因此改變；
服務也不會重載或重啟。來源檔目前需管理權限才能寫入。

**已執行指令｜控制節點的 `hpc-arch` 目錄：**

```bash
sudo vi project/slurm/four-node-slurm.conf
```

在 `SlurmdSpoolDir=/var/spool/slurmd` 後加入 `ReturnToService=1`，
存檔離開後核對檔案內容，再執行部署。

**實際結果：** 編輯器沒有終端輸出；工作樹來源檔第 33 行已核對為
`ReturnToService=1`。此時只確認來源檔內容，尚未套用到任何 VM。

**目的與影響：** 用既有
[slurm-four-node.yml](../project/ansible/slurm-four-node.yml)
正式部署來源設定。playbook 先在控制節點確認佇列為空，
接著更新三台運算 VM 各自的 `/etc/slurm/slurm.conf` 並檢查 `slurmd -G`，
再更新控制節點自己的同名檔案、執行 `scontrol reconfigure`，
最後在設定有變更時重啟三台運算 VM 的 `slurmd`。
各 VM 的舊檔由 copy 備份；運算服務在重啟期間暫時不能接工作。

**已執行指令｜控制節點的 `project/ansible` 目錄：**

```bash
sudo ansible-playbook slurm-four-node.yml
```

**實際輸出重點：** 佇列查詢 `ok`；三台運算 VM 的設定複製均為
`changed`，`slurmd -G` 檢查均為 `ok`；控制節點設定複製與
`scontrol reconfigure` handler 均為 `changed`；三台運算 VM 的
`slurmd` 重啟均為 `changed`。Play recap 顯示四台皆為
`failed=0`、`unreachable=0`。

**判讀：** 來源設定已正式複製到四台各自的目標檔，控制端已重載，
三台運算服務已重啟。部署任務完成，接著核對控制端實際載入值與節點狀態。

**已執行指令｜控制節點：**

```bash
scontrol show config | rg '^ReturnToService'
sinfo -N -n compute-cpu02 -o '%N %T'
```

**實際結果：**

```text
ReturnToService         = 1
NODELIST STATE
compute-cpu02 idle
```

**判讀：** 控制端已載入 `ReturnToService=1`；部署重啟 `slurmd` 後，
`compute-cpu02` 回到可排程的 `idle`，這次沒有執行人工 `RESUME`。
此處驗證的是失聯節點重新開放；故障期間新工作落到 `compute-cpu01`
的計算結果已在前節核對。

## 本模組結果

Zabbix 已收到 `slurmd` 狀態資料，並記錄停止服務時的 `PROBLEM`；
恢復由操作人員回報，但未保留 `OK` 事件畫面或時間，因此不宣稱
已獨立核對該事件的原始紀錄。

Slurm 已在故障時將 `compute-cpu02` 標為 `down*`；未指定節點的新 CPU
工作落到 `compute-cpu01` 並得到 `validation=PASS`。節點恢復後，
`ReturnToService=1` 已由控制端確認，`compute-cpu02` 回到 `idle`，
此輪未執行人工 `RESUME`。兩台 CPU 節點也已用相同資源請求完成
同一份熱擴散工作。至此結束本模組實作，不重做已完成的故障演練。
