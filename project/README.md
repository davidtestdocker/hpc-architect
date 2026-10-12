# 面試專案：可重建的迷你 HPC 叢集

狀態：原 CPU 控制／運算 VM 與 L4 GPU VM 已有跨 VM MPI、共享資料及
Slurm GPU 工作的先前結果；原 GPU VM 已停止並保留磁碟。
OpenStack 的 `compute-cpu01` 已供給且可從控制端 SSH 登入，
尚未成為 Slurm 運算節點。乾淨 GPU 節點首次部署及整合展示仍待交付。
依[能力路線](../curriculum/ROADMAP.md)逐步完成作品。

目標：由 GCP 控制節點以 Ansible 管理 Slurm 叢集，將 OpenStack CPU 客體
納入獨立運算節點，執行可核對的 CPU／GPU 工作，
配合 Python 健檢、共享儲存與 Zabbix，展示部署、排程、觀測、除錯和
復原能力。再以可重跑設定建立、變更及清除 GKE 叢集，在其上執行
可核對工作與故障演練，和 Slurm 比較工作、資源與恢復責任；
OpenStack 依已完成的單台 VM 供給證據如實對照。

```mermaid
flowchart LR
  U[使用者 SSH] --> C[CPU VM：Slurm 控制器／CPU 工作／Ansible／NFS]
  C <--> G[GPU VM：slurmd／NVIDIA L4]
  C -. 待驗證 Slurm 與資料通路 .-> O[OpenStack compute-cpu01：預定 CPU slurmd]
  H[openstack-lab01：DevStack 宿主機] --> O
  Z[Zabbix：規劃中] --> C
  Z --> G
  Z -. 規劃中 .-> O
  Z --> E[共同事件入口：規劃中]
  K[GKE 叢集：規劃中] --> E
```

圖中的原 GPU VM 目前已停止；OpenStack CPU 客體僅完成供給與管理 SSH，
虛線是待驗證的 Slurm／資料通路。Zabbix、GKE 與共同事件入口仍在規劃中。
Slurm 教學叢集的[目標拓撲](docs/cluster-topology.md)新增一台獨立 CPU 運算客體；
GPU VM 將在乾淨節點驗證後替換，測試期間舊 VM 先停止保留。
運算節點所需的[Slurm 套件與原始碼](packages/slurm/README.md)已保存在專案中，
尚未於新 VM 安裝。
CPU VM 兼任多項角色是降低實驗成本的取捨，沒有生產高可用性。
兩台 GCP VM 的實體主機配置不確定，OpenStack CPU 客體則運行在
`openstack-lab01` 上；效能報告只針對實測環境。

## 需求對照

| 職缺要求 | 作品證據 |
|---|---|
| HPC 軟硬體集群規劃 | 拓撲、資源估算、假設、限制與擴充設計 |
| 網路設定管理 | 位址與名稱表、連線規則、NFS、網路故障報告 |
| 叢集建置自動化 | inventory、playbook、OpenStack CPU 客體納管及乾淨 GPU 節點加入既有控制節點的部署證據 |
| Linux 與程式能力 | Python 健檢工具及測試、C/MPI 程式與正確性驗證 |
| 開源維運經驗 | Slurm 運算節點故障定位、Zabbix 告警與恢復事件、工作復測紀錄 |
| K8s／GKE | 叢集建立、重跑、可控變更、工作與故障結果、監控及清除證據 |
| OpenStack | DevStack 的映像、網路及 CPU VM 供給，控制節點 SSH 登入的實際證據；另與現有 VM 供給流程對照 |

## 必做驗收

- [ ] 控制 VM、獨立 CPU 客體及 GPU VM 的版本、資源、位址與角色有文件，敏感資訊不公開。
- [ ] `compute-cpu01` 的雙向通路、身分與共享資料經驗證；Ansible 納管後，Slurm CPU 工作在此客體完成且答案可核對。
- [ ] 從符合文件前置條件的乾淨 GPU VM，以 Ansible 加入既有控制節點；人工步驟與依賴如實列出。
- [ ] 獨立 CPU 客體與 GPU VM 都能接收各自適合的 Slurm 工作；以輸出中的主機名證明執行位置。
- [ ] C/MPI 程式正確處理不可整除工作量，結果與序列版本一致。
- [ ] MPI 工作跨 CPU VM 與 GPU VM 執行，保存 rank／主機名與工作輸出。
- [ ] Python 工具有 help、結構化輸出、逾時及部分失敗處理，保留測試結果。
- [ ] 只做能支持架構決策的量測；保留原始數據、輸入、資源配置、版本與波動，不要求一定加速。
- [ ] Zabbix 持續更新運算節點或 Slurm 服務狀態；同一次故障有 Problem 與 OK 事件，並有 Slurm 定位、修復及已知答案工作的復測結果。跨節點轉移另需兩台獨立運算節點可接同類 CPU 工作的證據。
- [ ] 事先確認預算與配額；由保存的設定建立 GKE 叢集與節點集區，重跑無非預期變更，完成可控變更及恢復。
- [ ] GKE 工作有可核對結果、狀態與日誌；一次故障有監控、處理、重試與最終結果，清除本次資源有證據。
- [ ] Slurm 與 GKE 的實際告警進入共同事件入口，能對照時間、影響、處理與工作驗收。
- [ ] 以已完成的 DevStack CPU VM 供給與 SSH 登入證據，對照現有 GCP VM 供給流程。
- [ ] 一份完整的跨節點故障紀錄，串起監控、告警、原因、修復、恢復事件與工作結果。
- [ ] 在新環境按文件重建並核對工作；README、部署手冊、操作／復原手冊、技術追問與十分鐘展示完整，沒有將規劃寫成完成。

目前 GPU 配額僅允許一張卡；替換節點時先停止舊 GPU VM，並保留回復方式。
OpenStack 已有單台 VM 供給證據，沒有 OpenStack 叢集建置證據。
RDMA、Lustre、Slurm accounting 資料庫需有需求與相應環境才展開；
Zabbix 和 GKE 仍屬後續模組目標。

## 建議實作目錄

```text
project/
  README.md
  ansible/              # inventory 範例、playbooks、roles
  healthcheck/          # Python 原始碼、測試、使用說明
  workloads/            # C/MPI、編譯方法、sbatch 腳本
  gke/                  # 叢集生命週期與 Kubernetes 工作設定，排除憑證
  monitoring/           # 模板與告警定義，排除憑證
  benchmarks/           # 原始 CSV、分析程式、圖表
  docs/                 # 架構、部署、操作手冊、版本紀錄
  incidents/            # 真實演練報告
  demo/                 # 展示腳本、截圖或影片索引
```

這些是預期交付位置，待實作才建立內容。不要在尚未測量前填入重建耗時、效能提升或恢復時間。

## 十分鐘展示順序

1. 交代職缺需求、Slurm 與 GKE 的角色、現有規模及限制。
2. 展示 Ansible 與 GKE 的設定來源、真實建立、重跑及可控變更證據。
3. 核對跨節點工作、單 GPU 工作與 GKE 工作的輸入、節點及答案。
4. 用真實事件說明告警、故障定位、恢復與工作驗收。
5. 用必要量測說明架構取捨，指出企業實體叢集仍需驗證的部分。

履歷完成後應依實際證據描述各 VM 的角色、工作與驗證範圍；
在 `compute-cpu01` 尚未完成 Slurm 工作前，不能把其 SSH 管理通路
說成已具備獨立 CPU 運算能力，
也不能把乾淨 GPU 節點驗證寫成整個叢集從零重建。
