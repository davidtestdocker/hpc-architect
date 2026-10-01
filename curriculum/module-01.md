# 模組 01：HPC 架構與單節點排程

[能力路線](ROADMAP.md)｜職缺核心：叢集架構規劃；支撐能力：系統架構與 Linux 服務管理。

## 這個模組在做什麼

先用一台 VM 建立最小的排程環境，讓一般帳號提交工作，
再用工作輸出確認它在哪裡執行，並練習判讀資源不足與控制服務故障。
這是後續擴充節點前的單節點基礎。

**Slurm 是工作排程系統。** 使用者告訴它要執行的程式和需要的 CPU、
記憶體等資源；Slurm 決定工作何時、在哪個節點執行。
它像維運環境中的工作佇列與派工系統，不是計算程式本身。
本模組讓同一台 VM 同時擔任派工端與執行端。

## 目前成果

| 項目 | 已驗證的結果 |
|---|---|
| 教學節點 | `instance-20260923-104239` 在當時兼任 Slurm 控制與運算節點 |
| 本機資源 | 2 個邏輯 CPU；Slurm 偵測 3906 MiB，設定供工作使用 3000 MiB |
| 驗證與排程 | MUNGE 驗證 `a2264` 成功；`debug` 分區的節點為 `idle` |
| 正常工作 | 批次工作 4 的 `sbatch_exit=0`，以 `a2264` 在本機執行 |
| 資源不符 | 工作 5 請求 3 CPU，因分區設定無法排入；已取消 |
| 故障復原 | 控制服務停止時 Slurm 查詢失敗；啟動後節點恢復 `idle`，一般帳號工作成功 |

這些成果完成本模組的**單節點**排程與故障判讀範圍。
實際拓撲與資源決策另見[架構成果](../project/docs/cluster-topology.md)。

## 先看懂叢集角色

HPC 是用合適的計算、記憶體和資料傳輸資源處理大量工作。
叢集由多台「節點」組成；節點可負責登入、控制、運算或儲存。
教學初期只有一台 VM，所以一台兼任控制與運算。

| 元件 | 在這台 VM 上做什麼 |
|---|---|
| `slurmctld` | 接收工作、管理佇列與節點狀態 |
| `slurmd` | 在運算節點啟動工作 |
| `debug` 分區 | 允許提交工作的節點集合；當時只有這台 VM |
| MUNGE | 讓 Slurm 服務與使用者請求確認身分；不負責排程 |
| `a2264` | 一般工作帳號，實際提交與執行工作 |

**工作**是程式和所需 CPU、記憶體等資源的一次執行要求；
**排程器**決定工作何時、在哪個節點執行。
提交被接受不代表執行成功，還要查工作退出碼、輸出與主機名。

### 這裡會用到的指令

下表是工具用途對照；實際執行與回傳結果記在後面的操作段落。

| 指令 | 用途 | 判讀限制 |
|---|---|---|
| `lscpu`、`slurmd -C` | 查 VM 可見 CPU 與 Slurm 偵測的資源 | VM 內拓撲不能代表實體主機 |
| `systemctl is-active`、`journalctl -u` | 查服務狀態與日誌 | 服務 `active` 不保證工作成功 |
| `sinfo -N`、`squeue` | 查節點／分區與工作佇列 | 佇列空了不表示工作正常退出 |
| `scontrol show job` | 查工作最終狀態與配置 | 需配合程式輸出核對答案 |
| `srun`、`sbatch` | 即時執行／提交批次工作 | 要核對執行節點與退出碼 |

### 資源規劃的邊界

