# 模組 01：HPC 架構與單節點排程

[能力路線](ROADMAP.md)｜職缺核心：軟硬體集群架構規劃；支撐能力：計算機架構、Linux 服務管理。

## 先教會的概念

### HPC、叢集與節點

HPC 是高效能運算：當工作需要大量計算、記憶體或資料傳輸時，用適合的運算資源執行它。

**叢集**是被組織起來共同提供運算能力的多台電腦；
其中每一台叫**節點**，可以是實體伺服器，也可以是 VM。
「控制」「運算」「儲存」是節點負責的角色，小型實驗可以讓一台機器兼任多個角色。

例：使用者提交一個計算工作；
**控制節點**接收工作並決定分給哪台機器，**運算節點**實際執行程式，
**儲存節點**提供程式讀取的資料與結果存放位置。
**登入節點**則是使用者進入叢集提交工作的入口。

之後要建立的 GPU 節點仍是運算節點，只是多了 GPU 可供工作使用。
目前只有一台 VM，起步時會暫時兼任控制與運算角色；
這是在學兩個角色如何配合，不等於已建成多節點叢集。

### 工作與排程器

**工作**是使用者提交的一次執行要求，包含要跑的程式和需要多少 CPU、記憶體或 GPU。
**排程器**把這個要求與各節點可用的資源配對，決定何時、在哪裡執行。

Slurm 是本課程選用的排程器：slurmctld 維護工作與節點狀態，
slurmd 在運算節點啟動工作；partition 是一組允許提交工作的節點。

MUNGE 是讓這些服務確認彼此身分的常見驗證機制，
類似叢集內服務之間的身分證明；它不是使用者登入的密碼。

### 從安裝到執行工作的流程與目前位置

| 步驟 | 作用 | 目前證據 |
|---|---|---|
| 安裝 Slurm 與 MUNGE | 提供排程服務、運算服務與身分驗證服務 | 套件與版本已記錄於下文 |
| 建立 MUNGE 金鑰並啟動服務 | 讓同一驗證範圍內的請求可驗證身分 | 本機 `a2264` 的憑證驗證成功；尚非跨節點驗證 |
| 設定並啟動 `slurmctld`、`slurmd` | 讓這台 VM 同時擔任控制與運算節點 | 兩服務曾回報 `active`，節點曾顯示 `idle` |
| 執行 `srun` | 直接申請資源並執行一個工作步驟 | `a2264` 執行 `hostname` 成功，輸出為本機節點名 |
| 提交 `sbatch` 腳本 | 將批次工作送入佇列，稍後由 Slurm 執行 | 工作 2 已被接受，輸出檔證實腳本已執行 |
| 檢查批次結果與節點狀態 | 確認工作執行結果及節點是否仍可排程 | 腳本輸出已取得，節點目前為 `idle`；工作退出狀態未取得 |

此流程只對應目前的單台 VM；獨立運算節點和跨節點工作尚未建立或驗證。

### 資源規劃

規劃節點時還要看 CPU 實體核心與邏輯執行緒、記憶體容量和 NUMA 位置、
磁碟吞吐／延遲、網卡頻寬／延遲。

GPU 節點另外考慮顯示記憶體、CPU 與 GPU 間的 PCIe 傳輸、
卡與網卡的拓撲及供電／散熱。

這些先用規格和拓撲理解，模組 04 有 GPU VM 後再驗證可觀察部分；單卡 VM 不能驗證多 GPU 互連。

例：若只有 2 個可用 CPU，工作要求 4 個 CPU 卻停在等待，
先比對工作請求、節點實際配置和分區限制；
不能因為 squeue 顯示等待就直接認定服務壞了。

## 指令先講清楚，再操作

首次使用時解釋：

- `lscpu`／`free`／`lsblk` 各查 CPU、記憶體、磁碟；
- `systemctl status` 查服務狀態，`journalctl -u` 查該服務日誌；
- `sinfo` 看分區與節點，`squeue` 看工作佇列，`scontrol show node` 查節點詳細狀態；
- `sbatch` 提交批次腳本，`srun` 執行工作步驟。

提交成功不等於工作成功，還要查退出狀態、輸出與實際主機名。
命令的選項、套件和設定檔路徑依當時發行版及版本確認，不能現在假定皆已安裝。

## 實作主線與過關證據

先用現有 VM 的資源與限制決定單節點可承受的工作規模，
寫出 head／CPU compute／GPU compute／storage 的目標拓撲、
目前共用角色和不能推論的硬體能力。

