# 模組 05：HPC 叢集建置與管理自動化

[能力路線](ROADMAP.md)｜職缺核心：叢集建置與管理自動化。

## 要解決的問題與交付物

模組 04 已讓控制節點透過 SSH 在 GPU VM 執行 MPI 工作，
兩台 VM 也能讀寫 NFS 共享目錄。這證明計算與資料通路可用，
但當時 GPU VM 並未接受 Slurm 排程。
本模組把節點設定寫成可重跑的 Ansible playbook，
讓控制端能管理 GPU VM 的身分驗證、Slurm 設定和運算服務。

目前已完成既有兩台 VM 的 NFS、MUNGE、Slurm 服務帳號及兩節點設定部署。
控制端已看到 GPU 節點；一般帳號透過 Slurm 請求一張 GPU，
並在該分區執行二維熱擴散工作，使用 L4 算出與 CPU 一致的結果。
現有結果仍未驗證乾淨節點重建。

## 管理位置與本次部署範圍

所有 Ansible 指令都在**控制節點**的
`/root/hpc-arch/project/ansible` 目錄以 root 執行。
[ansible.cfg](../project/ansible/ansible.cfg) 指向
[hosts.yml](../project/ansible/inventory/hosts.yml)，
其中 `controller` 是控制節點本機，`gpu_compute` 是透過既有 SSH 金鑰
連到私有 IP `10.146.0.3` 的 `compute-gpu01`。
Inventory 只列出已存在的 VM，不會建立雲端資源。

下方先交代已建立的管理通路、NFS 和 MUNGE 前提及其自動化證據。
**本次兩節點 Slurm 部署的步驟從「1. 核對資源與帳號」開始：**
先核對 GPU VM 與兩台 VM 的帳號空間，
再執行 `slurm-identity.yml`，最後才執行 `slurm-two-node.yml`。
每個步驟都把指令、執行的檔案、檔案內的任務和實際結果放在一起。

工作樹中的 `project/` 檔案是**部署來源**；
`/etc/` 下的檔案才是各 VM 服務實際讀取的檔案。
相同路徑出現在兩台 VM 時，各自是本機磁碟上的一份，並非同一個檔案。
下方每個步驟分別說明來源、目標及服務何時讀取。

## 已建立的 Ansible 管理通路

Ansible 沿用模組 04 已驗證的 SSH 管理通路。
**Inventory** 列目標主機；**playbook** 描述檔案、掛載和服務應有的狀態；
**handler** 在任務真的變更時才由 `notify` 觸發。
正式執行的 `changed` 表示已改動受管狀態；`changed=0` 表示重跑沒有額外變更。
`--syntax-check` 只解析 playbook，`--check --diff` 只預演，
都不能當成檔案已複製或服務已啟動。

在控制節點執行下列指令。它先讀取目前目錄的
[ansible.cfg](../project/ansible/ansible.cfg)，再依設定讀取
[hosts.yml](../project/ansible/inventory/hosts.yml) 並列出群組與主機；
這裡沒有執行 playbook，也不連線或修改 GPU VM：

```bash
ansible-inventory --graph
```

```text
@all:
  |--@ungrouped:
  |--@controller:
  |  |--instance-20260923-104239
  |--@gpu_compute:
  |  |--compute-gpu01
```

兩個群組各有預期的 VM。下一條指令仍用 `hosts.yml` 選
`gpu_compute`，再透過 SSH 在 GPU VM 執行 Ansible 的 `ping` 模組。
這裡也沒有執行 playbook；這個 `ping` 不是 ICMP，
回傳 `pong` 才代表遠端模組可執行：

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml gpu_compute -m ansible.builtin.ping
```

```text
compute-gpu01 | SUCCESS => {
    "ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3"},
    "changed": false,
    "ping": "pong"
}
```

## 已完成的 NFS 自動化

模組 04 已手動驗證兩台 VM 對 `/srv/hpc-share` 的雙向讀寫。
第一條指令執行
[nfs-controller.yml](../project/ansible/nfs-controller.yml)。
該檔在**控制節點**依序確認 `nfs-utils`、核對 `/srv/hpc-share`
的擁有者和權限、把工作樹中的
[hpc-share.exports](../project/nfs/hpc-share.exports) 複製到
控制節點自己的 `/etc/exports.d/hpc-share.exports`，
最後確認 `nfs-server` 正在運行。
匯出檔真的改動時，handler 才執行 `exportfs -ra` 重新讀取分享清單。

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-controller.yml
```

```text
PLAY RECAP
instance-20260923-104239 : ok=5 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

[nfs-gpu-client.yml](../project/ansible/nfs-gpu-client.yml)
由下一條指令執行。它在 **GPU VM** 先確認 `nfs-utils`，
再把控制節點 `10.140.0.2:/srv/hpc-share` 接到**GPU VM 自己的**
`/srv/hpc-share`，同時核對 GPU VM 的 `/etc/fstab` 項目與掛載狀態。
`ansible.posix.mount` 來自
[requirements.yml](../project/ansible/requirements.yml) 固定的
`ansible.posix:2.2.2`；實際已安裝該版本。
掛載選項為 `rw,vers=4.2,_netdev,nofail,x-systemd.automount`，
用途與副作用寫在 playbook 中文註解中。
正式執行與重跑都沒有改動既有掛載：

```bash
ansible-playbook nfs-gpu-client.yml
```

```text
PLAY RECAP
compute-gpu01 : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

同一指令重跑的結果也為 `ok=3 changed=0 failed=0`。
這證明既有兩台 VM 的 NFS 狀態符合 playbook，
並沒有提供乾淨節點首次建立掛載的證據。

## 已完成的 MUNGE 跨節點身分驗證

模組 04 的 MPI 工作由 SSH 啟動，不需要 GPU VM 的 Slurm 服務。
要由 Slurm 控制端分配工作，GPU VM 的 `slurmd` 必須能用 MUNGE
驗證同一叢集的請求。兩台 VM 使用控制節點既有的 MUNGE 金鑰；
金鑰內容只留在 VM 的 `/etc/munge/munge.key`，不存入專案或輸出。

GPU VM 已安裝與控制節點同版的運算端套件：

| 套件 | 已安裝版本 | 用途 |
|---|---|---|
| `munge`、`munge-libs` | `0.5.15-11.el10_1.x86_64` | 產生與驗證憑證 |
| `slurm`、`slurm-slurmd` | `26.05.4-1.el10.x86_64` | 運算節點的 Slurm 元件與服務 |

