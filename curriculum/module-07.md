# 模組 07：面試作品與職缺能力證據

[能力路線](ROADMAP.md)｜目標：把核心工作與程式能力整理成可檢查的作品。

## 作品摘要

在 GCP 與 DevStack 環境建立四節點 Slurm 叢集：控制節點兼 CPU 工作，
另有一台 NVIDIA L4 節點及兩台獨立 CPU 運算節點。
作品包含 Ansible 設定、OpenStack 客體納管、NFS 資料路徑、
可核對答案的 CPU／GPU 工作，以及 Zabbix 告警後的工作轉移與復原。
以下連結可從原始設定追到實際命令、輸出與判讀。

## 證據與操作入口

各項成果與可重跑來源如下：

| 能力 | 現有證據與可重跑來源 |
|---|---|
| 網路與共享資料 | [模組 04](module-04.md)記錄私有網路、Cloud NAT、SSH、NFS 雙向讀寫及兩台 VM 各一個 rank 的 MPI 工作；[模組 05](module-05.md)記錄 OpenStack CPU 客體的雙向通路、SNAT／DNAT 與開機後網路恢復；恢復腳本在[工作樹](../project/openstack/restore-module05-network.sh) |
| 部署自動化 | [模組 05](module-05.md)與[模組 06](module-06.md)保存 Ansible 部署結果；[inventory](../project/ansible/inventory/hosts.yml)及[四節點 playbook](../project/ansible/slurm-four-node.yml)是現有設定來源 |
| 計算與排程 | [模組 05](module-05.md)有 L4 熱擴散工作的 `validation=PASS`；[模組 06](module-06.md)有兩台 CPU 節點各自完成同一份熱擴散工作，以及故障期間新工作落到 `compute-cpu01` 的 `validation=PASS`；程式在[工作負載目錄](../project/workloads/) |
| 監控與恢復 | [模組 06](module-06.md)記錄 Zabbix `slurmd` 告警、Slurm 隔離與恢復，以及 `ReturnToService=1` 部署後節點回到 `idle` |

**操作前置：** 現有 [inventory](../project/ansible/inventory/hosts.yml)、
[Slurm 設定](../project/slurm/four-node-slurm.conf)及
[宿主機網路恢復腳本](../project/openstack/restore-module05-network.sh)
含目前 VM 的位址、名稱、SSH 路徑或網路命名空間資訊；
使用前須確認它們對應本次環境，不能直接套到另一套 VM。
[Slurm RPM 與來源檔](../project/packages/slurm/README.md)已保存，
但套件相依、MUNGE、GPU 驅動和 Zabbix 的部署仍須依節點角色處理。

**拓撲：** [四節點拓撲](../project/docs/cluster-topology.md)
列出節點角色、位址、資料與工作路徑；節點即時狀態應由 Slurm 查詢。

**操作手冊：** [現有四節點叢集操作與復原](../project/docs/operations.md)
已整理各設定來源會寫到哪台 VM 的哪個服務檔案、變更前置條件、
開機後網路恢復入口及故障定位順序，並連回模組 04–06 的實測輸出。

**展示提綱：** [十分鐘作品展示](../project/docs/demo.md)
依拓撲、網路、自動化、工作、故障與限制安排證據順序。

## 職缺能力與可用的作品敘述

下列敘述只對應已保存的實測；面試時可沿證據連結說明設計、
執行位置、結果及限制。履歷若使用這些內容，仍須按自己的實際
任職經驗區分專案成果與工作經歷。

| 職缺能力 | 可依現有證據描述的成果 | 依據與範圍 |
|---|---|---|
| HPC 叢集架構規劃 | 設計控制節點兼 CPU 工作、獨立 GPU 與兩台獨立 CPU 運算節點的教學規模 Slurm 拓撲，列出分區、資源和控制端單點取捨 | [四節點拓撲](../project/docs/cluster-topology.md)與[設定](../project/slurm/four-node-slurm.conf) |
| 網路系統設定與管理 | 配置私有網路、Cloud NAT、OpenStack 客體的 SNAT／DNAT 及開機後網路恢復，核對 SSH、NFS 和 Slurm 所需通路 | [模組 04](module-04.md)、[模組 05](module-05.md)；範圍為本叢集的 GCP VM 與一台 OpenStack 客體 |
| 叢集建置與管理自動化 | 使用 Ansible 管理 NFS、MUNGE、Slurm 節點設定，將 OpenStack CPU 客體納入 Slurm，部署四節點設定 | [模組 05](module-05.md)、[模組 06](module-06.md)及[playbooks](../project/ansible/)；範圍為既有節點的服務與設定部署 |
| Linux 與程式開發 | 寫 Python 提交前健檢、C/MPI 分工程式，以及可核對答案的 CPU／L4 熱擴散工作 | [模組 02](module-02.md)至[模組 05](module-05.md)；跨節點 MPI 由 SSH 在兩台 VM 啟動 CPU 程序 |
| 叢集維運與 Zabbix | 用 Zabbix 告警定位 `slurmd` 停止，核對 Slurm 節點隔離、故障期間新工作轉移及服務恢復後的工作結果 | [模組 06](module-06.md)的告警、工作結果與復原證據 |
| OpenStack | 在 DevStack 供給一台 AlmaLinux CPU VM，接通管理與 Slurm 服務路徑，並以 CPU 工作驗證納管 | [模組 05](module-05.md)；範圍是一台 CPU 客體 |

## 檢查方式

面試官可依下列入口檢查成果；工作證據以各模組保存的結果為準。

| 材料 | 讀者要能做什麼 |
|---|---|
| README／操作手冊 | 找到安裝、執行、測試與復原步驟 |
| 工作輸出與原始資料 | 核對節點、結果、退出碼與量測數字 |
| 能力對照表 | 對照職缺要求與本專案的實際證據 |

檢查命令應對應實際程式和部署文件；
不以一條「總測試成功」取代排程、網路、GPU 與故障證據。

## 作品範圍

這是四節點教學叢集與一台 OpenStack CPU 客體的實作成果。
自動化涵蓋既有節點上的 NFS、MUNGE 與 Slurm 設定；
控制節點、GPU 驅動及 Zabbix 依各自的部署紀錄說明。
工作結果以主機名、資源配置、退出碼及答案核對，不以設定宣告代替實測。
