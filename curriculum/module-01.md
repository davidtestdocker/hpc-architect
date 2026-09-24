# 模組 01：HPC 架構與單節點排程

[能力路線](ROADMAP.md)｜職缺核心：軟硬體集群架構規劃；支撐能力：計算機架構、Linux 服務管理。

## 先教會的概念

HPC 是高效能運算：當工作需要大量計算、記憶體或資料傳輸時，用適合的運算資源執行它。**叢集**是被組織起來共同提供運算能力的多台電腦；其中每一台叫**節點**，可以是實體伺服器，也可以是 VM。「控制」「運算」「儲存」是節點負責的角色，小型實驗可以讓一台機器兼任多個角色。

例：使用者提交一個計算工作；**控制節點**接收工作並決定分給哪台機器，**運算節點**實際執行程式，**儲存節點**提供程式讀取的資料與結果存放位置。**登入節點**則是使用者進入叢集提交工作的入口。之後要建立的 GPU 節點仍是運算節點，只是多了 GPU 可供工作使用。目前只有一台 VM，起步時會暫時兼任控制與運算角色；這是在學兩個角色如何配合，不等於已建成多節點叢集。

**工作**是使用者提交的一次執行要求，包含要跑的程式和需要多少 CPU、記憶體或 GPU。**排程器**把這個要求與各節點可用的資源配對，決定何時、在哪裡執行。Slurm 是本課程選用的排程器：slurmctld 維護工作與節點狀態，slurmd 在運算節點啟動工作；partition 是一組允許提交工作的節點。MUNGE 是讓這些服務確認彼此身分的常見驗證機制，類似叢集內服務之間的身分證明；它不是使用者登入的密碼。

規劃節點時還要看 CPU 實體核心與邏輯執行緒、記憶體容量和 NUMA 位置、磁碟吞吐／延遲、網卡頻寬／延遲。GPU 節點另外考慮顯示記憶體、CPU 與 GPU 間的 PCIe 傳輸、卡與網卡的拓撲及供電／散熱。這些先用規格和拓撲理解，模組 04 有 GPU VM 後再驗證可觀察部分；單卡 VM 不能驗證多 GPU 互連。

例：若只有 2 個可用 CPU，工作要求 4 個 CPU 卻停在等待，先比對工作請求、節點實際配置和分區限制；不能因為 squeue 顯示等待就直接認定服務壞了。

## 指令先講清楚，再操作

首次使用時解釋：lscpu／free／lsblk 各查 CPU、記憶體、磁碟；systemctl status 查服務狀態，journalctl -u 查該服務日誌；sinfo 看分區與節點，squeue 看工作佇列，scontrol show node 查節點詳細狀態；sbatch 提交批次腳本，srun 執行工作步驟。提交成功不等於工作成功，還要查退出狀態、輸出與實際主機名。命令的選項、套件和設定檔路徑依當時發行版及版本確認，不能現在假定皆已安裝。

## 實作主線與過關證據

先用現有 VM 的資源與限制決定單節點可承受的工作規模，寫出 head／CPU compute／GPU compute／storage 的目標拓撲、目前共用角色和不能推論的硬體能力。GPU 節點先比較一張卡的候選型號、記憶體與用途，不在此時建立。取得同意後，依版本文件安裝與設定單節點 Slurm；由一般工作帳號提交正常與故意不符合資源條件的工作，從排程狀態、服務日誌和輸出解釋結果。可恢復的服務故障只在確認沒有重要工作後演練，事先寫明復原方式。

成果是 project/docs/ 的拓撲與資源假設、project/workloads/ 的可重跑批次腳本，以及本文件的真實工作與診斷紀錄。過關時應能回答：工作在哪個節點跑、請求和實得資源如何核對、等待／失敗時先看哪一層；單節點成功不得寫成跨節點能力。

開始第一次帶練前，先在本文件追加本次確定的 VM 指令、每條用途及檔案／服務影響；取得結果後再追加實際輸出與解釋。現在沒有實作成果。

## 第一次帶練：確認單節點排程環境

本次要把目前 VM 視為暫時共用控制與運算角色的教學節點，先確認作業系統，再決定與其版本相容的 Slurm 安裝來源及後續操作。GPU 節點此時仍是規劃，並未建立。這一步不把已知的帳號、路徑與一般 Linux 指令重新當課程練習。

第一條確定要執行的 VM 指令是 `cat /etc/os-release`：讀取作業系統名稱與版本，用來選擇正確的套件與服務文件。它只讀系統資訊，不建立、修改或刪除檔案，也不改服務或雲端資源。後續精確指令須依這份實際輸出決定，不能先假定發行版。

### 已執行：確認作業系統

實際指令：`cat /etc/os-release`。

重點輸出：

```text
NAME="AlmaLinux"
VERSION="10.2 (Lavender Lion)"
ID="almalinux"
ID_LIKE="rhel centos fedora"
VERSION_ID="10.2"
PLATFORM_ID="platform:el10"
```

判讀：這台 VM 是 AlmaLinux 10.2，屬 RHEL 相容發行版系列；後續要用 EL10／AlmaLinux 10.2 對應的套件與服務文件。`ID_LIKE` 說明相容家族，不代表可直接套用其他版本的套件來源。本命令只讀檔案，未安裝或變更任何套件、服務或雲端資源；目前尚未判定 Slurm 是否已安裝。

### 下一步：確認是否已有 Slurm 套件

預定 VM 指令：`rpm -qa 'slurm*'`。RPM 是 AlmaLinux 的已安裝套件資料庫；`-qa` 查詢已安裝套件，`'slurm*'` 只挑名稱符合 Slurm 的項目。這一步用來決定後續是檢查現有安裝，還是先研究可用套件來源。沒有輸出只代表 RPM 資料庫找不到符合套件，尚不能推論可用倉庫沒有 Slurm。本指令只讀套件資料庫，不修改任何檔案、服務或雲端資源。