同一筆安裝交易另帶入 `bash-completion`、`mariadb-connector-c`、
`mariadb-connector-c-config`；套件準備不是本模組的操作重點。

下列指令執行 [munge-gpu.yml](../project/ansible/munge-gpu.yml)。
該檔在 **GPU VM** 依序核對 MUNGE 目錄權限、
從**控制節點的** `/etc/munge/munge.key` 複製金鑰到
**GPU VM 自己的**同名路徑、設為 `munge:munge` 與 `0600`，
最後啟用 GPU VM 的 `munge` 服務。
金鑰真的改動時，handler 才重啟 GPU VM 的 MUNGE；
Ansible 不顯示金鑰內容或差異。

```bash
ansible-playbook munge-gpu.yml
```

```text
TASK [部署叢集共用的 MUNGE 金鑰]           changed: [compute-gpu01]
TASK [確保 GPU VM 的 MUNGE 已啟動]         changed: [compute-gpu01]
RUNNING HANDLER [重新啟動 GPU VM 的 MUNGE] changed: [compute-gpu01]
PLAY RECAP
compute-gpu01 : ok=5 changed=3 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

在控制節點以 `a2264` 產生短效憑證，經既有 SSH 金鑰交給 GPU VM 的
`unmunge` 解碼；左側 `munge -n` 不把金鑰輸出，管線只傳短效憑證。
`-i` 選 SSH 私鑰，`IdentitiesOnly=yes` 限定使用該金鑰，
`BatchMode=yes` 不互動詢問，`ConnectTimeout=5` 限制連線等待。
這只檢查驗證通路，不提交 Slurm 工作或改動服務：

```bash
sudo -u a2264 -- munge -n | sudo -u a2264 -- ssh -i /home/a2264/.ssh/hpc_gpu_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 a2264@10.146.0.3 unmunge
```

```text
STATUS:          Success (0)
ENCODE_HOST:     instance-20260923-104239.asia-east1-b.c.project-78b8a95c-a2c0-461f-a08.internal (10.140.0.2)
UID:             a2264 (1000)
GID:             a2264 (1005)
```

GPU VM 成功解碼控制節點的憑證，證明跨 VM 的 MUNGE 驗證通路可用。
重跑 `ansible-playbook munge-gpu.yml` 得到 `ok=4 changed=0 failed=0`，
沒有重新複製金鑰或重啟服務。

## 1. 核對 GPU VM 資源與帳號空間

Slurm 按節點宣告的 CPU、記憶體和 **GRES**（通用資源）分配工作；
GPU 是本叢集的 GRES。先在 GPU VM 以 `a2264` 執行 `slurmd -C`，
直接讀取本機硬體並列出建議節點設定；
這條指令不執行 playbook，也不啟動服務：

```bash
slurmd -C
```

```text
NodeName=compute-gpu01 CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=2 ThreadsPerCore=2 RealMemory=15983 Gres=gpu:nvidia_l4:1
Found gpu:nvidia_l4:1 with Autodetect=nvidia (Substring of gpu name may be used instead)
```

GPU VM 有 4 個邏輯 CPU、15,983 MiB 記憶體和一張 NVIDIA L4。
兩節點設定只宣告 14,000 MiB 給工作，保留其餘容量給系統與服務。
`slurmd -C` 是硬體探測，不能當成 GPU 已交由 Slurm 分配。

### 為何要統一帳號編號

Linux 帳號除了名稱，還有數字身分：**UID** 是使用者編號，
**GID** 是群組編號；檔案擁有權和服務身分會用到它們。
`800:800` 表示 UID 800 的使用者，其主要群組是 GID 800。
兩台 VM 即使都有叫 `slurm` 的帳號，也要核對數字身分。

控制節點的 `slurm` 在[模組 01 的單節點建置](module-01.md#驗證身分與服務)
由 `useradd -r -M -U -s /sbin/nologin slurm` 建立；
當時 `id slurm` 回報 `uid=994(slurm) gid=994(slurm)`。
GPU VM 的 `994:994` 已屬於 `munge`，不能照搬控制節點的數字。
改號前要找出兩台 VM 都沒有占用的
使用者編號和群組編號。在控制節點的 Ansible 目錄以 root 執行
兩條只讀查詢，**不執行 playbook 檔案**：第一條查兩台 VM 的 UID 800，
第二條查 GID 800。
`ansible all` 選兩台 VM；`getent` 讀帳號資料庫；
`fail_key=false` 讓查無資料回傳空值。查詢不建立帳號或群組。

```bash
ansible all -m ansible.builtin.getent -a 'database=passwd key=800 fail_key=false'
ansible all -m ansible.builtin.getent -a 'database=group key=800 fail_key=false'
```

`getent_passwd["800"]`、`getent_group["800"]` 是輸出中的
使用者與群組查詢欄位，**不是指令**。實際結果如下；
`null` 表示該 VM 找不到這個編號：

| 查詢 | 控制節點 | GPU VM |
|---|---|---|
| `getent_passwd["800"]` | `null` | `null` |
| `getent_group["800"]` | `null` | `null` |

兩台 VM 的 UID 與 GID 800 都未占用，因此選 `800:800`。

控制節點的 `/var/spool/slurmctld` 保存排程狀態，
原本由 UID/GID `994:994` 的 `slurm` 帳號持有。
只改帳號編號，舊狀態檔不會自動變成新帳號的檔案；
因此下方 playbook 也把這個目錄及其內容交給新的 `800:800` 帳號。

## 2. 執行 slurm-identity.yml：統一服務帳號

在控制節點的 Ansible 目錄以 root **正式執行**：

```bash
ansible-playbook slurm-identity.yml
```

這條指令執行的是
[slurm-identity.yml](../project/ansible/slurm-identity.yml)。
檔案中的任務依序處理：

1. 在 **GPU VM** 建立不能互動登入、沒有家目錄的 `slurm` 群組與使用者，
   UID/GID 固定為 `800:800`，再用 `id slurm` 核對。
2. 在**控制節點**確認原帳號是 `994:994` 或已改為 `800:800`；
   第一次改號時先確認沒有工作，再停止 `slurmctld`。
3. 將控制節點的 `slurm` 群組和使用者改為 `800:800`，
   並把 `/var/spool/slurmctld` 及其中排程狀態交給新帳號。
4. 啟動控制節點的 `slurmctld`，用 `id slurm` 與 `scontrol ping` 核對。
   重跑時若已是 `800:800`，跳過停機及改號。

若控制端遷移途中失敗，檔案中的救援任務會嘗試恢復原本的
`994:994` 與服務；若連線中斷，仍需依實際狀態人工核對。
這一步會變更兩台 VM 的系統帳號，並短暫中斷控制端排程服務；
不建立 VM、不安裝套件。

下列是這次指令的實際關鍵輸出：

```text
PLAY [建立 GPU VM 的 Slurm 服務帳號]
TASK [備妥 GPU VM 的 slurm 群組]           changed: [compute-gpu01]
TASK [備妥 GPU VM 的 slurm 使用者]         changed: [compute-gpu01]
"gpu_slurm_id.stdout": "uid=800(slurm) gid=800(slurm) groups=800(slurm)"
PLAY [將控制節點的 Slurm 服務帳號遷移到相同身分數字]
TASK [變更身分前確認 Slurm 沒有工作]       ok: [instance-20260923-104239]
TASK [暫停控制節點的 slurmctld]           changed: [instance-20260923-104239]
TASK [將控制節點的 slurm 群組改為 GID 800] changed: [instance-20260923-104239]
TASK [將控制節點的 slurm 使用者改為 UID 800] changed: [instance-20260923-104239]
TASK [讓遷移後的帳號持有控制節點排程狀態] changed: [instance-20260923-104239]
TASK [恢復控制節點的 slurmctld]           changed: [instance-20260923-104239]
"controller_slurm_id.stdout": "uid=800(slurm) gid=800(slurm) groups=800(slurm)"
"controller_slurm_ping.stdout": "Slurmctld(primary) at instance-20260923-104239 is UP"
PLAY RECAP
compute-gpu01            : ok=5 changed=2 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
instance-20260923-104239 : ok=14 changed=5 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

