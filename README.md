# HPC 叢集建置與維運作品

在 GCP 與 DevStack 環境建立四節點 Slurm 叢集：一台控制節點、
一台 NVIDIA L4 運算節點，以及兩台獨立 CPU 運算節點。
使用 Ansible 部署節點設定，接通 NFS 與 OpenStack 客體的網路路徑，
以 CPU／GPU 工作結果和 Zabbix 故障事件核對派工與復原。

## 我具備的能力

| 能力 | 在這份作品中的實作與證據 |
|---|---|
| HPC 叢集架構與資源規劃 | 規劃控制、GPU 與兩台 CPU 節點的角色、分區及資源配置；[拓撲](project/docs/cluster-topology.md)與[四節點 Slurm 設定](project/slurm/four-node-slurm.conf)可核對 |
| Slurm 與 Linux 服務管理 | 設定 MUNGE、`slurmctld`、`slurmd`，判讀節點狀態與工作結果，處理節點故障及恢復；[實測紀錄](curriculum/module-06.md)與[操作手冊](project/docs/operations.md)可查 |
| 網路與共享資料路徑 | 接通 GCP 私有網路、NFS、OpenStack 客體的 SSH 管理與 Slurm 雙向通路，配置 SNAT／DNAT；[跨節點資料路徑](curriculum/module-04.md)與[客體網路紀錄](curriculum/module-05.md)可查 |
| 叢集部署自動化 | 使用 [Ansible inventory 與 playbooks](project/ansible/)部署 NFS、MUNGE 及 Slurm 設定，將 OpenStack CPU 客體納入排程；[部署結果](curriculum/module-05.md)可查 |
| Python、C/C++ 與平行程式 | 編寫[提交前健檢工具](curriculum/module-02.md)、[C/C++ 與 MPI 工作](curriculum/module-03.md)，並以 CPU／CUDA 熱擴散程式核對答案；[CPU 工作](curriculum/module-06.md)與[L4 工作](curriculum/module-05.md)均有實測 |
| GPU 資源管理 | 以 Slurm GRES 配置 NVIDIA L4，提交 GPU 熱擴散工作並取得 `validation=PASS`；[設定與輸出](curriculum/module-05.md)可查 |
| 監控與故障復原 | 使用 Zabbix 捕捉 `slurmd` 停止告警，核對節點隔離、工作轉移及恢復後的答案；[故障與工作證據](curriculum/module-06.md)可查 |
| OpenStack 客體納管 | 在 DevStack 供給 CPU VM、建立管理與 Slurm 網路通路，並完成指定客體的 Slurm 工作；[供給與驗證紀錄](curriculum/module-05.md)可查 |

[作品總覽](project/README.md)整理各項成果；
[職缺能力與證據索引](curriculum/module-07.md)可從主張追到設定、命令與實際輸出。
可重跑的程式與設定在 [project/](project/)，各模組保存實作結果與判讀。

這是教學規模虛擬叢集的實作作品；節點角色、部署範圍與工作結果
依上述證據描述。[學習路線](curriculum/ROADMAP.md)和[進度](PROGRESS.md)
記錄實作順序。
