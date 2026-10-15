# 學習進度

課程已依學員要求重建，舊每日教學與操作紀錄已移除；以下重新從作品證據起算。沒有實際程式、部署或測試，就不寫成已完成。

| 模組 | 狀態與已交付成果 |
|---|---|
| [1 HPC 架構與單節點排程](curriculum/module-01.md) | 已完成：單節點正常與資源不符工作、控制服務復原、拓撲及資源取捨 |
| [2 Linux 問題判斷與 Python 健檢工具](curriculum/module-02.md) | 已完成：健檢 CLI、使用說明、正常與兩種條件不符案例 |
| [3 C/C++ 系統程式與 MPI 工作](curriculum/module-03.md) | 已完成：C++ 工具、C 序列版、本機 MPI 分工及單節點 Slurm 兩 rank 工作；工作 9 的答案 `55`、退出碼 `0:0` |
| [4 多節點網路與共享資料路徑](curriculum/module-04.md) | 已完成：兩台 VM 私有 IP 可互通，控制節點能 SSH 遠端執行；GPU VM 透過 NAT 連 GitHub 回報 HTTP `200`，並辨認出一張 NVIDIA L4；NFS 已驗證雙向讀寫；兩台 VM 各執行一個 MPI rank，主機名不同，部分總和 `15+40=55` |
| [5 HPC 叢集建置與管理自動化](curriculum/module-05.md) | 已完成 CPU 節點納管及基本工作：AlmaLinux 10.2 `compute-cpu01` 為 1 vCPU、2 GiB RAM、20 GiB 磁碟，私有 IP `10.0.0.32`；MUNGE `0.5.15-11.el10_1`、Slurm 與 `slurm-slurmd` `26.05.4-1.el10` 以套件安裝。CPU 節點最近一次為 `idle`、1 CPU、1400 MiB，`srun hostname` 回報 `compute-cpu01.novalocal`。GPU VM 已開機，更新為三節點 Slurm 設定、核對一張 L4 對應 `/dev/nvidia0`，解除重開機造成的 `DOWN` 後最近一次為 `idle`、4 CPU、14000 MiB；本次未重跑 GPU 計算工作，先前 L4 熱擴散工作已有實測。兩台獨立運算節點曾同時顯示 `idle`。DevStack 浮動 IP `172.24.4.121` 用於 CPU 客體的 Slurm 入站轉送。宿主機 `br-ex`、NAT 與轉送須在重開機後恢復；CPU 客體本次開機曾因 `/boot`、`/boot/efi` 裝置等待逾時進入 emergency mode，持久修正與重啟驗證尚未完成。 |
| [6 叢集維運、Zabbix 監控與故障復原](curriculum/module-06.md) | 進行中：基線已核對控制服務、兩台舊運算節點與空佇列。因控制節點空間和記憶體不足、OpenStack 宿主機已承載 DevStack 與 CPU 客體，新建東京 GCP `compute-cpu02`（2 vCPU、8 GiB、40 GiB），加入 Slurm `cpu` 分區；四節點均顯示 `idle`，指定新節點的 `srun hostname` 成功。新 VM 已安裝 Zabbix 7.0.31、MariaDB 10.11.18 與網頁介面套件；MariaDB 已啟動，`zabbix` 資料庫與本機帳號已建立並授權，初始資料匯入後有 203 個資料表、2 個初始帳號。已回報修改 Zabbix server 的資料庫密碼設定，Zabbix server 目前正在執行。`php-fpm` 與 `httpd` 已啟動，控制節點 SSH 轉接配合 VS Code 本機埠後，Windows 瀏覽器已完成網頁初始設定並成功登入；啟動本機 agent 後，儀表板顯示 1 台主機可用及 CPU 使用率資料。告警、故障恢復及兩台 CPU 節點的同類工作轉移尚未驗證。 |
| [7 GKE 叢集自動化、維運與架構取捨](curriculum/module-07.md) | 未開始；預定用可重跑設定建立、變更與清除 GKE 叢集，驗證工作、故障恢復、共同告警入口及架構取捨 |
| [8 面試作品與職缺能力證據](curriculum/module-08.md) | 未開始；預定用新環境重建、工作與故障證據及技術追問驗收作品 |

模組 05 的 CPU 基本排程與 GPU 節點重新加入已驗證。
模組 06 已新增第二台 CPU 運算節點並驗證指定派工；
同類 CPU 工作在兩台 CPU 節點間的轉移尚未驗證。
模組 04 的跨節點 MPI 由 `mpirun` 透過 SSH 啟動，只用 CPU；
這不代表已驗證跨節點 Slurm 排程或 GPU 計算。