兩台 VM 都實際回報 `800:800`；控制服務在遷移後回應 `UP`。
在控制節點同一目錄以 root 重跑，核對帳號設定不再改動；
如果實際狀態已偏移，playbook 仍可能修正帳號或服務：

```bash
ansible-playbook slurm-identity.yml
```

```text
TASK [備妥 GPU VM 的 slurm 群組]   ok: [compute-gpu01]
TASK [備妥 GPU VM 的 slurm 使用者] ok: [compute-gpu01]
"gpu_slurm_id.stdout": "uid=800(slurm) gid=800(slurm) groups=800(slurm)"
TASK [確認控制節點的原身分或目標身分完整] ok: [instance-20260923-104239]
TASK [變更身分前確認 Slurm 沒有工作] skipping: [instance-20260923-104239]
TASK [暫停控制節點的 slurmctld] skipping: [instance-20260923-104239]
TASK [將控制節點的 slurm 群組改為 GID 800] skipping: [instance-20260923-104239]
TASK [將控制節點的 slurm 使用者改為 UID 800] skipping: [instance-20260923-104239]
TASK [讓遷移後的帳號持有控制節點排程狀態] skipping: [instance-20260923-104239]
TASK [恢復控制節點的 slurmctld] skipping: [instance-20260923-104239]
TASK [核對控制節點排程服務已回應] skipping: [instance-20260923-104239]
PLAY RECAP
compute-gpu01            : ok=5 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
instance-20260923-104239 : ok=4 changed=0 unreachable=0 failed=0 skipped=10 rescued=0 ignored=0
```

跳過的 10 個任務是首次遷移用的工作檢查、停機、改號與服務核對；
重跑沒有再次停止服務。重跑本身沒有重新 ping 控制服務，
`UP` 是首次正式執行的驗證結果。

## 3. 執行 slurm-two-node.yml：部署排程設定

修改控制端排程設定前，在控制節點以 root 查工作佇列；
`-h` 不顯示標題，`-o` 列出 ID、狀態、使用者和名稱。
這只讀取當下狀態，不提交或取消工作：

```bash
squeue -h -o '%i %T %u %j'
```

**結果：** 命令正常返回、沒有輸出；查詢當下沒有執行中或等待中的工作。

在控制節點的 Ansible 目錄以 root **正式執行**：

```bash
ansible-playbook slurm-two-node.yml
```

這條指令執行的是
[slurm-two-node.yml](../project/ansible/slurm-two-node.yml)。
檔案中的任務依序處理：

1. 在 **GPU VM** 建立或核對 `/etc/slurm` 和 `/var/spool/slurmd`。
   從**控制節點工作樹**的
   [two-node-slurm.conf](../project/slurm/two-node-slurm.conf)
   複製到 GPU VM 自己的 `/etc/slurm/slurm.conf`。
   這份設定保留控制節點的 `debug` 分區，新增只含 GPU VM 的 `gpu` 分區，
   向 Slurm 宣告 GPU VM 可排程 4 個邏輯 CPU、14,000 MiB 記憶體和一張 L4。
2. 從控制節點工作樹的
   [gpu-gres.conf](../project/slurm/gpu-gres.conf)
   複製到 GPU VM 自己的 `/etc/slurm/gres.conf`。
   它指定 `AutoDetect=nvidia`。
   **執行 `slurmd -G` 的目的是確認 Slurm 設定宣告的 GPU 型號，
   跟 GPU VM 實際偵測到的裝置對得上。**
   接著 playbook 在 GPU VM 執行 `slurmd -G`，讀取剛收到的兩份設定，
   列出這台 VM 的 GPU 資源與本機裝置路徑如何對應。
   Ansible 收集指令輸出，要求指令成功、結果包含 `nvidia_l4`
   且沒有 `error:`；基本檢查失敗就停止，不更新控制節點。
   緊接的「顯示 GPU VM 的 GRES 檢查結果」任務在控制節點終端顯示
   收集的結果，供核對 GPU 數量與裝置路徑；本次顯示
   `Count=1`、`File=/dev/nvidia0`。自動條件沒有逐項驗證這兩個欄位。
3. GPU 檢查通過後，才把控制節點工作樹中同一份
   `two-node-slurm.conf` 複製到**控制節點自己**的
   `/etc/slurm/slurm.conf`，取代模組 01 建立的單節點內容。
   檔案真的改動時，handler 執行 `scontrol reconfigure`，
   讓現有 `slurmctld` 重新讀取，不重啟控制服務。
