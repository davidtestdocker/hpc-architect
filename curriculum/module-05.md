# 模組 05：HPC 叢集建置與管理自動化

[能力路線](ROADMAP.md)｜職缺核心：叢集建置與管理自動化。

## 要解決的問題與交付物

模組 04 已讓控制節點透過 SSH 在 GPU VM 執行 MPI 工作，
兩台 VM 也能讀寫 NFS 共享目錄。這證明計算與資料通路可用，
但當時 GPU VM 並未接受 Slurm 排程。
本模組把節點設定寫成可重跑的 Ansible playbook，
讓控制端能管理 GPU VM 的身分驗證、Slurm 設定和運算服務。

目前已完成既有兩台 VM 的 NFS、MUNGE、Slurm 服務帳號及兩節點設定部署。
**下一項必要驗證是控制端是否看到 GPU 節點，以及 Slurm 工作能否取得 CPU／GPU 資源。**
現有結果不代表已從乾淨節點重建，也不代表 GPU 工作已成功。

## 執行順序與檔案位置

所有 Ansible 指令都在**控制節點**的
`/root/hpc-arch/project/ansible` 目錄以 root 執行。
[ansible.cfg](../project/ansible/ansible.cfg) 指向
[hosts.yml](../project/ansible/inventory/hosts.yml)，
其中 `controller` 是控制節點本機，`gpu_compute` 是透過既有 SSH 金鑰
連到私有 IP `10.146.0.3` 的 `compute-gpu01`。
Inventory 只列出已存在的 VM，不會建立雲端資源。

| 步驟 | 在哪台 VM 建立或核對什麼 | 使用的 playbook |
|---|---|---|
| 1. 共享資料路徑 | 控制節點 NFS 分享、GPU VM NFS 掛載 | [nfs-controller.yml](../project/ansible/nfs-controller.yml)、[nfs-gpu-client.yml](../project/ansible/nfs-gpu-client.yml) |
| 2. 跨節點驗證 | GPU VM 的 MUNGE 金鑰和服務 | [munge-gpu.yml](../project/ansible/munge-gpu.yml) |
| 3. 確認硬體與帳號空間 | GPU VM 的 CPU、記憶體、GPU；兩台 VM 可用的 UID/GID | 只讀查詢 |
| **4. 統一 Slurm 服務帳號** | GPU VM 建立 `slurm:slurm`，控制節點將原帳號與排程狀態改為 `800:800` | [slurm-identity.yml](../project/ansible/slurm-identity.yml) |
| **5. 部署兩節點 Slurm** | 兩台 VM 各自的 `slurm.conf`、GPU VM 的 `gres.conf`，以及運算服務 | [slurm-two-node.yml](../project/ansible/slurm-two-node.yml) |

**`slurm-identity.yml` 必須在 `slurm-two-node.yml` 之前正式執行。**
因為兩節點設定的 `SlurmUser=slurm` 要在兩台 VM 上指向一致的身分；
GPU VM 的 `994:994` 已由 `munge` 使用，不能直接沿用控制節點原來的
`slurm` UID/GID `994:994`。本次選用經兩台 VM 查詢未占用的 `800:800`。
帳號修正是正式部署流程的一步，不是事後另加的排障操作。

工作樹中的 `project/` 檔案是**部署來源**；
`/etc/` 下的檔案才是各 VM 服務實際讀取的檔案。
相同路徑出現在兩台 VM 時，各自是本機磁碟上的一份，並非同一個檔案。
下方每個步驟分別說明來源、目標及服務何時讀取。

## Ansible 如何管理這兩台 VM

Ansible 沿用模組 04 已驗證的 SSH 管理通路。
**Inventory** 列目標主機；**playbook** 描述檔案、掛載和服務應有的狀態；
**handler** 在任務真的變更時才由 `notify` 觸發。
正式執行的 `changed` 表示已改動受管狀態；`changed=0` 表示重跑沒有額外變更。
`--syntax-check` 只解析 playbook，`--check --diff` 只預演，
都不能當成檔案已複製或服務已啟動。

從控制節點讀取預設 inventory，不連線或修改 GPU VM：

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

兩個群組各有預期的 VM。接著透過 SSH 在 GPU VM 執行 Ansible 的連線測試；
這個 `ping` 不是 ICMP，回傳 `pong` 才代表遠端模組可執行：

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

## 1. NFS 共享資料路徑