GPU 節點先比較一張卡的候選型號、記憶體與用途，不在此時建立。
取得同意後，依版本文件安裝與設定單節點 Slurm；
由一般工作帳號提交正常與故意不符合資源條件的工作，
從排程狀態、服務日誌和輸出解釋結果。

可恢復的服務故障只在確認沒有重要工作後演練，事先寫明復原方式。

成果是 project/docs/ 的拓撲與資源假設、project/workloads/ 的可重跑批次腳本，
以及本文件的真實工作與診斷紀錄。
過關時應能回答：工作在哪個節點跑、請求和實得資源如何核對、
等待／失敗時先看哪一層；單節點成功不得寫成跨節點能力。

開始第一次帶練前，先在本文件追加本次確定的 VM 指令、
每條用途及檔案／服務影響；取得結果後再追加實際輸出與解釋。
現在沒有實作成果。

## 第一次帶練：確認單節點排程環境

本次要把目前 VM 視為暫時共用控制與運算角色的教學節點，
先確認作業系統，再決定與其版本相容的 Slurm 安裝來源及後續操作。
GPU 節點此時仍是規劃，並未建立。

這一步不把已知的帳號、路徑與一般 Linux 指令重新當課程練習。

第一條確定要執行的 VM 指令是 `cat /etc/os-release`：
讀取作業系統名稱與版本，用來選擇正確的套件與服務文件。
它只讀系統資訊，不建立、修改或刪除檔案，也不改服務或雲端資源。
後續精確指令須依這份實際輸出決定，不能先假定發行版。

### 1. 確認作業系統

**實際指令：**`cat /etc/os-release`。

**重點輸出：**

```text
NAME="AlmaLinux"
VERSION="10.2 (Lavender Lion)"
ID="almalinux"
ID_LIKE="rhel centos fedora"
VERSION_ID="10.2"
PLATFORM_ID="platform:el10"
```

**判讀：**這台 VM 是 AlmaLinux 10.2，屬 RHEL 相容發行版系列；
後續要用 EL10／AlmaLinux 10.2 對應的套件與服務文件。
`ID_LIKE` 說明相容家族，不代表可直接套用其他版本的套件來源。
本命令只讀檔案，未安裝或變更任何套件、服務或雲端資源；
目前尚未判定 Slurm 是否已安裝。

### 2. 確認是否已有 Slurm 套件

預定 VM 指令：`rpm -qa 'slurm*'`。
RPM 是 AlmaLinux 的已安裝套件資料庫；`-qa` 查詢已安裝套件，
`'slurm*'` 只挑名稱符合 Slurm 的項目。
這一步用來決定後續是檢查現有安裝，還是先研究可用套件來源。
沒有輸出只代表 RPM 資料庫找不到符合套件，尚不能推論可用倉庫沒有 Slurm。
本指令只讀套件資料庫，不修改任何檔案、服務或雲端資源。

實際指令：`rpm -qa 'slurm*'`。

實際結果：沒有輸出，正常返回 shell 提示字元。

判讀：目前 RPM 資料庫中沒有名稱符合 `slurm*` 的已安裝套件；
下一步應檢查已啟用的套件倉庫，不能據此斷定 Slurm 無法安裝。

### 3. 確認套件倉庫

**套件倉庫**是供 DNF 查詢與安裝軟體的來源清單，
和 RPM 的「本機已安裝套件資料庫」不同。
例：剛才 RPM 查不到 Slurm，只說明機器沒裝；
若某個已啟用倉庫提供 Slurm，DNF 才可能找到對應版本。

本次預定指令 `dnf repolist --enabled` 用來列出已啟用的倉庫名稱，
不安裝套件、不變更倉庫設定或服務。
是否要新增倉庫或安裝軟體，須等看過實際結果後另行確認。

**實際指令：**`dnf repolist --enabled`。

**重點輸出：**

```text
appstream               AlmaLinux 10 - AppStream
baseos                  AlmaLinux 10 - BaseOS
crb                     AlmaLinux 10 - CRB
extras                  AlmaLinux 10 - Extras
google-cloud-sdk        Google Cloud SDK
google-compute-engine   Google Compute Engine
```

**判讀：**已啟用 AlmaLinux 基礎／應用／開發相依套件來源與 Google Cloud 相關來源；
清單中沒有 EPEL。
EPEL 是 Enterprise Linux 的額外社群套件倉庫，但尚未確認是否需要它。
先查現有倉庫是否提供 Slurm，不因猜測而新增倉庫。

### 4. 查現有倉庫能提供哪些 Slurm 套件

