# 教學規模 Slurm 叢集拓撲

本圖整理[模組 05](../../curriculum/module-05.md)與
[模組 06](../../curriculum/module-06.md)保存的部署、節點及工作結果。
節點狀態是當時的實測，不代表閱讀文件時仍在線；目前狀態須另行核對。

```text
工作提交者
    │
    ▼
控制節點 instance-20260923-104239（10.140.0.2）
    ├─ slurmctld／slurmd、Ansible、MUNGE、NFS 伺服器
    ├── 私有網路與 NFS ── compute-gpu01（10.146.0.3，L4／slurmd）
    ├── 私有網路 ──────── compute-cpu02（10.146.0.5，slurmd／Zabbix）
    └── TCP 6818 ─────── openstack-lab01（10.146.0.4，DevStack／NAT）
                               └── 浮動 IP 172.24.4.121
                                    → compute-cpu01（10.0.0.32，slurmd）
```

`compute-cpu01` 回連控制節點的 TCP `6817` 經過 DevStack 路由器與
宿主機來源轉址；控制節點到該客體的 TCP `6818` 經宿主機與浮動 IP
目的轉址。SSH 管理客體則由宿主機的網路命名空間代理，
與 Slurm 服務連線使用不同路徑。

| 角色 | 已建立的資源 | 已驗證的工作與資料路徑 |
|---|---|---|
| 控制／提交／CPU／NFS | GCP `instance-20260923-104239`；`asia-east1-b`；2 vCPU、4 GiB；私有 IP `10.140.0.2` | `debug` 分區宣告 2 CPU、3000 MiB；執行 Ansible 並提供 `/srv/hpc-share` |
| GPU 運算 | GCP `compute-gpu01`；`asia-northeast1-c`；4 vCPU、16 GiB、一張 NVIDIA L4；私有 IP `10.146.0.3` | `gpu` 分區宣告 4 CPU、14000 MiB、一張 L4；透過 NFS 讀共享程式，Slurm GPU 熱擴散工作回報 `validation=PASS` |
| OpenStack 宿主機 | GCP `openstack-lab01`；Ubuntu 24.04、2 vCPU、8 GiB；私有 IP `10.146.0.4` | 承載 DevStack 與 CPU 客體；提供宿主機網路轉送，不是 Slurm 運算節點 |
| OpenStack CPU 運算 | `compute-cpu01`；AlmaLinux 10.2、1 vCPU、2 GiB、20 GiB 磁碟；私有 IP `10.0.0.32` | `cpu` 分區宣告 1 CPU、1400 MiB；已由 Ansible 納管並完成 Slurm CPU 工作；本客體沒有掛載 NFS |
| 監控兼 CPU 運算 | GCP `compute-cpu02`；AlmaLinux 10.2、2 vCPU、8 GiB、40 GiB 磁碟；私有 IP `10.146.0.5` | `cpu` 分區宣告 2 CPU、4000 MiB；執行 Zabbix 並完成 Slurm CPU 工作 |

控制節點、GPU VM 與兩台 CPU VM 的 `/etc/slurm/slurm.conf`
各是本機檔案，來源為[四節點設定](../slurm/four-node-slurm.conf)，
由[四節點 playbook](../ansible/slurm-four-node.yml)部署。
控制節點的 `/srv/hpc-share` 是 NFS 來源；GPU VM 的同名路徑是掛載點。
跨節點 MPI 已在控制節點與 GPU VM 各執行一個 CPU rank，
由 SSH 啟動，不是跨節點 Slurm 工作。

[模組 06](../../curriculum/module-06.md)記錄兩台 CPU VM 都完成同一份
熱擴散工作，以及 `compute-cpu02` 故障期間未指定節點的新工作落到
`compute-cpu01` 並回報 `validation=PASS`。Zabbix 記錄服務停止告警，
`ReturnToService=1` 部署後，`compute-cpu02` 曾回到 `idle`。

## 重建時的邊界

[inventory](../ansible/inventory/hosts.yml)、四節點設定及
[宿主機網路恢復腳本](../openstack/restore-module05-network.sh)
含這次環境的位址、SSH 路徑與網路命名空間資訊；
在新環境使用前須依新資源核對。現有叢集沒有高可用控制節點，
OpenStack 只供給一台 CPU 客體；單張 L4 的結果不代表多 GPU 或
企業實體網路的驗證。新環境重建尚未執行。
