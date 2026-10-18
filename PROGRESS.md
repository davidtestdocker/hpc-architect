# 學習進度

課程已依學員要求重建，舊每日教學與操作紀錄已移除；以下重新從作品證據起算。沒有實際程式、部署或測試，就不寫成已完成。

| 模組 | 狀態與已交付成果 |
|---|---|
| [1 HPC 架構與單節點排程](curriculum/module-01.md) | 已完成：單節點正常與資源不符工作、控制服務復原、拓撲及資源取捨 |
| [2 Linux 問題判斷與 Python 健檢工具](curriculum/module-02.md) | 已完成：健檢 CLI、使用說明、正常與兩種條件不符案例 |
| [3 C/C++ 系統程式與 MPI 工作](curriculum/module-03.md) | 已完成：C++ 工具、C 序列版、本機 MPI 分工及單節點 Slurm 兩 rank 工作；工作 9 的答案 `55`、退出碼 `0:0` |
| [4 多節點網路與共享資料路徑](curriculum/module-04.md) | 已完成：兩台 VM 私有 IP 可互通，控制節點能 SSH 遠端執行；GPU VM 透過 NAT 連 GitHub 回報 HTTP `200`，並辨認出一張 NVIDIA L4；NFS 已驗證雙向讀寫；兩台 VM 各執行一個 MPI rank，主機名不同，部分總和 `15+40=55` |
| [5 HPC 叢集建置與管理自動化](curriculum/module-05.md) | 已完成 CPU 節點納管及基本工作：AlmaLinux 10.2 `compute-cpu01` 為 1 vCPU、2 GiB RAM、20 GiB 磁碟，私有 IP `10.0.0.32`；MUNGE `0.5.15-11.el10_1`、Slurm 與 `slurm-slurmd` `26.05.4-1.el10` 以套件安裝。CPU 節點最近一次為 `idle`、1 CPU、1400 MiB，`srun hostname` 回報 `compute-cpu01.novalocal`。GPU VM 已開機，更新為三節點 Slurm 設定、核對一張 L4 對應 `/dev/nvidia0`，解除重開機造成的 `DOWN` 後最近一次為 `idle`、4 CPU、14000 MiB；本次未重跑 GPU 計算工作，先前 L4 熱擴散工作已有實測。兩台獨立運算節點曾同時顯示 `idle`。DevStack 浮動 IP `172.24.4.121` 用於 CPU 客體的 Slurm 入站轉送。宿主機 `br-ex`、NAT 與轉送須在重開機後恢復；CPU 客體本次開機曾因 `/boot`、`/boot/efi` 裝置等待逾時進入 emergency mode，持久修正與重啟驗證尚未完成。 |
| [6 叢集維運、Zabbix 監控與故障復原](curriculum/module-06.md) | 已完成本輪實作：基線已核對控制服務、兩台舊運算節點與空佇列。因控制節點空間和記憶體不足、OpenStack 宿主機已承載 DevStack 與 CPU 客體，新建東京 GCP `compute-cpu02`（2 vCPU、8 GiB、40 GiB），加入 Slurm `cpu` 分區；四節點均顯示 `idle`，指定新節點的 `srun hostname` 成功。新 VM 已安裝 Zabbix 7.0.31、MariaDB 10.11.18 與網頁介面套件；MariaDB 已啟動，`zabbix` 資料庫與本機帳號已建立並授權，初始資料匯入後有 203 個資料表、2 個初始帳號。已回報修改 Zabbix server 的資料庫密碼設定，Zabbix server 目前正在執行。`php-fpm` 與 `httpd` 已啟動，控制節點 SSH 轉接配合 VS Code 本機埠後，Windows 瀏覽器已完成網頁初始設定並成功登入；啟動本機 agent 後，儀表板顯示 1 台主機可用及 CPU 使用率資料。Zabbix 已記錄停止 `slurmd` 的高嚴重度問題，服務恢復後監控回到正常。Slurm 節點曾保留 `DOWN`，執行 `RESUME` 後回到 `idle`；故障後 `compute-cpu02` 與 `compute-cpu01` 已用相同的 1 CPU、512 MiB 請求完成同一份熱擴散工作，總和相同且都回報 `PASS`。停止 `compute-cpu02` 的 `slurmd` 並等待節點顯示 `down*` 後，未指定節點的新 CPU 工作落到 `compute-cpu01.novalocal`，熱擴散答案核對為 `PASS`。四節點設定已部署 `ReturnToService=1`；控制端讀到值 `1`，重新啟動 `slurmd` 後 `compute-cpu02` 顯示 `idle`，此輪未執行人工 `RESUME`。 |
| [7 面試作品與職缺能力證據](curriculum/module-07.md) | 已交付：網路、Ansible、CPU／GPU 工作及監控復原的證據索引，四節點拓撲、職缺能力對照、操作手冊及作品展示提綱 |

模組 05 的 CPU 基本排程與 GPU 節點重新加入已驗證。
模組 06 已新增第二台 CPU 運算節點，兩台都能完成同一份 CPU 工作；
故障期間新工作轉移到 `compute-cpu01` 已驗證；
`compute-cpu02` 已在 `ReturnToService=1` 部署後回到 `idle`。
模組 04 的跨節點 MPI 由 `mpirun` 透過 SSH 啟動，只用 CPU；
這不代表已驗證跨節點 Slurm 排程或 GPU 計算。
