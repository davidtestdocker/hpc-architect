# 學習進度

課程已依學員要求重建，舊每日教學與操作紀錄已移除；以下重新從作品證據起算。沒有實際程式、部署或測試，就不寫成已完成。

| 模組 | 狀態與已交付成果 |
|---|---|
| [1 HPC 架構與單節點排程](curriculum/module-01.md) | 已完成：單節點正常與資源不符工作、控制服務復原、拓撲及資源取捨 |
| [2 Linux 問題判斷與 Python 健檢工具](curriculum/module-02.md) | 已完成：健檢 CLI、使用說明、正常與兩種條件不符案例 |
| [3 C/C++ 系統程式與 MPI 工作](curriculum/module-03.md) | 已完成：C++ 工具、C 序列版、本機 MPI 分工及單節點 Slurm 兩 rank 工作；工作 9 的答案 `55`、退出碼 `0:0` |
| [4 多節點網路與共享資料路徑](curriculum/module-04.md) | 已完成：兩台 VM 私有 IP 可互通，控制節點能 SSH 遠端執行；GPU VM 透過 NAT 連 GitHub 回報 HTTP `200`，並辨認出一張 NVIDIA L4；NFS 已驗證雙向讀寫；兩台 VM 各執行一個 MPI rank，主機名不同，部分總和 `15+40=55` |
| [5 HPC 叢集建置與管理自動化](curriculum/module-05.md) | 進行中：NFS 與 MUNGE 已由 Ansible 核對或部署，跨 VM 憑證解碼成功；`slurm-identity.yml` 已讓兩台 VM 的 `slurm` 帳號一致為 `800:800`，重跑均 `changed=0`；`slurm-two-node.yml` 已更新控制端設定、啟動 GPU VM 的 `slurmd`；控制端曾查到 `compute-gpu01` 位於 `gpu` 分區並宣告一張 L4；一般帳號的 `srun` 曾在該分區執行二維熱擴散工作，CPU 與 GPU 逐格比較 `validation=PASS`。已完成 GCP VM 供給與 OpenStack 元件的流程對照；OpenStack VM 供給與管理實作尚未開始，不能列為已具備的操作證據。`compute-gpu01` 已停止並保留開機磁碟，L4 配額使用量降為 0；原規劃的 `compute-gpu02` 不再建立，現時 GPU 工作不可用。`openstack-lab01` 已建立並運行，套件來源已驗證可用，DevStack 安裝程序退出碼 0；OpenStack API 與 VM 供給尚待驗證。尚無跨節點 Slurm 工作或乾淨節點部署證據。 |
| [6 叢集維運、Zabbix 監控與故障復原](curriculum/module-06.md) | 未開始 |
| [7 效能證據、K8s／GKE 與架構取捨](curriculum/module-07.md) | 未開始 |
| [8 面試作品與職缺能力證據](curriculum/module-08.md) | 未開始 |

依模組順序推進；目前進行模組 05 叢集建置與管理自動化。
模組 04 的跨節點 MPI 由 `mpirun` 透過 SSH 啟動，只用 CPU；
這不代表已驗證跨節點 Slurm 排程或 GPU 計算。
