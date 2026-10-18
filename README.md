# HPC 叢集建置與維運作品

在 GCP 與 DevStack 環境建立四節點 Slurm 叢集：一台控制節點、
一台 NVIDIA L4 運算節點，以及兩台獨立 CPU 運算節點。
使用 Ansible 部署節點設定，接通 NFS 與 OpenStack 客體的網路路徑，
以 CPU／GPU 工作結果和 Zabbix 故障事件核對派工與復原。

## 我具備的能力

| 能力 | 我完成的實作 | 相關內容 |
|---|---|---|
| HPC 叢集架構與資源規劃 | 規劃控制、GPU 與兩台 CPU 節點的角色、分區及資源配置 | [拓撲](project/docs/cluster-topology.md)、[Slurm 設定](project/slurm/four-node-slurm.conf) |
| Slurm 與 Linux 服務管理 | 設定 MUNGE、`slurmctld`、`slurmd`，判讀節點狀態與工作結果，處理節點故障及恢復 | [服務與工作結果](curriculum/module-06.md) |
| 網路與共享資料路徑 | 接通 GCP 私有網路、NFS、OpenStack 客體的 SSH 管理與 Slurm 雙向通路，配置 SNAT／DNAT | [跨節點資料路徑](curriculum/module-04.md)、[客體網路](curriculum/module-05.md) |
| 叢集部署自動化 | 使用 Ansible 部署 NFS、MUNGE 及 Slurm 設定，將 OpenStack CPU 客體納入排程 | [Playbooks](project/ansible/)、[部署結果](curriculum/module-05.md) |
| Python、C/C++ 與平行程式 | 編寫提交前健檢工具、C/C++ 與 MPI 工作，並以 CPU／CUDA 熱擴散程式核對答案 | [Python](curriculum/module-02.md)、[C/C++ 與 MPI](curriculum/module-03.md)、[CPU](curriculum/module-06.md)／[L4](curriculum/module-05.md)工作 |
| GPU 資源管理 | 以 Slurm GRES 配置 NVIDIA L4，提交 GPU 熱擴散工作並取得 `validation=PASS` | [設定與工作結果](curriculum/module-05.md) |
| 監控與故障復原 | 使用 Zabbix 捕捉 `slurmd` 停止告警，核對節點隔離、工作轉移及恢復後的答案 | [告警與復原結果](curriculum/module-06.md) |
| OpenStack 客體納管 | 在 DevStack 供給 CPU VM、建立管理與 Slurm 網路通路，並完成指定客體的 Slurm 工作 | [供給與工作結果](curriculum/module-05.md) |

更多實作內容可以看[作品總覽](project/README.md)；
程式與設定放在 [project/](project/)。
