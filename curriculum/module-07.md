# 模組 07：用 GKE 跑批次工作，驗證建置、故障與監控

[能力路線](ROADMAP.md)｜對應叢集建置與管理自動化、網路管理和 K8s 加分能力。

## 這個模組要做什麼

現有 Slurm 叢集已能在 CPU／GPU 節點執行工作，也驗證了 CPU 節點
故障時的新工作轉移。本模組要建立一個短期使用的 GKE 叢集，
把同一類可核對答案的 CPU 批次工作放到 Kubernetes 執行，
再驗證設定變更、故障處理及告警。

最後交付四類可展示的成果：

1. **叢集生命週期：** 保存設定，建立 GKE、重跑無非預期變更、
   做一次有目的的設定變更與恢復，最後清除本次建立的資源。
2. **實際工作：** 在 Kubernetes Job 跑熱擴散計算，核對輸入、
   資源請求、執行節點、退出狀態和答案。
3. **故障與共同監控：** 演練一次可復原的 Kubernetes 工作故障，
   讓 GKE 與既有 Slurm／Zabbix 的問題在同一個 Zabbix 入口可追查。
4. **架構決策：** 用實際結果說明 Slurm 與 GKE 各適合什麼工作，
   誰負責排程、資料、失敗重試與監控；不拿不同硬體的耗時硬比效能。

這對應目標職缺的叢集架構、網路與自動化核心工作；
K8s 是職缺列出的加分項。GKE 是實作平台，受管控制平面不能
寫成自行部署 Kubernetes 控制平面的經驗。

## 現在已有什麼

模組 05 的 Slurm 叢集已完成 L4 工作；OpenStack 供給的
`compute-cpu01` 已納入 Slurm。模組 06 的兩台 CPU 節點已用同一份
[熱擴散程式](../project/workloads/heat2d_cpu.cpp) 完成可核對工作；
`compute-cpu02` 故障期間，新工作落到 `compute-cpu01`。
Zabbix 已收集 `slurmd` 狀態並記錄故障告警。

**GKE 尚未建立。** 庫內目前也沒有 GKE、Terraform、容器映像或
Kustomize 的設定檔。以下全部是本模組計畫，不能寫成已執行結果。

## 會用哪些技術與工具

GKE Standard 由 Google 管理 Kubernetes 控制平面，我們設定
**節點集區**（同規格的運算 VM）。**Pod** 執行容器，**Job** 管理
有限次工作的完成與重試。**容器映像**則把程式及執行環境封裝，
供 GKE 節點取得並啟動。

| 工具／技術 | 在本模組負責什麼 |
|---|---|
| GKE Standard、Kubernetes | 提供叢集與節點集區，讓 Job 在 Pod 中執行批次工作 |
| Terraform、Google Cloud CLI | 前者保存並管理本次 GKE、節點集區、必要網路／權限與映像倉庫；後者核對專案、配額及實際資源 |
| Docker 或 Podman、Artifact Registry | 把現有 C++ 程式建成容器映像並保存版本；建置工具依實際環境選一個 |
| Kustomize、kubectl | 前者保存 Job 基礎設定與一次資源配置變體；後者預覽、套用及查 Job、Pod、日誌 |
| Cloud Logging／Monitoring、既有 Zabbix 7.0 | 前者協助定位 GKE 故障；後者作 Slurm 與 GKE 的共同問題入口 |
| Helm、Zabbix Kubernetes 模板 | 在連線與權限確認後部署 Zabbix 的 Kubernetes 監控元件，讓 GKE 狀態進入既有 Zabbix |