VM 中的邏輯 CPU 是作業系統可排程的單位，不等於實體核心。
NUMA 是同一台機器內 CPU 與鄰近記憶體的分組，不是叢集中的另一台 VM。
本機只呈現一個 NUMA 節點，不能量測跨 NUMA 存取差異。
規劃 GPU 節點還要看 GPU 記憶體、CPU→GPU 傳輸、網卡與儲存路徑；
本模組已比較單卡 GPU 候選的用途與規格，取捨見
[架構成果](../project/docs/cluster-topology.md#單-gpu-候選比較)。

## 建置單節點環境

先用唯讀命令確認 VM 的作業系統：

```text
$ cat /etc/os-release
NAME="AlmaLinux"
VERSION="10.2 (Lavender Lion)"
VERSION_ID="10.2"
```

當時 VM 是 AlmaLinux 10.2。已安裝下列套件；安裝準備不是本模組的實作重點。

| 套件 | 版本 |
|---|---|
| `slurm`、`slurm-slurmctld`、`slurm-slurmd` | `26.05.4-1.el10.x86_64` |
| `munge`、`munge-libs`、`munge-devel` | `0.5.15-11.el10_1.x86_64` |

### 資源基線

先看 VM 可見的 CPU，再對照 Slurm 偵測值：

```text
$ lscpu
CPU(s):                  2
Thread(s) per core:      2
Core(s) per socket:      1
Socket(s):               1
Hypervisor vendor:       KVM
NUMA node(s):            1
NUMA node0 CPU(s):       0,1

$ slurmd -C
NodeName=instance-20260923-104239 CPUs=2 Boards=1 SocketsPerBoard=1 CoresPerSocket=1 ThreadsPerCore=2 RealMemory=3906
```

VM 呈現 2 個邏輯 CPU、一個 NUMA 節點。
Slurm 設定使用 2 CPU、3000 MiB，低於偵測到的 3906 MiB；
這是給工作的設定值，不是每個時刻可用的剩餘記憶體。

### 驗證身分與服務

`slurmctld` 使用專用的 `slurm` 系統帳號，不用一般工作帳號。
實際建立命令與驗證結果：

```bash
useradd -r -M -U -s /sbin/nologin slurm
```

```text
$ id slurm
uid=994(slurm) gid=994(slurm) groups=994(slurm)
$ getent passwd slurm
slurm:x:994:994::/home/slurm:/sbin/nologin
```

MUNGE 需由 `munge` 帳號保存共享金鑰；金鑰內容不進文件或版本庫。
當時將套件目錄調整為 `munge:munge`、權限 `700`，
以 `munge` 身分建立金鑰，再啟動服務：

```bash
chown munge:munge /etc/munge /var/lib/munge /var/log/munge
sudo -u munge /usr/sbin/mungekey --create --keyfile /etc/munge/munge.key
systemctl enable --now munge
```

三條設定命令都沒有錯誤輸出；隨後查詢得到：

```text
$ stat -c '%U:%G %a %n' /etc/munge /var/lib/munge /var/log/munge
munge:munge 700 /etc/munge
munge:munge 700 /var/lib/munge
munge:munge 700 /var/log/munge
$ stat -c '%U:%G %a %s %n' /etc/munge/munge.key
munge:munge 600 128 /etc/munge/munge.key
$ systemctl is-active munge
active
$ sudo -u a2264 munge -n | unmunge
STATUS:          Success (0)
UID:             a2264 (1000)
GID:             a2264 (1005)
```

目錄與金鑰權限符合預期，一般帳號的本機憑證驗證成功；
金鑰內容沒有被讀出或保存到文件。

### Slurm 設定與啟動

[single-node-slurm.conf](../project/slurm/single-node-slurm.conf)
定義同一台 VM 的控制與運算角色、MUNGE 驗證、
2 CPU／3000 MiB，以及預設的 `debug` 分區。
各設定項目的用途在設定檔中文註解中。

| 實際命令 | 建立或變更什麼 | 執行後的實際驗證 |
|---|---|---|
| `install -D -o root -g root -m 0644 /root/hpc-arch/project/slurm/single-node-slurm.conf /etc/slurm/slurm.conf` | 部署 Slurm 設定檔 | `stat`：`root:root 644`；`cmp`：`same` |
| `install -d -o slurm -g slurm -m 0700 /var/spool/slurmctld` | 控制端狀態目錄 | `stat`：`slurm:slurm 700` |
| `install -d -o root -g root -m 0755 /var/spool/slurmd` | 運算端暫存目錄 | `stat`：`root:root 755` |
| `systemctl start slurmctld`、`systemctl start slurmd` | 啟動控制與運算服務 | `systemctl is-active`：兩者皆為 `active` |
| `systemctl enable slurmctld slurmd` | 設定兩服務開機自啟 | `systemctl is-enabled munge slurmctld slurmd`：依序 `enabled`、`enabled`、`enabled` |

設定與目錄的命令本身沒有錯誤輸出；右欄是隨後的唯讀驗證。
三項服務 `munge`、`slurmctld`、`slurmd` 的實際狀態查詢均為 `active`。
節點查詢結果：

```text
$ sinfo -N
NODELIST                  NODES PARTITION STATE
instance-20260923-104239      1    debug* idle
```

`debug*` 是預設分區，`idle` 表示節點當時可接新工作。

## 工作驗證

### 一般帳號即時工作

```bash
sudo -iu a2264 srun -p debug -N1 -n1 /usr/bin/hostname
```

```text
instance-20260923-104239
```

`a2264` 經 Slurm 在這台節點執行了 `hostname`；這仍是單節點結果。

### 正常批次工作

[node-smoke.sbatch](../project/workloads/node-smoke.sbatch) 申請
1 個節點、1 個 task、1 CPU、256 MiB，最長 2 分鐘，
輸出工作 ID、使用者、節點和資源請求值。
一般帳號無法穿過 `/root`，因此先把腳本複製到其家目錄：

```bash
install -o a2264 -g a2264 -m 0644 /root/hpc-arch/project/workloads/node-smoke.sbatch /home/a2264/node-smoke.sbatch
```

命令沒有錯誤輸出；`stat` 顯示副本為
`a2264:a2264 644 /home/a2264/node-smoke.sbatch`，`cmp` 輸出 `same`。

工作 4 用以下命令提交並等待結束：

```bash
sudo -u a2264 -- bash -c 'cd /home/a2264 || exit 1; sbatch --wait /home/a2264/node-smoke.sbatch; result=$?; printf "sbatch_exit=%s\n" "$result"; exit "$result"'
```

```text
Submitted batch job 4
sbatch_exit=0
```

接著讀取這個工作留下的輸出檔：

```text
$ sudo -iu a2264 cat /home/a2264/slurm-4.out
job_id=4
user=a2264
node=instance-20260923-104239
requested_nodes=1
requested_cpus_per_task=1
requested_memory_mb=256
```

退出碼 `0` 與輸出一起證明批次腳本在本機正常完成，
不證明核心層的 CPU 綁定或記憶體隔離。

### 故意超過節點容量

這是有教學目的的條件不符案例：節點設定 2 CPU，工作請求 3 CPU。

```bash
sudo -iu a2264 sbatch --cpus-per-task=3 /home/a2264/node-smoke.sbatch
sudo -iu a2264 squeue -j 5
```

```text
$ sudo -iu a2264 sbatch --cpus-per-task=3 /home/a2264/node-smoke.sbatch
Submitted batch job 5
$ sudo -iu a2264 squeue -j 5
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
                 5     debug hpc-node    a2264 PD       0:00      1 (PartitionConfig)
```

`PD` 表示等待；在唯一節點只有 2 CPU 的設定下，
這份 3 CPU 請求無法排入。取消並核對佇列：

```text
$ sudo -iu a2264 scancel 5
$ sudo -iu a2264 squeue -u a2264
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
```

`scancel` 沒有錯誤輸出；佇列只剩表頭，工作 5 已取消。

## 控制服務故障與復原

在確認 `squeue` 沒有工作後，短暫停止本機控制服務，
用來辨認「控制端不可連」的症狀；復原方式是重新啟動服務。
這會暫停工作提交與狀態查詢，不修改設定檔或雲端資源。

```bash
systemctl stop slurmctld
systemctl is-active slurmctld
sinfo -N
```

```text
$ systemctl stop slurmctld
$ systemctl is-active slurmctld
inactive
$ sinfo -N
slurm_load_partitions: Unable to contact slurm controller (connect failure)
```

服務日誌也核對了停止原因：

```text
$ journalctl -u slurmctld -n 20 --no-pager
Sep 25 05:40:54 instance-20260923-104239 slurmctld[331435]: [2026-09-25T05:40:54.470] Terminate signal SIGTERM received
Sep 25 05:40:54 instance-20260923-104239 slurmctld[331435]: [2026-09-25T05:40:54.475] Saving all slurm state
Sep 25 05:40:54 instance-20260923-104239 systemd[1]: slurmctld.service: Deactivated successfully.
```

`SIGTERM`、保存狀態與正常停用，和這次有意停止相符。
隨後恢復並核對：

```bash
systemctl start slurmctld
systemctl is-active slurmctld
sinfo -N
sudo -iu a2264 srun -p debug -N1 -n1 /usr/bin/hostname
```

```text
$ systemctl start slurmctld
$ systemctl is-active slurmctld
active
$ sinfo -N
NODELIST                  NODES PARTITION STATE
instance-20260923-104239      1    debug* idle
$ sudo -iu a2264 srun -p debug -N1 -n1 /usr/bin/hostname
instance-20260923-104239
```

控制服務、節點狀態與一般帳號工作都恢復。
此故障案例只驗證同一台 VM 上的控制端復原，不代表多節點高可用。
