# GCP 實驗環境方案

已驗證控制節點 `instance-20260923-104239` 的客體位址為 `10.140.0.2`，
並建立東京 GPU VM `compute-gpu01`。使用者開機後，GPU VM 的客體輸出顯示
`eth0` 為 `10.146.0.3/32`、預設下一跳為 `10.146.0.1`。
這些本機結果尚未證明兩台 VM 互通；最新實作紀錄見[模組 04](curriculum/module-04.md)。
安裝前仍須確認目標 VM 的系統與套件版本，不要求重灌既有環境。

## 分階段使用

| 階段 | 規劃 | 能驗證什麼 |
|---|---|---|
| 模組 1–3 | 現有 VM | 工作負載健檢、單節點 Slurm、C/MPI 正確性 |
| 模組 4 | 控制節點加上已建立的 `compute-gpu01`，目前共兩台獨立 VM | 名稱、連線、共享資料、跨節點工作與 GPU 裝置，按實測逐項判定 |
| 模組 5 | 依模組 4 已驗證的兩台 VM 整理部署自動化 | 重建、重跑與工作驗證；不把規劃中的第三台寫成已建立 |
| 模組 6 | 按實際 RAM 使用量決定監控服務配置 | 監控與告警；不可因記憶體不足影響量測卻未註記 |

控制節點在先前紀錄中為 2 vCPU／4 GiB；GPU 節點建機規格為
`g2-standard-4`、一張 L4、40 GiB `pd-balanced` 開機磁碟。
這是小型功能實驗配置，不是生產建議或費用報價。

目前已建立兩台 VM，但跨節點工作尚未驗證。
容器或多個本機程序只能驗證部分功能，不能冒稱跨獨立 VM 驗收已通過。

## GCP 要記錄的條件

- OS、機型、vCPU、RAM、磁碟類型及容量、region／zone、套件版本。
- 實驗節點使用同一 VPC 的內部位址互通；GCP 防火牆與客體防火牆分開檢查。
- 寫出 SSH、NFS、Slurm、監控的實際來源與目的規則，不把叢集內部服務直接開到全網。
- MPI 可能涉及額外動態連接埠，依安裝版本和設定確認；不能只開 Slurm 控制連接埠就假設 MPI 一定可用。
- 使用一般帳號執行 MPI；安裝與系統設定才使用必要權限。
- 將控制器与 NFS 放同一台是教學取捨，屬單點故障。GCP VM 間的實際實體配置未知，不宣稱是專用 HPC 硬體測試。

## 資源與預算

已建立的 `compute-gpu01` 是付費資源，啟動時有 GPU VM 運算費；
停止後保留的磁碟仍可能計費，跨區流量也可能計費。
VM 的啟動與停止由使用者自行決定。任何新增資源前先確認預算，
估算 VM、磁碟與網路費用；以當時官方價格與帳單為準。

官方參考：[VM 網路](https://docs.cloud.google.com/compute/docs/networking/network-overview)、[VM 停止／啟動](https://docs.cloud.google.com/compute/docs/instances/stop-start-instance)、[Compute 定價](https://cloud.google.com/products/compute/pricing)。