預定 VM 指令：`dnf repoquery --available 'slurm*'`。
`repoquery` 查的是已啟用倉庫中的**可取得套件**，與 `rpm -qa` 的「已安裝」不同；
`--available` 排除僅已安裝的項目。
DNF 可能更新本機套件索引快取並連線讀取倉庫資料，
但不安裝套件、不啟用新倉庫，也不改服務。
如果沒有結果，只能說目前啟用的倉庫查不到符合套件，不代表所有來源都沒有。

### 5. Slurm 安裝結果

已安裝：`slurm-26.05.4-1.el10.x86_64`、`slurm-slurmctld-26.05.4-1.el10.x86_64`、
`slurm-slurmd-26.05.4-1.el10.x86_64`、`munge-0.5.15-11.el10_1.x86_64`、
`munge-libs-0.5.15-11.el10_1.x86_64`、`munge-devel-0.5.15-11.el10_1.x86_64`。

## VM 的 CPU 配置

### `lscpu`：VM 可見的 CPU

Slurm 要知道運算節點有多少可分配的 CPU。
這裡的「邏輯 CPU」是作業系統看見、可排程的執行單位；
在 VM 內看到的是雲端提供的虛擬 CPU 配置，不能直接當成實體伺服器的核心數。

本次指令：`lscpu`。它只讀取 VM 可見的 CPU 資訊；
重點看 `CPU(s)`（邏輯 CPU 總數）、`Thread(s) per core`（每核心的執行緒數）、
`Core(s) per socket`（每插槽的核心數）與 `Socket(s)`（插槽數）。
這一步不建立或修改檔案，不更動 Slurm 服務或雲端資源。
收到實際輸出後再決定節點的 CPU 設定。

**實際執行 `lscpu`；重點輸出：**

```text
CPU(s):                  2
Thread(s) per core:      2
Core(s) per socket:      1
Socket(s):               1
Hypervisor vendor:       KVM
NUMA node(s):            1
NUMA node0 CPU(s):       0,1
```

**判讀：**這台 VM 呈現 2 個邏輯 CPU、1 個虛擬核心／插槽和 1 個 NUMA 節點；
`KVM` 表示它是虛擬機，不能由此推論實體主機的核心配置。
後續先以 VM 實際可見資源設定教學節點，不把它寫成實體叢集容量。

### NUMA 節點是什麼

NUMA 是多處理器電腦的一種 CPU／記憶體配置：
CPU 存取自己附近的記憶體通常比存取其他 CPU 群附近的記憶體快。
系統把一組 CPU 與其鄰近記憶體稱為一個 NUMA 節點。

這裡的「節點」是**同一台機器內部**的硬體分組，不是叢集裡的一台 VM。
這台 VM 只呈現 1 個 NUMA 節點，CPU 0、1 都在其中，
因此不能拿它測試跨 NUMA 節點的記憶體存取差異；
也不能推論底層實體主機的 NUMA 拓撲。

### `slurmd -C`：Slurm 偵測的資源