模組 04 已手動驗證兩台 VM 對 `/srv/hpc-share` 的雙向讀寫。
[nfs-controller.yml](../project/ansible/nfs-controller.yml) 確保控制節點有
`nfs-utils`、共享目錄及匯出設定；匯出設定的來源是控制節點工作樹中的
[hpc-share.exports](../project/nfs/hpc-share.exports)，目標是**控制節點自己的**
`/etc/exports.d/hpc-share.exports`。檔案真的變更時，handler 才執行
`exportfs -ra`，讓 NFS 重新讀取分享清單，不重啟服務。
本次正式執行時現有狀態已符合設定：

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-controller.yml
```

```text
PLAY RECAP
instance-20260923-104239 : ok=5 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

[nfs-gpu-client.yml](../project/ansible/nfs-gpu-client.yml)
確保 GPU VM 的 `nfs-utils`、`/etc/fstab` 項目及掛載狀態，
將控制節點 `10.140.0.2:/srv/hpc-share` 接到**GPU VM 自己的**
`/srv/hpc-share`。`ansible.posix.mount` 來自
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

## 2. MUNGE 跨節點身分驗證

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

[munge-gpu.yml](../project/ansible/munge-gpu.yml) 從**控制節點的**
`/etc/munge/munge.key` 直接複製到**GPU VM 自己的**同名路徑，
設為 `munge:munge`、`0600`，並啟用 GPU VM 的 `munge` 服務。
金鑰真的改動時，handler 重啟 GPU VM 的 MUNGE；
Ansible 不顯示金鑰內容或差異。
正式部署的必要結果：

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

## 3. GPU VM 硬體與 Slurm 帳號空間

Slurm 按節點宣告的 CPU、記憶體和 **GRES**（通用資源）分配工作；
GPU 是本叢集的 GRES。先在 GPU VM 以 `a2264` 執行 `slurmd -C`，
只讀取本機硬體並列出建議節點設定，不啟動服務：

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

控制節點原有 `slurm` 帳號是 `994:994`，
GPU VM 的這組數字已屬於 `munge`。在控制節點的 Ansible 目錄
以 root 查兩台 VM 的候選 UID/GID `800`；`fail_key=false` 讓
「查無此身分」回傳空值，查詢不建立帳號：

```bash
ansible all -m ansible.builtin.getent -a 'database=passwd key=800 fail_key=false'
ansible all -m ansible.builtin.getent -a 'database=group key=800 fail_key=false'
```

**結果：** 兩台 VM 的 `getent_passwd["800"]` 與
`getent_group["800"]` 都是 `null`；兩條命令均回傳
`SUCCESS`、`changed=false`。因此選 `800:800` 作為兩端的 `slurm` 身分。

控制端的 `/var/spool/slurmctld` 及其狀態檔由原 `slurm` 帳號持有；
改 UID/GID 後必須一起調整擁有權。
已查到服務由 `slurm:slurm` 執行，`/run/slurmctld` 由 systemd 的
`RuntimeDirectory` 管理，`StateDirectory` 為空：

```bash
ansible controller -b -m ansible.builtin.command -a 'systemctl show slurmctld -p ActiveState -p User -p Group -p RuntimeDirectory -p StateDirectory'
```

```text
User=slurm
Group=slurm
RuntimeDirectory=slurmctld
StateDirectory=
ActiveState=active
```

## 4. 先執行 slurm-identity.yml：統一服務帳號

[slurm-identity.yml](../project/ansible/slurm-identity.yml)
先在 GPU VM 建立不可登入、沒有家目錄的 `slurm` 群組和使用者，
UID/GID 固定為 `800:800`。只有 GPU VM 完成，才處理控制節點。
控制端先確認沒有工作，短暫停止 `slurmctld`，
把原 `slurm` 帳號改為 `800:800`，並將 `/var/spool/slurmctld`
整個目錄樹交給新身分，再啟動服務並用 `scontrol ping` 核對。
`/run/slurmctld` 在服務啟動時由 systemd 管理。
若控制端遷移途中失敗，playbook 會嘗試恢復原本的 `994:994`
與服務；若連線中斷，仍需依實際狀態人工核對。
這一步會變更兩台 VM 的系統帳號，並短暫中斷控制端排程服務；
不建立 VM、不安裝套件。

在控制節點的 Ansible 目錄以 root 正式執行：

```bash
ansible-playbook slurm-identity.yml
```

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
同一指令重跑時，GPU VM 為 `ok=5 changed=0`，
控制節點為 `ok=4 changed=0 skipped=10`。
跳過的 10 個任務是首次遷移用的工作檢查、停機、改號與服務核對；
重跑沒有再次停止服務。重跑本身沒有重新 ping 控制服務，
`UP` 是首次正式執行的驗證結果。

