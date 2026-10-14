# 學習進度

課程已依學員要求重建，舊每日教學與操作紀錄已移除；以下重新從作品證據起算。沒有實際程式、部署或測試，就不寫成已完成。

| 模組 | 狀態與已交付成果 |
|---|---|
| [1 HPC 架構與單節點排程](curriculum/module-01.md) | 已完成：單節點正常與資源不符工作、控制服務復原、拓撲及資源取捨 |
| [2 Linux 問題判斷與 Python 健檢工具](curriculum/module-02.md) | 已完成：健檢 CLI、使用說明、正常與兩種條件不符案例 |
| [3 C/C++ 系統程式與 MPI 工作](curriculum/module-03.md) | 已完成：C++ 工具、C 序列版、本機 MPI 分工及單節點 Slurm 兩 rank 工作；工作 9 的答案 `55`、退出碼 `0:0` |
| [4 多節點網路與共享資料路徑](curriculum/module-04.md) | 已完成：兩台 VM 私有 IP 可互通，控制節點能 SSH 遠端執行；GPU VM 透過 NAT 連 GitHub 回報 HTTP `200`，並辨認出一張 NVIDIA L4；NFS 已驗證雙向讀寫；兩台 VM 各執行一個 MPI rank，主機名不同，部分總和 `15+40=55` |
| [5 HPC 叢集建置與管理自動化](curriculum/module-05.md) | 已完成本次 CPU 節點納管：原有控制節點與 GPU 節點的 NFS、MUNGE、Slurm 部署及 L4 工作已有實測。舊 Ubuntu `compute-cpu01` 已刪除，Ubuntu Glance 映像保留。AlmaLinux 10.2 `compute-cpu01` 已建立，1 vCPU、2 GiB RAM、20 GiB 磁碟，私有 IP `10.0.0.32`；MUNGE `0.5.15-11.el10_1`、Slurm 與 `slurm-slurmd` `26.05.4-1.el10` 以套件安裝，客體沒有編譯。控制節點已部署共用 MUNGE 金鑰與 Slurm 設定；CPU 節點已註冊於 `cpu` 分區，顯示 `IDLE`、1 CPU、1400 MiB 可排程記憶體，`srun hostname` 成功回報 `compute-cpu01.novalocal`。DevStack 浮動 IP `172.24.4.121` 用於控制節點到客體的 Slurm 入站轉送。GPU 節點目前關機，兩台獨立運算節點尚未同時在線；OpenStack 宿主機手動恢復的 `br-ex`、NAT、轉送及 swap 設定尚未持久化。 |
| [6 叢集維運、Zabbix 監控與故障復原](curriculum/module-06.md) | 未開始；CPU 節點已納管並通過基本 Slurm 工作啟動驗證。開始前須核對 GPU 與 CPU 兩台獨立運算節點的在線狀態；跨節點工作轉移須先有兩台都可接同類 CPU 工作的證據。 |
| [7 GKE 叢集自動化、維運與架構取捨](curriculum/module-07.md) | 未開始；預定用可重跑設定建立、變更與清除 GKE 叢集，驗證工作、故障恢復、共同告警入口及架構取捨 |
| [8 面試作品與職缺能力證據](curriculum/module-08.md) | 未開始；預定用新環境重建、工作與故障證據及技術追問驗收作品 |

模組 05 的 CPU 節點納管及基本排程驗證已完成。模組 06 開始前先核對兩台獨立運算節點的在線狀態；同類 CPU 工作在兩台節點間的轉移尚未驗證。
模組 04 的跨節點 MPI 由 `mpirun` 透過 SSH 啟動，只用 CPU；
這不代表已驗證跨節點 Slurm 排程或 GPU 計算。