4. 最後啟動 GPU VM 的 `slurmd` 並設為開機啟動；
   重跑且設定未變時不會無故重啟服務。

複製任務改動檔案時，會在各 VM 留下舊版備份。
下列是這次指令的實際關鍵輸出；
`顯示 GPU VM 的 GRES 檢查結果` 把前一任務收集的資料印回控制節點，
供核對 GPU 數量與裝置路徑：

```text
PLAY [備妥 GPU VM 的 Slurm 設定並檢查 GPU 對應]
TASK [部署 GPU VM 的共用 Slurm 設定] changed: [compute-gpu01]
TASK [部署 GPU VM 的 GPU 資源設定] changed: [compute-gpu01]
TASK [核對 GPU VM 的 GRES 設定] ok: [compute-gpu01]
TASK [顯示 GPU VM 的 GRES 檢查結果] ok: [compute-gpu01] => {
    "gpu_gres_probe": {
        "changed": false,
        "cmd": ["slurmd", "-G"],
        "rc": 0,
        "stderr_lines": [
            "[2026-10-09T06:49:39.018] _read_slurm_cgroup_conf: No cgroup.conf file (/etc/slurm/cgroup.conf), using defaults",
            "[2026-10-09T06:49:39.052] Gres Name=gpu Type=nvidia_l4 Count=1 Index=0 ID=7696487 File=/dev/nvidia0 Cores=0-1 CoreCnt=4 Links=(null) Flags=HAS_FILE,HAS_TYPE,ENV_NVML"
        ],
        "stdout": ""
    }
}
PLAY [讓控制節點認得 GPU VM]
TASK [部署控制節點的共用 Slurm 設定] changed: [instance-20260923-104239]
RUNNING HANDLER [重新讀取 Slurm 設定] changed: [instance-20260923-104239]
PLAY [啟動 GPU VM 的 Slurm 運算服務]
TASK [設定有變更時重啟 GPU VM 的 slurmd] changed: [compute-gpu01]
TASK [確保 GPU VM 的 slurmd 已啟動] changed: [compute-gpu01]
PLAY RECAP
compute-gpu01            : ok=10 changed=4 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
instance-20260923-104239 : ok=3 changed=2 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

`rc=0` 是 `slurmd -G` 的結束代碼，表示這條檢查指令正常結束。
`stderr_lines` 的第二行顯示一張 `nvidia_l4` 對應 `/dev/nvidia0`；
第一行表示沒有額外的 `cgroup.conf`，這次檢查使用預設值。
控制節點設定已取代原單節點內容並由 `scontrol reconfigure` 重新讀取；
GPU VM 的 `slurmd` 已啟動並設為開機啟動。
這些結果尚未證明 GPU VM 已在控制端註冊、工作能使用 GPU，
或 GPU 工作已受隔離。

## 4. 從控制節點查 GPU 節點是否註冊

上一步已啟動 GPU VM 的 `slurmd`，但 playbook 成功只證明服務任務完成。
在**控制節點**以 root 執行下列只讀命令。
`scontrol` 向正在運行的 `slurmctld` 查詢名為 `compute-gpu01` 的節點；
這條指令不執行 playbook，不提交工作，也不改動檔案或服務。

```bash
scontrol show node compute-gpu01
```

結果要核對 `NodeName` 是 `compute-gpu01`、`NodeAddr` 是 GPU VM 的
私有 IP `10.146.0.3`、`Gres` 宣告一張 `nvidia_l4`，
並看 `State` 判斷控制端是否認為節點可接工作。
這只驗證控制端看到的節點狀態；GPU 工作是否真的能使用裝置，
仍須由實際 Slurm 工作驗證。

```text
NodeName=compute-gpu01 Arch=x86_64 CoresPerSocket=2
   CPUAlloc=0 CPUEfctv=4 CPUTot=4 CPULoad=0.00
   Gres=gpu:nvidia_l4:1(S:0)
   NodeAddr=10.146.0.3 NodeHostName=compute-gpu01 Version=26.05.4
   RealMemory=14000 AllocMem=0 FreeMem=14239 Sockets=1 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=gpu
   BootTime=2026-10-09T05:28:30 SlurmdStartTime=2026-10-09T06:49:45
```

控制服務已記錄 GPU VM 的私有 IP、4 個可用邏輯 CPU、
14,000 MiB 可排程記憶體和一張 `nvidia_l4`。
`State=IDLE`、`CPUAlloc=0`、`AllocMem=0` 表示查詢時節點可接新工作且未分配資源；
`SlurmdStartTime` 顯示運算服務已啟動。
這是節點註冊證據，還不是 GPU 工作或 GPU 隔離證據。

## 5. 用 Slurm 請求一張 GPU 的通路驗證

控制端已將 `compute-gpu01` 列為 `IDLE`，接著要確認一般帳號能透過
Slurm 的 `gpu` 分區請求一張 GPU，並在該分區唯一的 GPU VM 啟動程序。
此處先用驅動提供的 `nvidia-smi -L` 讀取裝置清單，
核對排程請求和 GPU 裝置通路；它不是代表性計算工作，
也不能證明 GPU 隔離或計算結果正確。

在**控制節點**以 root 執行下列一條指令。
`sudo -iu a2264` 改用一般工作帳號；`srun` 向 Slurm 提交同步工作；
`--partition=gpu` 選 GPU 分區，`--nodes=1 --ntasks=1` 請求一個節點、
一個行程，`--gres=gpu:1` 請求一張 GPU，`--time=00:02:00` 限制最多兩分鐘。
Slurm 在分配的節點執行 `nvidia-smi -L` 並把輸出帶回控制節點。
這條命令不執行 playbook，也不改服務設定或建立雲端資源；
預期輸出列出一張 NVIDIA L4，若工作無法分配或啟動，依實際訊息排查。

```bash
sudo -iu a2264 srun --partition=gpu --nodes=1 --ntasks=1 --gres=gpu:1 --time=00:02:00 nvidia-smi -L
```

```text
GPU 0: NVIDIA L4 (UUID: GPU-60db0aa8-3f64-a75a-bd6f-cf44fe764b36)
```

Slurm 接受一張 GPU 的請求，並在 `gpu` 分區啟動了 `a2264` 的程序；
程序能透過 NVIDIA 驅動讀到一張 L4。
這是排程與裝置可見性的初步驗證，不是 GPU 計算正確性、
節點主機名或 GPU 隔離的證據。

## GPU 計算工具準備

下一步要用有已知答案的 GPU 計算工作，核對 Slurm 分配的裝置能否真的執行計算。
GPU VM 原有的 NVIDIA 驅動能執行 `nvidia-smi`，但尚缺編譯 CUDA 程式的工具。
從 GPU VM 已啟用的 AlmaLinux NVIDIA 套件庫安裝 CUDA 13.4 編譯器與
CUDA 執行階段開發檔；安裝交易新增下列套件，沒有升級 NVIDIA 驅動或 Slurm：

| GPU VM 新增套件 | 版本 |
|---|---|
| `cuda-nvcc-13-4` | `13.4.59-1` |
| `cuda-cudart-devel-13-4` | `13.4.49-1` |
| `cuda-crt-13-4` | `13.4.59-1` |
| `cuda-cudart-13-4`、`cuda-culibos-devel-13-4` | `13.4.49-1` |
| `cuda-toolkit-13-4-config-common`、`cuda-toolkit-13-config-common`、`cuda-toolkit-config-common` | `13.4.49-1` |
| `cccl-13-4` | `13.3.4.2.1-1` |
| `libnvptxcompiler-13-4`、`libnvvm-13-4` | `13.4.59-1` |
| `gcc-c++`、`libstdc++-devel` | `14.3.1-4.4.el10.alma.2` |

從控制節點透過 Ansible 在 GPU VM 查詢編譯器版本；套件將它放在
`/usr/local/cuda-13.4/bin/nvcc`，因此使用絕對路徑，不假定它在登入環境的 `PATH` 中。
這條查詢不編譯程式，也不修改服務：

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml gpu_compute -m ansible.builtin.command -a '/usr/local/cuda-13.4/bin/nvcc --version'
```

