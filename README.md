# HPC 叢集建置與維運作品

在 GCP 與 DevStack 環境建立四節點 Slurm 叢集：一台控制節點、
一台 NVIDIA L4 運算節點，以及兩台獨立 CPU 運算節點。
使用 Ansible 部署節點設定，接通 NFS 與 OpenStack 客體的網路路徑，
以 CPU／GPU 工作結果和 Zabbix 故障事件核對派工與復原。

## 先看成果

| 主題 | 證據入口 |
|---|---|
| 架構與資源 | [四節點拓撲](project/docs/cluster-topology.md)、[Slurm 設定](project/slurm/four-node-slurm.conf) |
| 自動化與網路 | [Ansible playbooks](project/ansible/)、[OpenStack 客體納管與網路](curriculum/module-05.md) |
| 可核對的計算工作 | [L4 工作結果](curriculum/module-05.md)、[兩台 CPU 節點的工作與轉移](curriculum/module-06.md) |
| 監控與復原 | [Zabbix 告警及 Slurm 故障處理](curriculum/module-06.md)、[操作手冊](project/docs/operations.md) |

[作品總覽](project/README.md)整理各項成果；
[職缺能力與證據索引](curriculum/module-07.md)可從主張追到設定、命令與實際輸出。
可重跑的程式與設定在 [project/](project/)，各模組保存實作結果與判讀。

這是教學規模虛擬叢集的實作作品；節點角色、部署範圍與工作結果
依上述證據描述。[學習路線](curriculum/ROADMAP.md)和[進度](PROGRESS.md)
記錄實作順序。