下一條指令是 `slurmd -C`：讓 Slurm 的運算節點程式列出它偵測到的硬體配置，
尤其是 `CPUs`、插槽／核心／執行緒與 `RealMemory`（MiB）。
`-C` 只列印硬體配置後結束，不啟動服務，也不修改設定檔；
輸出將用來核對之後的 `slurm.conf` 節點設定。
若執行失敗，也保留錯誤訊息供判斷。
參考：[Slurm 官方 slurmd 文件](https://slurm.schedmd.com/slurmd.html)。

**實際執行 `slurmd -C`；輸出：**

```text
NodeName=instance-20260923-104239 CPUs=2 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=2 RealMemory=3906
UpTime=0-23:29:49
```

**判讀：**Slurm 偵測到的 CPU 拓撲與 `lscpu` 一致；
`RealMemory=3906` 表示它偵測到約 3906 MiB 記憶體，
不是保證所有記憶體都能分配給工作。
`UpTime` 是當時 VM 的開機運作時間。
這是硬體偵測結果，還不是可用的 Slurm 節點或已啟動的排程服務。

## Slurm 控制服務帳號

### 建立帳號

`slurmctld` 是排程控制服務；它需要一個專用的 Linux 身分來管理自己的狀態檔，
不應把一般工作帳號或 root 當作 `SlurmUser`。
這個 `slurm` 帳號不是學員用來登入或提交工作的帳號。
建立前已查詢：本機尚無 `slurm` 使用者或同名群組，且 `/sbin/nologin` 存在。

本次指令：`useradd -r -M -U -s /sbin/nologin slurm`。
`-r` 建立系統服務帳號，`-M` 不建立家目錄，`-U` 建立同名群組，
`-s /sbin/nologin` 禁止一般互動登入。
它會修改 VM 的 `/etc/passwd`、`/etc/shadow`、`/etc/group`、`/etc/gshadow`，
不建立工作檔、不改 Slurm 設定、不啟動服務，也不改雲端資源。
若尚未投入使用而需要撤銷，可先確認無服務或檔案依賴，
再刪除該帳號與群組；不在此時執行撤銷。

學員回報已執行建立指令。

### 驗證帳號

驗證指令可連續執行：`id slurm` 檢查 UID、主要 GID 與群組；
`getent passwd slurm` 檢查帳號紀錄中的預設家目錄**路徑**和登入 shell。
兩條都是只讀查詢，不修改系統。
`getent` 顯示的路徑不代表家目錄真的已建立；
若要確認 `-M` 的效果，須另查目錄是否存在。

**實際結果：**

```text
$ id slurm
uid=994(slurm) gid=994(slurm) groups=994(slurm)
$ getent passwd slurm
slurm:x:994:994::/home/slurm:/sbin/nologin
$ ls -ld /home/slurm
ls: cannot access '/home/slurm': No such file or directory
```

**判讀：**`slurm` 專用帳號與同名群組已建立，UID／GID 都是 994；
登入 shell 是 `/sbin/nologin`。
帳號資料庫仍記錄預設家目錄路徑 `/home/slurm`，但實際目錄不存在，
符合 `-M`「不建立家目錄」的效果。
這一步尚未建立 Slurm 設定或啟動任何服務。

## MUNGE 驗證

### 原理

MUNGE 是供叢集程式使用的驗證服務：
它依請求者的 Linux UID／GID 產生短效憑證，讓另一端確認請求身分。
Slurm 的控制端與運算端會用它互相驗證；它不是學員的登入密碼。

參與同一叢集的主機需要一致的使用者／群組身分與共享金鑰。
這台 VM 先完成單機驗證，不把它寫成跨節點成果。

`munge` 是執行驗證服務的帳號，
與剛建立、供 `slurmctld` 使用的 `slurm` 帳號不同。
金鑰由每台參與驗證的主機上的 MUNGE 服務使用，一般使用者不讀取金鑰。
例如 `a2264` 執行 `srun` 時，Slurm 透過本機 MUNGE 服務為這次請求產生短效憑證；
憑證標示發出請求的程序所屬 UID／GID，控制端據此驗證請求者身分。
若是 Slurm 服務之間發出請求，憑證標示的則是發出請求的服務程序身分。
身分通過驗證後，Slurm 仍須分配資源，運算端才會啟動程式；
MUNGE 本身不負責排程，也不把金鑰交給 `a2264`。
將來增加獨立控制、運算或提交主機時，這些需要 MUNGE 驗證的主機須安全地使用同一把金鑰，
並保持使用者 UID／GID 一致；目前只做過本機驗證，沒有跨節點證據。
參考：[MUNGE 官方說明](https://dun.github.io/munge/)、
[Slurm 驗證文件](https://slurm.schedmd.com/authentication.html)。

### 檢查金鑰與目錄

先用 `stat -c '%U:%G %a %s %n' /etc/munge/munge.key`
只看金鑰檔的擁有者／群組、權限、大小（位元組）與路徑，
**不讀取或貼出金鑰內容**。

`stat` 若顯示檔案不存在，就要在確認路徑後建立；
若已存在，先判斷權限與所有權，不覆寫它。
這一步不修改檔案或服務。
依 Slurm 官方建議，金鑰應由 `munge` 擁有，且其他使用者不可讀寫。

實際執行 `stat -c '%U:%G %a %s %n' /etc/munge/munge.key`，
回報 `No such file or directory`：金鑰尚不存在，不會覆寫舊金鑰。

另查到 `/etc/munge`、`/var/lib/munge`、`/var/log/munge`
三個套件目錄目前權限均為 `700`，但實際擁有者是 `nobody:nobody`；
RPM 套件記錄的預期擁有者是 `munge:munge`，
`rpm -V munge` 也只對這三個目錄回報 `UG`（使用者、群組不符）。
目前原因未確認，不猜測為何變成 `nobody`。

### 修正目錄擁有者

先執行 `chown munge:munge /etc/munge /var/lib/munge /var/log/munge`，
只修正這三個已確認目錄的擁有者與群組；
不遞迴、不建立或讀取金鑰、不啟動服務。

緊接著執行唯讀的
`stat -c '%U:%G %a %n' /etc/munge /var/lib/munge /var/log/munge`
驗證三個目錄均為 `munge:munge`、權限仍為 `700`。
驗證通過後，再由 `munge` 身分使用套件自帶的 `mungekey` 建立金鑰。

**實際回報的驗證輸出：**

```text
munge:munge 700 /etc/munge
munge:munge 700 /var/lib/munge
munge:munge 700 /var/log/munge
```

### 建立金鑰

三個目錄的擁有者與權限已符合預期。
接著執行 `sudo -u munge /usr/sbin/mungekey --create --keyfile /etc/munge/munge.key`：
以 `munge` 身分使用 MUNGE 套件提供的工具產生共享祕密金鑰；
未使用 `--force`，若路徑已存在就不覆寫。

這會在 VM 的 `/etc/munge/` 建立祕密檔，
不改專案檔案或雲端資源，也不啟動服務。

完成後用 `stat -c '%U:%G %a %s %n' /etc/munge/munge.key`
只驗證擁有者、權限及大小，不查看或貼出金鑰內容。
金鑰不能放進 Markdown、Git 或公開位置。

`mungekey` 是 MUNGE 套件提供的金鑰管理工具，
不是 Linux 通用的建金鑰指令；
`sudo -u munge` 只是切換執行身分，`stat` 是通用的檔案屬性查詢。

實際建立指令沒有輸出；
驗證結果為 `munge:munge 600 128 /etc/munge/munge.key`。
這表示金鑰檔由 `munge` 擁有、大小 128 位元組，
只有擁有者可讀寫；未公開金鑰內容。
權限 `600` 已阻止其他使用者讀寫，暫無必要再改權限。

### 啟動服務並驗證一般帳號

接著執行 `systemctl enable --now munge`：啟用 MUNGE 開機自動啟動，
並立刻啟動本機 `munged` 驗證服務。

這會改 VM 的 systemd 啟用狀態並啟動服務，
不修改金鑰、不動雲端資源；
若需撤銷服務啟用與執行狀態，可用 `systemctl disable --now munge`，
但它不會刪除金鑰。

隨後可連續執行兩條只讀驗證：`systemctl is-active munge` 檢查服務是否為 `active`；
`sudo -u a2264 munge -n | unmunge` 讓一般帳號產生不含資料內容的短效憑證
並立即解碼，確認驗證服務可回報其 UID／GID。
這條管線不列印共享金鑰，也不保存憑證檔。

**實際結果：**`systemctl enable --now munge` 成功建立開機啟用連結；
`systemctl is-active munge` 回報 `active`。
`sudo -u a2264 munge -n | unmunge` 的重點輸出：

```text
STATUS:          Success (0)
TTL:             300
CIPHER:          aes128 (4)
MAC:             sha256 (5)
UID:             a2264 (1000)
GID:             a2264 (1005)
LENGTH:          0
```

**判讀：**MUNGE 服務目前運作中；
一般帳號 `a2264` 的憑證已被成功驗證，UID／GID 正確。
`TTL=300` 表示這張憑證的有效時間為 300 秒，
`LENGTH=0` 是因為 `munge -n` 不放入資料內容。
這只證明本機 MUNGE 驗證正常，尚未證明 Slurm 排程器已設定或可提交工作。

## 單節點 Slurm 設定

`slurm.conf` 是 Slurm 控制端、運算端與使用者命令共同讀取的設定檔。
它要回答「誰是控制器、哪台是運算節點、能分配多少資源、工作能送到哪個分區」。
**分區**（partition）是可提交工作的節點集合；本次 `debug` 分區只有這台 VM。

本次設定檔：[single-node-slurm.conf](../project/slurm/single-node-slurm.conf)。
專案檔放在 repo 的 `project/slurm/`，部署後的設定檔在 VM 的 `/etc/slurm/`；
`/var/spool/slurmctld` 與 `/var/spool/slurmd` 則是服務執行時使用的目錄，
不是放設定檔的地方，也不屬於 repo。
這份設定讓同一台 VM 同時擔任控制與運算節點，使用 MUNGE 驗證，
將 2 個邏輯 CPU 和 3000 MiB 記憶體納入資源排程，
並把運算節點放進預設的 `debug` 分區。
控制端與運算端所需的狀態目錄下一步才建立。
各設定項目的用途與限制直接見設定檔內的中文註解。

本次要在 VM 執行的指令是
`install -D -o root -g root -m 0644 /root/hpc-arch/project/slurm/single-node-slurm.conf /etc/slurm/slurm.conf`。
`install -D` 會建立必要的上層目錄並複製設定檔，
`-o root -g root -m 0644` 設定擁有者與讀取權限。
已確認 `/etc/slurm/slurm.conf` 目前不存在，因此不會覆寫既有設定。
它只建立 VM 的 `/etc/slurm/slurm.conf`，不碰 MUNGE 金鑰、不啟動或啟用 Slurm 服務，
也不修改雲端資源。
若需撤銷這一步，應在確認檔案仍是本次建立且服務未依賴後移除該設定檔；不直接刪除其他設定。

完成後可連續執行兩條只讀驗證：
`stat -c '%U:%G %a %n' /etc/slurm/slurm.conf` 檢查檔案為 `root:root 644`；
`cmp /root/hpc-arch/project/slurm/single-node-slurm.conf /etc/slurm/slurm.conf && echo same`
逐位元組比較來源與安裝後的設定檔，完全一致才輸出 `same`。
這些驗證不啟動服務，也不輸出任何金鑰。

**實際結果：**`install` 完成且沒有錯誤訊息；
`stat` 顯示 `/etc/slurm/slurm.conf` 為 `root:root 644`，
`cmp` 輸出 `same`，表示安裝檔與專案中的來源檔逐位元組相同。
這只確認設定檔已正確放置；Slurm 控制與運算服務尚未啟動。

後來只在專案設定檔加入中文註解，設定值未改；
VM 上的已安裝檔仍是加入註解前的版本，所以上述 `cmp` 結果僅代表當時一致。
下次部署前須重新複製專案設定檔，才能讓兩份檔案再度一致。

### 建立控制端狀態目錄

接下來在 VM 執行
`install -d -o slurm -g slurm -m 0700 /var/spool/slurmctld`。
這會建立設定檔指定的控制端狀態目錄，
並讓執行控制服務的 `slurm` 帳號擁有及寫入；
`0700` 限制其他帳號讀寫。
它只影響 VM 的 `/var/spool/slurmctld`，不修改 repo、其他目錄或雲端資源，
也不啟動 Slurm。
隨後以只讀指令
`stat -c '%U:%G %a %n' /var/spool/slurmctld`
驗證擁有者與權限。
若要復原，須先確認目錄沒有服務狀態資料，不能直接刪除。

**實際結果：**學員執行 `install -d -o slurm -g slurm -m 0700 /var/spool/slurmctld`，
指令沒有錯誤輸出；`stat` 回報
`slurm:slurm 700 /var/spool/slurmctld`。
控制端狀態目錄已存在且擁有者、權限符合設定，尚未啟動控制服務。

### 建立運算端暫存目錄

接下來在 VM 執行
`install -d -o root -g root -m 0755 /var/spool/slurmd`。
這會建立設定檔指定的運算端暫存目錄，供以 root 執行的 `slurmd` 使用；
目錄擁有者為 `root`，其他帳號只可進入與讀取目錄清單，不能寫入。
它只影響 VM 的 `/var/spool/slurmd`，不修改 repo 或雲端資源，
也不啟動服務。
隨後以只讀指令
`stat -c '%U:%G %a %n' /var/spool/slurmd`
驗證擁有者與權限。
若要復原，須先確認目錄沒有工作暫存資料，不能直接刪除。

**實際結果：**學員執行 `install -d -o root -g root -m 0755 /var/spool/slurmd`，
指令沒有錯誤輸出；`stat` 回報
`root:root 755 /var/spool/slurmd`。
運算端暫存目錄已存在且擁有者、權限符合預期，尚未啟動運算服務。

### 同步加上註解的設定檔

接下來在 VM 重跑
`install -D -o root -g root -m 0644 /root/hpc-arch/project/slurm/single-node-slurm.conf /etc/slurm/slurm.conf`。
這會以專案中的版本覆寫先前安裝的設定檔；
兩版的設定值相同，差別是新增中文註解。
影響僅限 VM 的 `/etc/slurm/slurm.conf`，不啟動服務或修改雲端資源。
隨後以只讀指令
`cmp /root/hpc-arch/project/slurm/single-node-slurm.conf /etc/slurm/slurm.conf && echo same`
確認兩份檔案完全一致。
若要還原先前版本，可從版本紀錄取回原檔再重新安裝；
這次不直接刪除設定檔。

**實際結果：**學員重新執行 `install` 後，
`cmp /root/hpc-arch/project/slurm/single-node-slurm.conf /etc/slurm/slurm.conf && echo same`
輸出 `same`。
專案設定檔與 VM 安裝檔再次完全一致；這仍未證明服務能啟動。

### 啟動控制服務

接下來在 VM 執行 `systemctl start slurmctld`，
啟動控制節點的排程服務，不設定開機自動啟動。
它會讓服務讀取 `/etc/slurm/slurm.conf`，
並可能在 `/var/spool/slurmctld` 寫入排程狀態；
不修改 repo 或雲端資源。
隨後以 `systemctl is-active slurmctld` 只讀確認服務是否為 `active`。
如果要停止，可用 `systemctl stop slurmctld`；
已寫入的狀態資料不會因停止服務而自動刪除。

**實際結果：**學員執行 `systemctl start slurmctld` 後，
`systemctl is-active slurmctld` 回報 `active`。
控制服務目前正在執行，但尚未設定開機自動啟動；
這也還不能證明運算服務與提交工作正常。

### 啟動運算服務並檢查節點

接下來在 VM 執行 `systemctl start slurmd`，
啟動這台 VM 的運算端服務，不設定開機自動啟動。
它會讀取 `/etc/slurm/slurm.conf`，
可能在 `/var/spool/slurmd` 寫入工作暫存資料，並向控制服務註冊節點；
不修改 repo 或雲端資源。
隨後以兩條只讀指令驗證：
`systemctl is-active slurmd` 檢查服務是否正在執行；
`sinfo -N` 列出 Slurm 看到的節點及狀態，確認節點是否進入排程器。
若要停止，可用 `systemctl stop slurmd`；
停止服務不會自動刪除可能留下的暫存資料。

**實際結果：**學員回傳：

```text
$ systemctl is-active slurmd
active
$ sinfo -N
NODELIST                  NODES PARTITION STATE
instance-20260923-104239      1    debug* idle
```

`active` 表示運算服務正在執行；
節點列中的 `1` 是列出的節點數，`debug*` 表示預設分區，
`idle` 表示節點已註冊且目前可供排程。
尚未驗證一般帳號的工作能真正執行。

### 驗證一般帳號能執行工作

接下來在 VM 執行
`sudo -iu a2264 srun -p debug -N1 -n1 /usr/bin/hostname`。
`sudo -iu a2264` 讓這次工作以一般帳號及其登入環境執行，
而不是沿用 root 身分與目前的 `/root/hpc-arch` 工作目錄。
`srun` 向 Slurm 申請資源並執行命令；
`-p debug` 指定分區，`-N1` 申請一個節點，`-n1` 啟動一個工作行程。
`hostname` 只回報實際執行的節點名稱。
這會短暫佔用 VM 的排程資源，可能留下 Slurm 工作狀態，
不建立 repo 檔案，也不修改雲端資源；工作結束後資源應自動釋放。

**實際結果：**學員回傳：

```text
$ sudo -iu a2264 srun -p debug -N1 -n1 /usr/bin/hostname
instance-20260923-104239
```

命令成功返回，輸出的主機名與設定的運算節點相同。
這證明一般帳號可經 Slurm 在本機運算節點執行即時工作；
尚未驗證批次腳本、資源限制或跨節點執行。

### 準備可重跑的批次工作

下一步使用 [node-smoke.sbatch](../project/workloads/node-smoke.sbatch)
驗證一般帳號提交批次工作、資源請求與工作輸出。
腳本請求 `debug` 分區的一個節點、一個工作行程、一個 CPU、256 MiB 記憶體，
最長執行兩分鐘；執行後輸出工作 ID、使用者、節點和請求的資源值。
`#SBATCH` 行是提交時由 Slurm 讀取的工作參數，
`slurm-%j.out` 是工作輸出檔名，其中 `%j` 會替換為實際工作 ID。
這些數值可驗證排程器收到的請求，不能單憑輸出宣稱核心層資源隔離已生效。

一般帳號不能穿越 `/root` 讀取 repo 內腳本，
因此先在 VM 執行
`install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/node-smoke.sbatch /home/a2264/node-smoke.sbatch`。
這會複製腳本到使用者家目錄並交由 `a2264` 擁有；
`sbatch` 只需讀取腳本，不要求可執行位元。
不啟動工作、不改服務或雲端資源。
隨後以只讀指令
`stat -c '%U:%G %a %n' /home/a2264/node-smoke.sbatch`
及
`cmp /root/hpc-arch/project/workloads/node-smoke.sbatch /home/a2264/node-smoke.sbatch && echo same`
確認部署副本的擁有者、權限與內容。
若之後要清理，先確認檔案仍是這次部署的副本，再移除該檔；
不清理使用者家目錄的其他檔案。

**實際結果：**學員回傳：

```text
$ stat -c '%U:%G %a %n' /home/a2264/node-smoke.sbatch
a2264:a2264 644 /home/a2264/node-smoke.sbatch
$ cmp /root/hpc-arch/project/workloads/node-smoke.sbatch /home/a2264/node-smoke.sbatch && echo same
same
```

副本由 `a2264` 擁有、可供 `sbatch` 讀取，內容與 repo 腳本相同。

### 提交批次工作

接下來在 VM 執行
`sudo -iu a2264 sbatch /home/a2264/node-smoke.sbatch`。
`sbatch` 會把腳本交給控制服務排隊執行，
而不是像先前的 `srun` 一樣等待工作執行完才返回；
成功提交時會回報工作 ID，尚不能據此斷定工作成功。
因使用 `sudo -iu a2264`，提交工作目錄是 `/home/a2264`；
執行後預期在該處留下 `slurm-<工作 ID>.out`，
Slurm 也會產生短暫的排程與執行狀態。
這次不改 repo、服務設定或雲端資源。
若工作需要中止，先查明工作 ID 與狀態，再用 `scancel` 取消該工作；
取消不會自動刪除已產生的輸出檔。

**實際結果：**

```text
$ sudo -iu a2264 sbatch /home/a2264/node-smoke.sbatch
Submitted batch job 2
```

控制端已接受批次工作並給予 ID `2`；
這不表示工作已執行或成功結束。

接著以兩條只讀指令檢查這個工作：
`sudo -iu a2264 squeue -j 2` 查看它是否仍在等待或執行；
`sudo -iu a2264 cat /home/a2264/slurm-2.out`
讀取腳本設定的工作輸出。
若佇列沒有工作列，只代表工作已離開目前佇列，不能單憑此判定成功；
若輸出檔尚未出現，可能是工作還沒開始，須再查排程狀態。
兩條指令只讀，不改檔案、服務或雲端資源。

**本次查詢結果：**

```text
$ sudo -iu a2264 squeue -j 2
slurm_load_jobs error: Invalid job id specified
```

目前 `squeue` 無法從即時佇列查到工作 2。
這可能是工作已離開佇列；單憑這則錯誤不能判定它成功或失敗，
也不能補寫尚未取得的工作輸出或退出狀態。
接著讀取 `/home/a2264/slurm-2.out`，確認是否有腳本實際執行的輸出。

**實際輸出：**

```text
$ sudo -iu a2264 cat /home/a2264/slurm-2.out
job_id=2
user=a2264
node=instance-20260923-104239
requested_nodes=1
requested_cpus_per_task=1
requested_memory_mb=256
```

工作 2 的腳本確實以 `a2264` 身分在本機節點執行，
並印出一個節點、一個行程用的 CPU 與 256 MiB 記憶體請求值。
腳本已執行到最後一條 `printf`，但輸出檔沒有記錄 Slurm 的工作退出狀態；
這些請求值也不證明 CPU 綁定或記憶體隔離已生效。
目前設定檔沒有配置持久的工作 accounting，且即時佇列已查不到工作 2；
因此不把其退出狀態補寫為成功。

### 設定服務開機自啟並檢查目前狀態

批次工作腳本已補上中文註解；
設定的工作參數與執行邏輯未改。
已提交的工作 `2` 使用提交當時的腳本，不因這次加註解而改變。

MUNGE 先前已執行 `systemctl enable --now munge`，
本次只需在 VM 執行 `systemctl enable slurmctld slurmd`，
讓控制與運算服務隨下次開機啟動；不會重啟目前正在運作的服務。
這會建立 systemd 的開機啟用連結，不修改 repo、工作資料或雲端資源。
可用 `systemctl is-enabled munge slurmctld slurmd` 只讀驗證三個服務；
若要撤銷本次設定，可用 `systemctl disable slurmctld slurmd`，
不動原本已啟用的 MUNGE。

**實際結果：**`systemctl enable slurmctld slurmd`
成功建立兩個服務的開機啟用連結。
`systemctl is-enabled munge slurmctld slurmd` 依序回報：

```text
enabled
enabled
enabled
```

三個服務都已設定開機自啟；這只證明啟用狀態。
加註解的腳本已重新複製到 `/home/a2264/node-smoke.sbatch`；
`cmp` 結束碼為 0，表示家目錄副本與 repo 內容一致。

**目前服務狀態的只讀查詢結果：**

```text
$ systemctl is-active munge slurmctld slurmd
active
active
active
```

三行依指令順序分別對應 MUNGE、`slurmctld` 與 `slurmd`，
表示三個服務當下都在執行。
學員確認工作 2 提交後尚未重開機，並決定不做開機恢復驗證；
不將開機恢復列為本次實作的完成證據。

**目前節點狀態的只讀查詢結果：**

```text
$ sinfo -N
NODELIST                  NODES PARTITION STATE
instance-20260923-104239      1    debug* idle
```

這台 VM 仍在預設的 `debug` 分區中，`idle` 表示目前可供排程新工作。
它不提供工作 2 的退出狀態，也不代表跨節點能力已驗證。