```text
compute-gpu01 | CHANGED | rc=0 >>
nvcc: NVIDIA (R) Cuda compiler driver
Cuda compilation tools, release 13.4, V13.4.59
```

版本查詢成功；Ansible 的 `CHANGED` 是此一次性 `command` 任務的預設標記，
不代表查詢改動了檔案。安裝後 GPU VM 的 `nvidia-smi -L` 仍辨認一張 L4。

## 6. 用熱擴散工作核對 GPU 計算

驅動可見與 GPU 分配已驗證，下一步要確認分配到的 L4 真的完成計算。
[heat2d.cu](../project/workloads/heat2d.cu) 實作二維熱擴散：
在 `1024 × 1024` 網格中心放一個熱源，每輪用上下左右格點更新溫度，
共執行 200 輪。CPU 與 GPU 使用相同初始條件和更新式，
最後逐格比較，最大絕對誤差不超過 `0.0001` 才輸出 `validation=PASS`。
程式也列出執行主機與 GPU 名稱，供核對工作實際執行的位置和裝置。

先從**控制節點**把工作樹中的原始碼複製到控制節點自己的
`/srv/hpc-share/heat2d.cu`，設為 `a2264` 可讀寫。
這個路徑已由模組 04 建立並由 `nfs-gpu-client.yml` 核對掛載；
GPU VM 的同一路徑是 NFS 掛載，讀到的是控制節點提供的檔案。
下面的 Ansible `copy` 只更新這份共享原始碼，沒有複製到 GPU VM 的 `/etc/`：

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml controller -b -m ansible.builtin.copy -a 'src=/root/hpc-arch/project/workloads/heat2d.cu dest=/srv/hpc-share/heat2d.cu owner=a2264 group=a2264 mode=0644'
```

```text
instance-20260923-104239 | CHANGED => {
    "changed": true,
    "dest": "/srv/hpc-share/heat2d.cu",
    "owner": "a2264",
    "group": "a2264",
    "mode": "0644",
    "size": 6778
}
```

共享原始碼已在控制節點建立，屬於 `a2264`；GPU VM 由既有 NFS 掛載讀取它。

複製完成後，從**控制節點**透過 Ansible 以 `a2264` 在 **GPU VM**
執行下列 `nvcc` 命令，讀取 GPU VM 掛載的原始碼，
編譯成同一共享目錄內的 `heat2d` 執行檔。
`-O2` 啟用編譯最佳化，`-std=c++17` 指定 C++ 語言版本；
`-arch=sm_89` 產生對應 L4 運算能力 8.9 的 GPU 程式碼。
這一步會建立或覆寫 `/srv/hpc-share/heat2d`，不改 Slurm 設定或服務：

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml gpu_compute -b --become-user a2264 -m ansible.builtin.command -a '/usr/local/cuda-13.4/bin/nvcc -O2 -std=c++17 -arch=sm_89 -o /srv/hpc-share/heat2d /srv/hpc-share/heat2d.cu'
```

```text
compute-gpu01 | CHANGED | rc=0 >>
```

GPU VM 編譯成功，終端沒有其他輸出；執行檔已寫入共享目錄。

最後在**控制節點**以 `a2264` 提交同步 Slurm 工作，
請求 `gpu` 分區的一個節點、一個 task、一張 GPU、512 MiB 記憶體，
並限制最長五分鐘。`srun` 在分配的 GPU VM 執行共享目錄中的程式，
輸出直接回到控制節點終端；程式不讀寫資料檔或改動服務。
要同時核對 `host=compute-gpu01`、`device=NVIDIA L4`、
`validation=PASS` 和工作正常返回，才能確認本次 GPU 計算通路：

```bash
sudo -iu a2264 srun --partition=gpu --nodes=1 --ntasks=1 --cpus-per-task=1 --gres=gpu:1 --mem=512M --time=00:05:00 /srv/hpc-share/heat2d 1024 200
```

```text
host=compute-gpu01 device_index=0 device=NVIDIA L4 grid=1024x1024 steps=200
cpu_sum=65535.998004 gpu_sum=65535.998004 max_abs_error=0.00000000
cpu_ms=504.605 gpu_kernel_ms=1.894 validation=PASS
```

工作在 `compute-gpu01` 使用 NVIDIA L4 完成 200 輪計算；CPU 與 GPU
結果逐格比對通過，輸出後返回控制節點提示字元。

## 7. VM 供給方式與 OpenStack 的對照

### 為什麼在這裡談 OpenStack