Terraform 管雲端資源，Kustomize 管叢集裡的工作設定，
兩者作用於不同層。
Kubernetes [支援以 Kustomize 組合並套用設定](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)；
Google Cloud [支援以 Terraform 管理 GKE](https://docs.cloud.google.com/kubernetes-engine/docs/terraform/)。
Zabbix 7.0 的 [Kubernetes 監控方案](https://www.zabbix.com/integrations/kubernetes)
需要在叢集部署監控元件；實作前先確認到既有 Zabbix server 的網路與權限。

## GKE 上跑的工作

沿用 `project/workloads/heat2d_cpu.cpp`，把它編譯進容器映像。
固定輸入是 **1024×1024 格、200 次更新**；程式自行核對總和
`65535.998004`，容許誤差 `0.1`，並以 `validation=PASS` 和退出狀態
表示是否成功。這是公開可重跑的熱擴散範例，不稱為目標公司的業務。

資料路徑是：原始碼 → 容器映像 → Artifact Registry → GKE Pod →
程式標準輸出與 Job 狀態。程式目前用記憶體內固定輸入，
**沒有外部資料集或持久輸出**；因此本輪只能驗證映像取得、
工作執行及日誌路徑，不能聲稱驗證共享儲存或外部資料寫入。
程式輸出的 `host` 在容器裡是 Pod 主機名；
實際 GKE 節點須從 Pod 排程資訊另行核對。
工作時間只用於理解本次資源需求，不用不同硬體的單次耗時
宣稱 GKE 比 Slurm 快或慢。

## 實作順序與每段要看到的結果

| 段落 | 要做的事 | 真正的驗收證據 |
|---|---|---|
| 1. 資源盤點 | 核對專案、權限、區域、配額、目前 VM、預算和 GKE 到 Zabbix 的路徑；列出本次會新增及清除的資源 | 可用配額、費用範圍與資源邊界已確認；建立資源前取得同意 |
| 2. 建叢集 | 以 Terraform 建 GKE Standard、節點集區與必要相依資源；再執行一次計畫檢查 | 設定與實際資源一致，重跑沒有非預期變更 |
| 3. 跑工作 | 建立映像並上傳 Artifact Registry；用 Kustomize 保存 Job 設定，再由 kubectl 執行 | Job 完成、Pod 所在節點、資源請求、日誌、退出狀態與 `validation=PASS` |
| 4. 可控變更 | 對叢集容量或工作資源做一次有目的的變更，核對後恢復原值 | 變更前後的計畫、實際資源與工作結果相符 |
| 5. 接監控並演練故障 | 讓 GKE 狀態進入既有 Zabbix，確認 Slurm 與 GKE 問題可同頁追查；再做一次可復原的 Job 故障 | 問題、定位、處理、重試或重建、恢復及最終答案能串起來；若只測 Job，不宣稱節點自動修復 |
| 6. 比較與清除 | 對照兩種平台的資源、網路／資料路徑、故障責任與成本，保存結論；清除本次 GKE 資源 | 有實測依據的架構決策與清除結果；既有 Slurm／Zabbix VM 保留 |

Zabbix 的 Kubernetes 模板能提供哪些 Job／Pod 指標與告警，
要按實際部署版本核對；若現成模板沒有本次故障所需訊號，
才補一個明確的監控項與觸發條件。故障方式與重試上限也在
確認版本、網路和監控訊號後寫成確定指令，不預寫假定可用的命令。
Zabbix 對 GKE 的問題與模組 06 的 Slurm 問題都要能在共同入口
看到來源、時間、受影響資源和處理結果。

## 文件與完成條件

本模組的實際設定、容器建置檔、工作定義、輸入與量測放在
`project/` 對應目錄；故障證據放在 `project/incidents/`，
架構決策放在 `project/docs/`。建立檔案時再連結實際路徑。
各段先記確定要執行的指令、來源與目標及服務影響；
執行後才記真實輸出與判讀，不預寫成功結果。

完成需有：**可重跑的叢集與可控變更、答案正確的 GKE 工作、
一次故障恢復、Slurm／GKE 共同告警入口、架構決策和資源清除**。
建置前先確認費用與復原方式；本模組不要求刪除既有 VM。
單次 Job 工作不能冒充大型生產叢集或多 GPU／RDMA 經驗。
