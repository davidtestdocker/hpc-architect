# GCP 實驗環境方案

目前只有你提供的概略規格，尚未連入或查驗雲端機器。也不假設此工作目錄就是那台 GCP VM。所有安裝指令需先確認 Linux 發行版與版本；課程不要求重灌既有環境。

## 分階段使用

| 時期 | 規劃 | 能驗證什麼 |
|---|---|---|
| 第 1–6 週 | 現有 2 vCPU／4 GB／100 GB VM | Linux、Shell、Git、Python 與單機健檢 |
| 第 7 週 | 需要跨機操作時加入第二台實驗 VM | SSH、名稱解析、連線診斷；未建立前只做單機部分 |
| 第 8 週起 | 規劃 head + compute01 + compute02 三台獨立 GCP VM | NFS、Ansible、多節點 Slurm 與 MPI |
| 第 16 週監控 | 按實際 RAM 使用量決定分時啟動 Zabbix，或另外配置監控 VM | 監控與告警；不可因記憶體不足影響量測卻未註記 |

教學叢集的起始估算：head 可沿用現有 2 vCPU／4 GB VM；每台 compute 暫估 2 vCPU／2–4 GB、20–30 GB 開機磁碟。這是小型功能實驗的規劃值，需依 OS、套件和工作負載驗證，不是生產建議或費用報價。資料集保持小型，不需 GPU 或 InfiniBand。

目前單機不適合再以巢狀虛擬化塞進完整三節點和监控系統。只用一台時可先做單節點 Slurm／MPI；容器或多個本機程序只能驗證部分功能，不能冒稱跨獨立 VM 驗收已通過。

## GCP 要記錄的條件

- OS、機型、vCPU、RAM、磁碟類型及容量、region／zone、套件版本。
- 實驗節點使用同一 VPC 的內部位址互通；GCP 防火牆與客體防火牆分開檢查。
- 寫出 SSH、NFS、Slurm、監控的實際來源與目的規則，不把叢集內部服務直接開到全網。
- MPI 可能涉及額外動態連接埠，依安裝版本和設定確認；不能只開 Slurm 控制連接埠就假設 MPI 一定可用。
- 使用一般帳號執行 MPI；安裝與系統設定才使用必要權限。
- 將控制器与 NFS 放同一台是教學取捨，屬單點故障。GCP VM 間的實際實體配置未知，不宣稱是專用 HPC 硬體測試。

## 資源與預算

本課程沒有建立任何付費資源。第 7 週前再確認你的每月可接受預算、現有機型與區域，估算啟動時數、磁碟、IP、網路與可能的其他服務費用後，才決定具體配置。停止 VM 不表示帳單歸零，保留資源仍可能計費；以當時官方價格與帳單為準。

官方參考：[VM 網路](https://docs.cloud.google.com/compute/docs/networking/network-overview)、[VM 停止／啟動](https://docs.cloud.google.com/compute/docs/instances/stop-start-instance)、[Compute 定價](https://cloud.google.com/products/compute/pricing)。