目標職缺把 OpenStack 列為加分項。現在的叢集已用 GCP 建出兩台 VM，
所以這裡要理解的是：若換一種雲平台供給節點，哪些建機與網路決策要重新確認，
哪些 VM 內的 NFS、MUNGE、Slurm 配置仍可由 Ansible 接手。
目前沒有可操作的 OpenStack 平台；這一節交付流程對照，不是部署或操作證據。

**OpenStack 是一套開源雲端基礎設施軟體**，讓組織透過 API 或管理介面
供給 VM、網路和儲存資源。用已做過的事理解：在 GCP 執行
`gcloud compute instances create` 申請 VM；在採用 OpenStack 的環境，
會向該環境的 OpenStack 服務申請 VM 及其網路、映像和磁碟。
VM 建好後，仍要另外配置登入、共享資料與 Slurm，工作才會進入 HPC 叢集。
[OpenStack 官方概覽](https://docs.openstack.org/install-guide/get-started-with-openstack.html)
將它定位為提供基礎設施即服務的多個協作元件。

### 對照目前建立 GPU 節點的流程

目前的 GPU VM 是由 GCP 建立：模組 04 的
`gcloud compute instances create compute-gpu01` 指定機型、AlmaLinux 映像、
開機磁碟、私有網路和無外部 IP；Cloud Router／NAT 另提供對外出口。
VM 已啟動後，Ansible 才透過 SSH 配置 NFS、MUNGE 與 Slurm。
若公司使用 OpenStack，先要分清**供給 VM**與**配置 VM 內的叢集服務**：
前者由雲平台負責，後者仍可由 Ansible 管理。
OpenStack 將供給能力分在不同服務：**Nova** 管 VM，**Glance** 管映像，
**Cinder** 管區塊儲存，**Neutron** 管網路，**Keystone** 管 API 身分與權限。
Nova 的 **flavor** 類似目前選用的 VM 機型，描述一種可申請的資源規格。

| 目前 GCP 的實際選擇 | OpenStack 中要確認的元件與能力 |
|---|---|
| `g2-standard-4`、一張 L4 | Nova 建立 VM；flavor 描述 CPU、記憶體等規格。GPU 供給需確認該雲的 Nova PCI 裝置配置、可用實體 GPU 與排程規則，不能只把機型名稱換掉。 |
| AlmaLinux 映像、40 GiB 開機磁碟 | Glance 提供映像；開機磁碟可依平台選用映像啟動或 Cinder volume，須核對映像、磁碟容量與啟動方式。 |
| 私有 IP、無 VM 外部 IP、Cloud NAT 對外出口 | Neutron 管理網路、子網、port、安全群組及路由；若工作節點需要對外下載套件，須核對該環境的外部 gateway／SNAT。Neutron router 不是 GCP Cloud NAT 的逐項同名替代。 |
| GCP 專案權限與執行個體 SSH 中繼資料 | Keystone 管理 OpenStack API 的身分與專案權限；VM 內的 SSH 登入、Linux UID/GID 和 MUNGE 金鑰仍須另外配置與驗證。 |
| 建好 VM 後由 Ansible 設定 Slurm | 取得 VM 的可達位址與登入方式後，更新 inventory，再部署各 VM 的 `/etc/slurm/slurm.conf`、MUNGE 與共享資料掛載；Slurm 排工作，Nova 負責供給 VM，兩者分屬不同層。 |

這份對照依據[模組 04 的實際 GCP 建機紀錄](module-04.md#東京-gpu-節點的配置)
與 OpenStack 官方的
[Nova VM 建立說明](https://docs.openstack.org/nova/latest/user/launch-instances.html)、
[PCI 裝置配置](https://docs.openstack.org/nova/latest/admin/pci-passthrough.html)、
[Neutron 網路說明](https://docs.openstack.org/neutron/latest/admin/intro-os-networking.html)、
[Cinder 磁碟說明](https://docs.openstack.org/cinder/latest/admin/volume-backed-image.html)
及 [Keystone 身分說明](https://docs.openstack.org/keystone/latest/contributor/services.html)。
目前沒有 OpenStack 平台操作輸出，因此這是供給流程與責任邊界的對照，
不能列為 OpenStack 實作經驗。

## 8. 單 GPU 配額下替換乾淨節點

**最終交付維持兩台 VM：一台 CPU 控制／運算節點，加一台 GPU 運算節點。**
原 GPU VM `compute-gpu01` 已能完成 Slurm GPU 工作；
要驗證乾淨節點首次部署，須換一台從 AlmaLinux 映像啟動的 GPU VM。
配額只允許同時運行一張 GPU，因此先準備重建材料，再停止舊 GPU VM，
保留其開機磁碟與設定供回復，建立新節點 `compute-gpu02`。
停止舊 VM 後，GPU 工作會暫時不可用；控制節點及其 NFS 分享仍運行。
Google Cloud 說明[停止 VM 後 GPU 不再保留](https://docs.cloud.google.com/compute/docs/instances/suspend-stop-reset-instances-overview)，
但新建或重啟 VM 仍取決於該 zone 的即時 GPU 容量。

| 角色 | 最終規格與位置 | 已確認／待執行 |
|---|---|---|
| CPU 控制／提交／運算／NFS | `instance-20260923-104239`；台灣 `asia-east1-b`；`e2-custom-2-4096`，2 vCPU、4 GiB；10 GiB 開機磁碟、100 GiB 附加磁碟；私有 IP `10.140.0.2`；Slurm `debug` 分區宣告 2 CPU、3000 MiB | 已運行；本次不重建 |
| GPU 運算 | 規劃 `compute-gpu02`；東京 `asia-northeast1-c`；`g2-standard-4`，4 vCPU、16 GiB、一張具 24 GiB 顯示記憶體的 NVIDIA L4；40 GiB `pd-balanced` 開機磁碟；AlmaLinux 10、既有 `default` VPC／東京 subnet、無 VM 外部 IP 或服務帳戶；新私有 IP 待建機後確認；Slurm `gpu` 分區預計宣告 4 CPU、14000 MiB、一張 L4 | 舊 GPU VM 已停止；新 VM 尚未建立 |

既有 Cloud NAT 提供東京私有 VM 對外出口；新 VM 要實際驗證網路，
不能只憑同一 subnet 推定可用。原建機映像
`almalinux-10-v20260811` 目前標為 `DEPRECATED`；
已查到 `almalinux-10-v20261005` 為 `READY`、`X86_64`，
作為新 VM 的候選映像，建機前仍須核對其狀態。
既有控制節點建出的 Slurm 26.05.4 原始碼與兩個運算端 RPM，
已保存於[專案套件目錄](../project/packages/slurm/README.md)，
附 SHA-256 值；新 VM 的安裝、套件相依性與相容性尚未驗證。
舊 GPU VM 的驅動與 CUDA 已確認來自 AlmaLinux 套件庫；
新映像的核心與實際可安裝版本仍須在新 VM 上核對，不能把舊 VM 的成功當成新 VM 的成功。

在**控制節點**透過 Ansible 對舊 GPU VM 執行唯讀 `rpm -q`，
核對已安裝的套件名稱與版本。
`-b` 用管理員身分遠端查詢，Ansible 的 `CHANGED` 是 `command` 模組預設標記，
不代表此查詢更新了套件：

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml gpu_compute -b -m ansible.builtin.command -a 'rpm -q almalinux-release-nvidia-driver nvidia-driver nvidia-open-kmod cuda-nvcc-13-4 cuda-cudart-devel-13-4'
```

```text
compute-gpu01 | CHANGED | rc=0 >>
almalinux-release-nvidia-driver-10-5.el10_1.x86_64
nvidia-driver-615.71.09-1.el10.x86_64
nvidia-open-kmod-615.71.09-1.el10_2.x86_64
cuda-nvcc-13-4-13.4.59-1.x86_64
cuda-cudart-devel-13-4-13.4.49-1.x86_64
```

舊 VM 上套件確實已安裝。再查其已啟用套件庫中可供下載的版本，
`--available` 查套件庫提供的版本，`--qf` 顯示套件名、版本及來源庫；
它不安裝套件，也不保證新映像會有相同核心或相同可用版本：

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml gpu_compute -b -m ansible.builtin.command -a 'dnf repoquery --available almalinux-release-nvidia-driver nvidia-driver nvidia-open-kmod cuda-nvcc-13-4 cuda-cudart-devel-13-4 --qf=%{name}-%{version}-%{release}@%{repoid}'
```

```text
compute-gpu01 | CHANGED | rc=0 >>
almalinux-release-nvidia-driver-10-5.el10_1@extras
cuda-cudart-devel-13-4-13.4.49-1@almalinux-nvidia
cuda-nvcc-13-4-13.4.59-1@almalinux-nvidia
nvidia-driver-615.71.09-1.el10@almalinux-nvidia
nvidia-open-kmod-615.71.09-1.el10_2@almalinux-nvidia
```

上面只保留本次重建要用的版本；查詢也列出其他較舊版本。
`extras` 提供 NVIDIA 套件庫設定包，`almalinux-nvidia` 提供驅動與 CUDA。
新 VM 建好後仍要先確認其套件庫與核心，再安裝並實測 L4。

### 停機前的資源核對

在**控制節點**以 root 查東京區域目前的 GPU 配額。
這條 `gcloud compute regions describe` 只讀 GCP 配額，
`--format` 讓回傳資料保留 `metric`、`limit` 與 `usage`；
取出 `NVIDIA_L4_GPUS` 後核對可同時運行的卡數。
它不停止 VM，也不預留新 GPU：

```bash
gcloud compute regions describe asia-northeast1 --project=project-78b8a95c-a2c0-461f-a08 '--format=json(quotas)'
```

```text
NVIDIA_L4_GPUS: limit=1, usage=1
```

原始回應還有其他配額；上面只保留這次決策需要的欄位。
目前唯一可用的 L4 配額已由舊 VM 使用，符合先停舊 VM 再建新 VM 的順序。

同在控制節點查兩個 GPU VM 名稱的存在與狀態，
`--filter` 限定名稱，`--format` 只列名稱、zone、機型、狀態與私有 IP。
這條命令不變更 VM：

```bash
gcloud compute instances list --project=project-78b8a95c-a2c0-461f-a08 --filter='name=(compute-gpu01 OR compute-gpu02)' --format='table(name,zone.basename(),machineType.basename(),status,networkInterfaces[0].networkIP)'
```

```text
NAME           ZONE               MACHINE_TYPE   STATUS   NETWORK_IP
compute-gpu01  asia-northeast1-c  g2-standard-4  RUNNING  10.146.0.3
```

查詢當下 `compute-gpu01` 正在運行，`compute-gpu02` 尚不存在。
這是停機與建機前的資源狀態，不代表替換已執行。

### 停機前的工作佇列

在**控制節點**以 root 讀取 Slurm 目前的工作清單。
`-h` 省略欄名，`-o` 保留工作 ID、狀態、使用者與名稱；
若有執行中或等待中的工作，先處理後再停止 GPU VM。
這條命令只查佇列，不取消工作或改動 VM：

```bash
squeue -h -o '%i %T %u %j'
```

**結果：** 指令正常返回、沒有工作列。查詢當下沒有執行中或等待中的工作；
這是停機前的即時佇列核對，仍須以停機指令的實際結果確認 VM 狀態。

### 停止舊 GPU VM

這條命令從**控制節點**以 root 送出，停止東京的
`compute-gpu01`，釋出目前占用的 L4 配額。它不刪除 VM 或開機磁碟，
但會中斷 GPU 分區的可用性；磁碟仍計費。`--quiet` 不再要求互動確認。
停機後須核對狀態為 `TERMINATED`，再建立新 VM。

```bash
gcloud compute instances stop compute-gpu01 --project=project-78b8a95c-a2c0-461f-a08 --zone=asia-northeast1-c --quiet
```

```text
Stopping instance(s) compute-gpu01...done.
Updated [https://compute.googleapis.com/compute/v1/projects/project-78b8a95c-a2c0-461f-a08/zones/asia-northeast1-c/instances/compute-gpu01].
```

GCP 已接受並完成停止操作。接下來讀取 VM 狀態、開機磁碟與配額，
確認舊機與磁碟仍在，且有額度建立新機。

在**控制節點**讀取舊 VM 的狀態、開機磁碟參照與私有 IP；
`gcloud compute instances describe` 不變更 VM，
人工核對 `status`、`disks` 中 `boot` 磁碟的 `source`，以及原位址：

```bash
gcloud compute instances describe compute-gpu01 --project=project-78b8a95c-a2c0-461f-a08 --zone=asia-northeast1-c '--format=json(status,disks,networkInterfaces)'
```

```text
status: TERMINATED
boot disk source: .../zones/asia-northeast1-c/disks/compute-gpu01
boot disk autoDelete: true
internal IP: 10.146.0.3
```

上面摘錄決策所需欄位；`autoDelete=true` 是**刪除 VM 時**的磁碟處理設定，
不代表停止 VM 就會刪磁碟。接著直接讀取該磁碟，核對它仍存在：

```bash
gcloud compute disks describe compute-gpu01 --project=project-78b8a95c-a2c0-461f-a08 --zone=asia-northeast1-c '--format=json(name,sizeGb,type,status,users)'
```

```text
name: compute-gpu01
sizeGb: 40
status: READY
type: .../diskTypes/pd-balanced
users: [.../instances/compute-gpu01]
```

磁碟仍附屬舊 VM，可供需要時嘗試重啟回復。

再讀取東京區域配額，沿用前述只讀命令；這次只摘錄 L4 欄位：

```bash
gcloud compute regions describe asia-northeast1 --project=project-78b8a95c-a2c0-461f-a08 '--format=json(quotas)'
```

```text
NVIDIA_L4_GPUS: limit=1, usage=0
```

停舊 VM 後 L4 配額使用量已降為 0。配額允許申請一張，
但是否有實際容量，仍由建機操作的結果決定。

最後核對新映像仍可使用，`status` 要是 `READY`，`architecture` 要是 `X86_64`：

```bash
gcloud compute images describe almalinux-10-v20261005 --project=almalinux-cloud '--format=json(name,status,architecture,deprecated,diskSizeGb)'
```

```text
name: almalinux-10-v20261005
status: READY
architecture: X86_64
diskSizeGb: 10
```

這是可用的 AlmaLinux 10 映像；建機命令會建立 40 GB 開機磁碟。

### 建立新 GPU VM（待執行）

從**控制節點**以 root 向 GCP 建立 `compute-gpu02`。這一步只供給 VM，
尚未把它加入 Slurm、NFS 或安裝驅動。`--metadata-from-file` 讀取控制節點
`/tmp/compute-gpu01-a2264-ssh-keys-20261003` 內既有的 `a2264` SSH **公鑰**，
讓同一管理金鑰可登入新 VM；私鑰不送到 GCP。該檔案存在，大小為 118 bytes。
`--no-address` 不給 VM 外部 IP，`--no-service-account --no-scopes` 不授予 VM
雲端 API 身分；`--max-run-duration=2h` 到時由 `--instance-termination-action=STOP`
停止 VM，避免無人看管時持續運行。`--quiet` 省略互動確認。

```bash
gcloud compute instances create compute-gpu02 \
  --project=project-78b8a95c-a2c0-461f-a08 \
  --zone=asia-northeast1-c \
  --machine-type=g2-standard-4 \
  --image-project=almalinux-cloud \
  --image=almalinux-10-v20261005 \
  --boot-disk-type=pd-balanced \
  --boot-disk-size=40GB \
  --network=default \
  --subnet=default \
  --no-address \
  --no-service-account \
  --no-scopes \
  --metadata-from-file=ssh-keys=/tmp/compute-gpu01-a2264-ssh-keys-20261003 \
  --maintenance-policy=TERMINATE \
  --max-run-duration=2h \
  --instance-termination-action=STOP \
  --quiet
```

本命令尚未執行。成功時要從輸出取得新 VM 私有 IP；
若雲端回報容量不足，停止後續部署並保留舊 VM。

建機後的**待執行**步驟如下，不是已完成的部署成果：

1. 取得新 VM 的私有 IP，確認 SSH、私有網路與套件來源，
   再依序部署 MUNGE、NFS 掛載與 Slurm。
   在控制節點工作樹更新 `project/ansible/inventory/hosts.yml` 的 GPU 目標與位址，
   並將 `project/nfs/hpc-share.exports` 的允許來源改為新 VM 的私有 IP，
   再由 NFS playbook 更新控制節點自己的 `/etc/exports.d/hpc-share.exports`。
   更新工作樹的 `project/slurm/two-node-slurm.conf` 節點名稱與 IP 後，
   由 Slurm playbook 分別複製到控制節點與新 GPU VM 各自的
   `/etc/slurm/slurm.conf`；同一 playbook 把 `project/slurm/gpu-gres.conf`
   複製到新 GPU VM 的 `/etc/slurm/gres.conf`，核對它偵測到一張 L4。
2. 由 Slurm 查新節點註冊狀態，以一般帳號在新 VM 執行可核對結果的 GPU 工作；
   同時核對共享資料讀取、MUNGE 驗證、主機名、L4 與 `validation=PASS`。
   這只能證明**乾淨 GPU 節點加入既有控制節點**，不是整個叢集從零重建。
3. 若新節點未通過，先停止新 VM，再把 inventory、NFS 匯出與 Slurm 設定
   恢復到舊節點的名稱和 IP，重新啟動 `compute-gpu01` 並用工作驗證回復。
   停止後釋出的 L4 不保證立即能重新取得，這是本方案的容量風險。
   若新節點通過並決定留下，才移除舊 VM；最終仍只有一台 CPU VM 和一台 GPU VM。

舊 GPU VM 的 40 GiB 開機磁碟目前設為 `autoDelete=true`。
若日後刪除 VM，預設會刪掉磁碟；
[Google Cloud 的 `--keep-disks=boot` 說明](https://docs.cloud.google.com/compute/docs/instances/deleting-instance)
提供保留開機磁碟的方式。停止期間及保留後的磁碟仍會計費；
新 VM 啟動後另有 VM、GPU 與新磁碟費用。
實際要用的新 VM 指令、版本與路徑，待映像及套件來源確認後，
在執行前依序補入本模組；此處不預寫未確認可用的命令。

## 目前限制

- 尚未由 Slurm 跨節點執行 CPU 工作。
- NFS、MUNGE 與 Slurm playbook 已在既有兩台 VM 執行；
  尚未驗證乾淨環境的首次部署。
- 單張 L4 只能驗證單 GPU 管理，不能當成多卡隔離或大型生產叢集經驗。
- 本模組後續仍須交付可核對的跨節點 CPU 工作、可恢復的故障處理、
  乾淨節點重建證據。OpenStack 目前只有供給流程對照，沒有平台操作證據。