## 5. 再執行 slurm-two-node.yml：部署排程設定

控制節點工作樹的
[two-node-slurm.conf](../project/slurm/two-node-slurm.conf)
是兩台 VM 的設定**來源**：保留控制節點原有的 `debug` 分區，
新增只包含 GPU VM 的 `gpu` 分區，宣告該節點 4 個邏輯 CPU、
14,000 MiB 可排程記憶體及一張 `nvidia_l4`。
[gpu-gres.conf](../project/slurm/gpu-gres.conf) 是 GPU VM 的 GRES 設定來源，
選用 `AutoDetect=nvidia` 核對本機 NVIDIA 裝置。
各設定項目的用途寫在來源檔的中文註解中。

| 來源：控制節點工作樹 | 目標：服務實際讀取位置 | 執行時機 |
|---|---|---|
| `project/slurm/two-node-slurm.conf` | GPU VM 自己的 `/etc/slurm/slurm.conf` | playbook 先複製；GPU VM 的 `slurmd -G` 接著讀取 |
| `project/slurm/gpu-gres.conf` | GPU VM 自己的 `/etc/slurm/gres.conf` | 與上一份一同交給 `slurmd -G` 檢查 |
| `project/slurm/two-node-slurm.conf` | 控制節點自己的 `/etc/slurm/slurm.conf` | GPU 檢查通過後才取代原單節點設定；`scontrol reconfigure` 請現有 `slurmctld` 重新讀取 |

控制節點的 `/etc/slurm/slurm.conf` 已由模組 01 的 `install -D`
從單節點來源建立；這次 playbook 更新它，不建立另一個共用檔。
GPU VM 的 `/etc/slurm` 和 `/var/spool/slurmd` 已建立，
正式執行時由 playbook 再核對。
若兩台 VM 上的設定檔內容被修改，`copy` 會在該台 VM 留下舊版備份。
`slurmd -G` 檢查 GPU 設定並退出，不啟動服務；
只有檢查成功，playbook 才更新控制節點，最後啟動 GPU VM 的 `slurmd`。
若控制端更新後出現問題，需依輸出查服務狀態，必要時還原控制端
`slurm.conf` 的備份並重新讀取。

修改控制端排程設定前，在控制節點以 root 查工作佇列；
`-h` 不顯示標題，`-o` 列出 ID、狀態、使用者和名稱。
這只讀取當下狀態，不提交或取消工作：

```bash
squeue -h -o '%i %T %u %j'
```

**結果：** 命令正常返回、沒有輸出；查詢當下沒有執行中或等待中的工作。

在控制節點的 Ansible 目錄以 root 正式執行：

```bash
ansible-playbook slurm-two-node.yml
```

```text
PLAY [備妥 GPU VM 的 Slurm 設定並檢查 GPU 對應]
TASK [部署 GPU VM 的共用 Slurm 設定] changed: [compute-gpu01]
TASK [部署 GPU VM 的 GPU 資源設定] changed: [compute-gpu01]
TASK [核對 GPU VM 的 GRES 設定] ok: [compute-gpu01]
"rc": 0,
"stderr_lines": [
    "[2026-10-09T06:49:39.052] Gres Name=gpu Type=nvidia_l4 Count=1 Index=0 ID=7696487 File=/dev/nvidia0 Cores=0-1 CoreCnt=4 Links=(null) Flags=HAS_FILE,HAS_TYPE,ENV_NVML"
]
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

`slurmd -G` 回傳 `rc=0`，顯示一張 `nvidia_l4` 對應 `/dev/nvidia0`。
控制節點設定已取代原單節點內容並由 `scontrol reconfigure` 重新讀取；
GPU VM 的 `slurmd` 已啟動並設為開機啟動。
這些結果尚未證明 GPU VM 已在控制端註冊、工作能使用 GPU，
或 GPU 工作已受隔離。

## 目前限制

- 尚未從控制端讀到 `compute-gpu01` 的 Slurm 節點狀態，
  也尚未執行由 Slurm 分配的 CPU／GPU 工作。
- NFS、MUNGE 與 Slurm playbook 已在既有兩台 VM 執行；
  尚未驗證乾淨環境的首次部署與整套重跑。
- 單張 L4 只能驗證單 GPU 管理，不能當成多卡隔離或大型生產叢集經驗。
- 本模組後續仍須交付可核對的 CPU／GPU 工作、可恢復的故障處理、
  乾淨節點重建證據，以及現有 GCP VM 供給與 OpenStack 的具體對照。