實際指令：`rpm -qa 'slurm*'`。實際結果：沒有輸出，正常返回 shell 提示字元。判讀：目前 RPM 資料庫中沒有名稱符合 `slurm*` 的已安裝套件；下一步應檢查已啟用的套件倉庫，不能據此斷定 Slurm 無法安裝。

### 下一步：確認套件倉庫

**套件倉庫**是供 DNF 查詢與安裝軟體的來源清單，和 RPM 的「本機已安裝套件資料庫」不同。例：剛才 RPM 查不到 Slurm，只說明機器沒裝；若某個已啟用倉庫提供 Slurm，DNF 才可能找到對應版本。本次預定指令 `dnf repolist --enabled` 用來列出已啟用的倉庫名稱，不安裝套件、不變更倉庫設定或服務。是否要新增倉庫或安裝軟體，須等看過實際結果後另行確認。

實際指令：`dnf repolist --enabled`。

重點輸出：

```text
appstream               AlmaLinux 10 - AppStream
baseos                  AlmaLinux 10 - BaseOS
crb                     AlmaLinux 10 - CRB
extras                  AlmaLinux 10 - Extras
google-cloud-sdk        Google Cloud SDK
google-compute-engine   Google Compute Engine
```

判讀：已啟用 AlmaLinux 基礎／應用／開發相依套件來源與 Google Cloud 相關來源；清單中沒有 EPEL。EPEL 是 Enterprise Linux 的額外社群套件倉庫，但尚未確認是否需要它。先查現有倉庫是否提供 Slurm，不因猜測而新增倉庫。

### 下一步：查現有倉庫能提供哪些 Slurm 套件

預定 VM 指令：`dnf repoquery --available 'slurm*'`。`repoquery` 查的是已啟用倉庫中的**可取得套件**，與 `rpm -qa` 的「已安裝」不同；`--available` 排除僅已安裝的項目。DNF 可能更新本機套件索引快取並連線讀取倉庫資料，但不安裝套件、不啟用新倉庫，也不改服務。如果沒有結果，只能說目前啟用的倉庫查不到符合套件，不代表所有來源都沒有。

### Slurm 安裝結果

已安裝：`slurm-26.05.4-1.el10.x86_64`、`slurm-slurmctld-26.05.4-1.el10.x86_64`、`slurm-slurmd-26.05.4-1.el10.x86_64`、`munge-0.5.15-11.el10_1.x86_64`、`munge-libs-0.5.15-11.el10_1.x86_64`、`munge-devel-0.5.15-11.el10_1.x86_64`。

## 下一步：確認 VM 的 CPU 配置

Slurm 要知道運算節點有多少可分配的 CPU。這裡的「邏輯 CPU」是作業系統看見、可排程的執行單位；在 VM 內看到的是雲端提供的虛擬 CPU 配置，不能直接當成實體伺服器的核心數。

本次指令：`lscpu`。它只讀取 VM 可見的 CPU 資訊；重點看 `CPU(s)`（邏輯 CPU 總數）、`Thread(s) per core`（每核心的執行緒數）、`Core(s) per socket`（每插槽的核心數）與 `Socket(s)`（插槽數）。這一步不建立或修改檔案，不更動 Slurm 服務或雲端資源。收到實際輸出後再決定節點的 CPU 設定。

實際執行 `lscpu`；重點輸出：

```text
CPU(s):                  2
Thread(s) per core:      2
Core(s) per socket:      1
Socket(s):               1
Hypervisor vendor:       KVM
NUMA node(s):            1
NUMA node0 CPU(s):       0,1
```

判讀：這台 VM 呈現 2 個邏輯 CPU、1 個虛擬核心／插槽和 1 個 NUMA 節點；`KVM` 表示它是虛擬機，不能由此推論實體主機的核心配置。後續先以 VM 實際可見資源設定教學節點，不把它寫成實體叢集容量。

**NUMA 節點是什麼：**NUMA 是多處理器電腦的一種 CPU／記憶體配置：CPU 存取自己附近的記憶體通常比存取其他 CPU 群附近的記憶體快。系統把一組 CPU 與其鄰近記憶體稱為一個 NUMA 節點。這裡的「節點」是**同一台機器內部**的硬體分組，不是叢集裡的一台 VM。這台 VM 只呈現 1 個 NUMA 節點，CPU 0、1 都在其中，因此不能拿它測試跨 NUMA 節點的記憶體存取差異；也不能推論底層實體主機的 NUMA 拓撲。

下一條指令是 `slurmd -C`：讓 Slurm 的運算節點程式列出它偵測到的硬體配置，尤其是 `CPUs`、插槽／核心／執行緒與 `RealMemory`（MiB）。`-C` 只列印硬體配置後結束，不啟動服務，也不修改設定檔；輸出將用來核對之後的 `slurm.conf` 節點設定。若執行失敗，也保留錯誤訊息供判斷。參考：[Slurm 官方 slurmd 文件](https://slurm.schedmd.com/slurmd.html)。

實際執行 `slurmd -C`；輸出：

```text
NodeName=instance-20260923-104239 CPUs=2 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=2 RealMemory=3906
UpTime=0-23:29:49
```

判讀：Slurm 偵測到的 CPU 拓撲與 `lscpu` 一致；`RealMemory=3906` 表示它偵測到約 3906 MiB 記憶體，不是保證所有記憶體都能分配給工作。`UpTime` 是當時 VM 的開機運作時間。這是硬體偵測結果，還不是可用的 Slurm 節點或已啟動的排程服務。
