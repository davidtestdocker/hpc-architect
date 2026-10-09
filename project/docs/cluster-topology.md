# 教學叢集拓撲與最終規格

這份文件記錄已部署的 VM 與約定的最終規模；實際指令和輸出見
[模組 04](../../curriculum/module-04.md)與[模組 05](../../curriculum/module-05.md)。
**最終維持一台 CPU VM 加一台 GPU VM。**
新 GPU 節點的替換步驟與回復方式見
[模組 05 的替換紀錄](../../curriculum/module-05.md#8-單-gpu-配額下替換乾淨節點)。

## 目前資源狀態

```text
a2264 提交工作
       │
       ▼
CPU VM：instance-20260923-104239（台灣）
  ├─ slurmctld：排程；slurmd：debug 分區的 CPU 工作
  ├─ Ansible：管理兩台 VM 的設定
  └─ NFS：分享 /srv/hpc-share
       │  私有網路、MUNGE 驗證、NFS
       ▼
GPU VM：compute-gpu01（東京，已停止）
  └─ 保留開機磁碟與設定；目前不能接工作
```

| 角色 | 已確認的 VM 與硬體 | 排程與資料路徑 |
|---|---|---|
| CPU 控制／提交／運算／NFS | `instance-20260923-104239`；`asia-east1-b`；`e2-custom-2-4096`，2 vCPU、4 GiB；10 GiB 開機磁碟、100 GiB 附加磁碟；私有 IP `10.140.0.2` | `debug` 分區宣告 2 CPU、3000 MiB；提供 `/srv/hpc-share`；執行 Ansible |
| GPU 運算（已停止） | `compute-gpu01`；`asia-northeast1-c`；`g2-standard-4`，4 vCPU、16 GiB、一張 NVIDIA L4；40 GiB `pd-balanced` 開機磁碟；私有 IP `10.146.0.3`，沒有 VM 外部 IP | 設定仍指向舊節點；停止期間不能接工作 |

兩台 VM 的 `/etc/slurm/slurm.conf` 各存在自己的本機磁碟；
內容由[同一份工作樹來源](../slurm/two-node-slurm.conf)部署。
控制節點的 `/srv/hpc-share` 是 NFS 分享來源，GPU VM 上的同名路徑是掛載點。
模組 05 曾透過 Slurm 在 `compute-gpu01` 的 L4 執行二維熱擴散工作，
CPU 與 GPU 結果比較為 `validation=PASS`。
模組 04 的跨 VM MPI 工作由 SSH 啟動，未驗證跨節點 Slurm 排程。

## 約定的最終規格與替換範圍

CPU VM 保持上述規格與角色，不在 GPU 節點替換時重建。
最終 GPU VM 規劃為 `compute-gpu02`：同在東京 `asia-northeast1-c`，
使用 `g2-standard-4`、4 vCPU、16 GiB、一張具 24 GiB 顯示記憶體的 L4、40 GiB `pd-balanced`
開機磁碟、AlmaLinux 10、既有 VPC／subnet，沒有 VM 外部 IP 或服務帳戶。
它的私有 IP 由建機結果決定，確認後才寫入 inventory、NFS 匯出與 Slurm 設定。
原映像 `almalinux-10-v20260811` 已標為 `DEPRECATED`，
候選映像 `almalinux-10-v20261005` 已確認為 `READY`、`X86_64`；
Slurm 套件已保存在[專案套件目錄](../packages/slurm/README.md)。

單 GPU 配額下，舊 GPU VM 已停止，保留其開機磁碟與設定；
建好新 VM 並通過工作驗證後，才決定移除舊 VM。
替換期間舊 VM 與新 VM 可能同時存在，但只有一台 GPU VM 運行。
舊 VM 停止後仍有磁碟費用，重新啟動或建立新 VM 也受即時 GPU 容量限制。
驗收的範圍是乾淨 GPU 節點加入**既有** CPU 控制節點，
不能寫成整個叢集從零重建。

這是教學規模叢集：控制、CPU 工作與 NFS 共用一台 VM，沒有高可用控制端；
一張 L4 不能證明多卡隔離、跨 GPU RDMA 或大型生產叢集經驗。
