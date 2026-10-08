# 模組 05：HPC 叢集建置與管理自動化

[能力路線](ROADMAP.md)｜職缺核心：叢集建置與管理自動化。

## 這個模組在做什麼

目前兩台 VM 的 NFS 資料路徑已由人工建好。
模組 04 也已由 `mpirun` 經 SSH 在 GPU VM 執行一個 MPI rank；
GPU VM 早就是實際參與計算的節點。
本模組接著要讓 Slurm 排程器管理它，
由控制節點分配資源、追蹤工作狀態，並讓 GPU VM 接收工作。
如果新建運算節點時還要逐台手動安裝套件、放設定檔、掛載目錄，
就容易漏步驟，也難確認重跑會不會改壞現有服務。

本模組把已驗證的人工步驟寫成 Ansible playbook。
最後要能從乾淨環境重建節點、核對 CPU／GPU 工作結果，
並證明重跑不會產生無意義的變更。
目前只完成其中一部分，不能把兩台教學 VM 當成大型生產叢集經驗。

## 目前成果

| 項目 | 已取得的證據 | 限制 |
|---|---|---|
| Ansible 控制端 | 台灣控制節點已安裝 `ansible-core-1:2.16.16-2.el10_2.1.noarch` | 安裝工具不等於部署節點 |
| 節點清單與連線 | inventory 列出控制節點與 GPU VM；對 GPU VM 執行模組回傳 `pong` | 只證明 Ansible 可連線與遠端執行 |
| 控制節點 NFS | playbook 通過語法檢查、預演及正式執行；正式執行 `ok=5`、`changed=0` | 現有設定已符合要求，這次沒有重建乾淨節點 |
| GPU VM 掛載 | 已安裝 `ansible.posix:2.2.2`；掛載 playbook 經預演、正式執行與重跑，兩次正式執行皆 `ok=3`、`changed=0` | 現有 fstab 與掛載已符合要求；尚無乾淨節點部署證據，雙向讀寫是在模組 04 手動驗證 |
| GPU VM 運算端套件 | 已安裝與控制節點同版的 MUNGE `0.5.15`、Slurm `26.05.4` 及運算端套件 | `slurmd` 尚未啟動，跨節點 Slurm 設定尚未部署 |
| GPU VM MUNGE | 已分發控制節點現有金鑰、啟動服務；控制端憑證在 GPU VM 解碼為 `Success (0)`；重跑 `changed=0` | 尚未部署 GPU VM 的 Slurm 設定或提交 Slurm 工作 |
| GPU VM 資源探測 | `slurmd -C` 回報 4 邏輯 CPU、15,983 MiB 記憶體，偵測到一張 NVIDIA L4 | 只讀硬體探測；尚未註冊進 Slurm 或驗證 GPU 工作 |
| 預設 inventory | 不帶 `-i` 執行 `ansible-inventory --graph`，列出兩組預期主機 | 只證明清單被讀到，不代表部署成功 |

## Ansible 在這個叢集的角色

模組 04 曾由控制節點透過 SSH 登入 GPU VM，手動執行一條遠端命令。
**Ansible** 仍使用這條管理通路，但把主機應有的狀態寫成可重跑規則：

| 名稱 | 在本叢集的意思 |
|---|---|
| inventory | 列出要管理的 VM、群組和連線方式 |
| playbook | 寫出套件、檔案、掛載或服務應有的狀態 |
| handler | 被同名 `notify` 通知後才執行的工作；本例在匯出檔變動時更新 NFS 分享清單 |
| 冪等 | 狀態已符合設定時，再執行不產生不必要的變更 |

執行結果中的 `ok` 表示該任務已符合要求，
`changed` 表示 Ansible 修改了狀態；
`failed` 是任務失敗，`unreachable` 是無法連到目標。
`--check` 只預演可支援的任務，預演中的 `changed` 是預計變更，
不能當成已部署。

Ansible 設定 VM 內的套件、檔案和服務；
Slurm 決定工作在哪個節點執行。
安裝 Ansible 本身不會建立雲端 VM，也不會讓 Slurm 開始排工作。
[Ansible playbook 說明](https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_intro.html)

## 節點清單與管理連線

[hosts.yml](../project/ansible/inventory/hosts.yml) 只列已存在的兩台 VM：

| 群組 | 主機 | Ansible 如何連線 |
|---|---|---|
| `controller` | `instance-20260923-104239` | 控制節點本機連線 |
| `gpu_compute` | `compute-gpu01` | SSH 到 `10.146.0.3`，以 `a2264` 和既有私鑰登入 |

inventory 只保存私鑰**路徑**，不保存私鑰內容。
尚未建立的 CPU 運算節點不列入清單。

### 清單能否讀取

在台灣控制節點以 root 執行。
`-i` 指定要讀的清單；`--graph` 列出群組與主機。
這只讀取 inventory，不登入其他 VM，也不改服務。

```bash
ansible-inventory -i /root/hpc-arch/project/ansible/inventory/hosts.yml --graph
```

```text
@all:
  |--@ungrouped:
  |--@controller:
  |  |--instance-20260923-104239
  |--@gpu_compute:
  |  |--compute-gpu01
```

`controller` 和 `gpu_compute` 各有預期的一台 VM；
`ungrouped` 沒有成員。
這一步尚未測試 SSH。

### 控制節點能否管理 GPU VM

`ansible.builtin.ping` 不是 ICMP `ping`。
它透過 inventory 設定的 SSH 連線，
在 GPU VM 上執行一個小型 Ansible 模組並回傳 `pong`。
成功可核對位址、帳號、金鑰和遠端 Python 執行通路；
不代表 NFS 或 GPU 工作已部署。

在台灣控制節點的 root shell 執行。
`gpu_compute` 選 GPU VM，`-m` 指定要執行的模組。
不改目標服務；SSH 會留下登入紀錄，
Ansible 可能短暫建立並清理遠端暫存檔。

```bash
ansible -i /root/hpc-arch/project/ansible/inventory/hosts.yml gpu_compute -m ansible.builtin.ping
```

```text
compute-gpu01 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

`SUCCESS` 和 `pong` 證明 Ansible 已在 GPU VM 執行模組。
`discovered_interpreter_python` 是遠端 Python 路徑；
`changed: false` 表示沒有修改受管設定。
SSH 私鑰與對應公鑰已在模組 04 建立和配置。

## 控制節點 NFS 設定

[nfs-controller.yml](../project/ansible/nfs-controller.yml)
只選 `controller` 群組，確保 `nfs-utils` 已安裝、
`/srv/hpc-share` 由 `a2264` 擁有且權限為 `0750`、
匯出檔與[模組 04 已用的來源](../project/nfs/hpc-share.exports)一致，
並確保 `nfs-server` 啟動且開機自動啟動。

`copy` 任務**真的改動**匯出檔時，
才用 `notify` 呼叫同名 handler 執行 `exportfs -ra`，
重新讀取 NFS 匯出設定並更新分享清單，不重啟服務。
細項與參數用途寫在 playbook 的中文註解中。

這份 playbook 假設控制節點已有 `a2264` 帳號，
只管理 NFS 伺服器，不負責 GPU VM 的掛載。
若狀態不符，正式套用可能安裝套件、改動目錄或匯出檔、
啟動服務；復原須依實際變更項目處理。

### 語法檢查

在台灣控制節點以 root 執行 `--syntax-check`。
只檢查 playbook 能否解析，不部署 NFS 設定。
此時仍以 `-i` 明確指定 inventory。

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-controller.yml --syntax-check
```

```text
playbook: /root/hpc-arch/project/ansible/nfs-controller.yml
```

Ansible 成功解析 playbook；這不代表部署成功。

### 預演

在台灣控制節點以 root 執行 `--check`。
Ansible 讀取控制節點狀態，預演可能的變更，
不應安裝套件、改寫匯出檔或重啟服務。
結果中的 `changed` 是預計變更。

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-controller.yml --check
```

```text
PLAY [設定控制節點的 NFS 工作資料分享]
TASK [Gathering Facts]                          ok: [instance-20260923-104239]
TASK [確保 NFS 套件已安裝]                        ok: [instance-20260923-104239]
TASK [確保共享目錄的擁有者與權限正確]              ok: [instance-20260923-104239]
TASK [部署只允許 GPU VM 讀寫的 NFS 匯出設定]     ok: [instance-20260923-104239]
TASK [確保 NFS 服務正在運行]                    ok: [instance-20260923-104239]
PLAY RECAP
instance-20260923-104239 : ok=5 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

五項檢查都符合 playbook，沒有預計變更或失敗。
預演未實際部署。

### 正式執行

在台灣控制節點以 root 執行，
目標只有 `controller`。
這次拿掉 `--check`；若執行時狀態與預演不同，
Ansible 仍可能修改檔案或服務。
若有非預期變更，應依 `changed` 項目恢復原設定；
匯出檔恢復後須重新執行 `exportfs -ra`。

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-controller.yml
```

```text
PLAY [設定控制節點的 NFS 工作資料分享]
TASK [Gathering Facts]                          ok: [instance-20260923-104239]
TASK [確保 NFS 套件已安裝]                        ok: [instance-20260923-104239]
TASK [確保共享目錄的擁有者與權限正確]              ok: [instance-20260923-104239]
TASK [部署只允許 GPU VM 讀寫的 NFS 匯出設定]     ok: [instance-20260923-104239]
TASK [確保 NFS 服務正在運行]                    ok: [instance-20260923-104239]
PLAY RECAP
instance-20260923-104239 : ok=5 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

正式執行沒有安裝、複製、修改或重載 NFS 設定。
`changed=0` 只證明現有控制節點已符合這份 playbook；
乾淨節點重建仍待驗證。
GPU VM 掛載與雙向讀寫已在模組 04 驗證，
這次控制節點設定未變，不重複執行相同檢查。

## GPU VM 掛載自動化

控制節點已安裝 `ansible.posix:2.2.2`，
安裝回報 `ansible.posix:2.2.2 was installed successfully`。
[requirements.yml](../project/ansible/requirements.yml)
固定該版本，供重建控制端環境。

[nfs-gpu-client.yml](../project/ansible/nfs-gpu-client.yml)
只選 `gpu_compute` 群組。
它先確保 GPU VM 有 `nfs-utils`，
再讓 GPU VM 把控制節點 `10.140.0.2` 的
`/srv/hpc-share` 接到自己機器的 `/srv/hpc-share`。
前者是資料來源，後者是 GPU VM 使用資料的入口。

這份 playbook 使用 `ansible.posix.mount` 的
`state: mounted`，
預計把掛載寫入 GPU VM 的 `/etc/fstab`
並確保目前已掛載。
設定細節、備份及開機行為寫在 playbook 的中文註解中。
已在現有 GPU VM 上正式執行並重跑，兩次皆無變更；
這證明現有設定符合 playbook，尚未證明能從乾淨節點建立掛載。
若將來需要撤回，先核對 fstab 備份與實際掛載，
移除該項設定；卸載前須確認沒有工作使用共享目錄。

## 用 ansible.cfg 指定預設 inventory

[ansible.cfg](../project/ansible/ansible.cfg)
指定 `inventory/hosts.yml` 作為預設主機清單。
在控制節點的 `/root/hpc-arch/project/ansible` 目錄執行 Ansible 時，
它會讀取這份設定，因此命令可以省略 `-i`。
之前已執行的命令如實保留 `-i`，不改寫紀錄。

這次只測試預設清單是否被讀到。
在上述目錄以 root 執行 `ansible-inventory --graph`；
它不 SSH 到 GPU VM，也不改動檔案或服務。

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

**結果：** 不帶 `-i` 仍列出控制節點與 GPU VM。
這證明此執行目錄中的 `ansible.cfg`
已讓 Ansible 使用專案的 `hosts.yml`；
這一步沒有部署 GPU VM 掛載。

### 掛載設定與執行結果

在台灣控制節點的 `/root/hpc-arch/project/ansible` 目錄以 root 執行。
playbook 的 `opts` 為
`rw,vers=4.2,_netdev,nofail,x-systemd.automount`，
與現有 GPU VM 的 fstab 選項一致。
`--check` 只預演，`--diff` 在模組支援時顯示預計差異；
預演仍會透過 SSH 讀取 GPU VM 狀態，但不應改動掛載或 fstab。

```bash
ansible-playbook nfs-gpu-client.yml --check --diff
```

```text
PLAY [設定 GPU VM 的 NFS 工作資料掛載]
TASK [Gathering Facts]                    ok: [compute-gpu01]
TASK [確保 NFS 用戶端套件已安裝]          ok: [compute-gpu01]
TASK [確保控制節點的 NFS 分享已掛載]     ok: [compute-gpu01]
PLAY RECAP
compute-gpu01 : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

預演沒有預計變更或差異。
接著不帶 `--check` 正式核對套件、fstab 與掛載。
若實際狀態與預演不同，playbook 仍可能安裝套件、
改寫 fstab 或調整掛載；修改 fstab 時會保留備份。
如有非預期變更，先核對輸出與備份再復原，
不直接卸載使用中的共享目錄。
這些指令不建立新 VM 或雲端資源。

```bash
ansible-playbook nfs-gpu-client.yml
```

```text
PLAY [設定 GPU VM 的 NFS 工作資料掛載]
TASK [Gathering Facts]                    ok: [compute-gpu01]
TASK [確保 NFS 用戶端套件已安裝]          ok: [compute-gpu01]
TASK [確保控制節點的 NFS 分享已掛載]     ok: [compute-gpu01]
PLAY RECAP
compute-gpu01 : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

正式執行沒有修改套件、fstab 或掛載。
以相同命令重跑，核對已符合要求的節點是否仍無變更：

```bash
ansible-playbook nfs-gpu-client.yml
```

```text
PLAY RECAP
compute-gpu01 : ok=3 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

重跑仍沒有變更或失敗。
這證明現有 GPU VM 符合 playbook 且可重跑；
沒有從乾淨節點部署的證據。

## GPU VM 運算端套件

模組 04 的執行路徑是控制節點的 `mpirun` 經 SSH 啟動 GPU VM 上的 MPI 程序；
NFS 讓兩台 VM 讀寫同一份工作檔案。
這已證明 GPU VM 能參與跨節點計算，
但當時沒有由 Slurm 接收工作、選節點或分配 GPU 資源。

要讓 Slurm 管理這台現有的運算節點，
控制節點的 `slurmctld` 需要與 GPU VM 的 `slurmd` 通訊：
前者排程與追蹤工作，後者在 GPU VM 回報狀態並啟動獲分配的工作。
目前的 Slurm 設定使用 MUNGE 驗證兩端身分，
因此 GPU VM 也需要 MUNGE 與控制節點共用的金鑰。
先前由 SSH 啟動的 MPI 工作不需要 GPU VM 上的 `slurmd` 或 MUNGE。

GPU VM 已安裝下列套件；版本由安裝交易與安裝後的 RPM 查詢確認。
套件準備不是本模組的操作重點，安裝過程不逐項保留。

| 套件 | 用途 | 已安裝版本 |
|---|---|---|
| `munge`、`munge-libs` | 產生與驗證跨節點身分憑證 | `0.5.15-11.el10_1.x86_64` |
| `slurm` | 提供 `slurmd` 所需的共用元件 | `26.05.4-1.el10.x86_64` |
| `slurm-slurmd` | 在 GPU VM 接收並啟動 Slurm 分配的工作 | `26.05.4-1.el10.x86_64` |
| `bash-completion` | 安裝交易帶入的相依套件 | `1:2.11-16.el10.noarch` |
| `mariadb-connector-c` | 安裝交易帶入的相依套件 | `3.4.4-2.el10_2.x86_64` |
| `mariadb-connector-c-config` | 安裝交易帶入的相依套件 | `3.4.4-2.el10_2.noarch` |

控制節點的 Slurm 與 MUNGE 版本相同。
GPU VM 的 MUNGE 金鑰與服務已在下節部署；
跨節點 Slurm 設定與 `slurmd` 仍待處理。

## 跨節點 MUNGE 身分驗證

Slurm 的控制端與運算端需要辨認同一叢集的請求。
MUNGE 使用兩台 VM 共用的私密金鑰建立及驗證憑證；
金鑰只留在 VM 的 `/etc/munge/munge.key`，不進專案或輸出。
先確認 GPU VM 是否已有金鑰，避免覆蓋未知內容。

在台灣控制節點的 `/root/hpc-arch/project/ansible` 目錄
以 root 執行下列只讀查詢。
`gpu_compute` 選 GPU VM，`-b` 讓遠端用管理員權限讀取檔案中繼資料；
`get_checksum=false` 不計算或回傳金鑰雜湊值。
結果中的 `exists` 表示檔案是否存在；若存在，再看擁有者和權限。
查詢不回傳金鑰內容，不修改檔案或服務；
可能留下 SSH 登入紀錄與短暫的 Ansible 暫存檔。

```bash
ansible gpu_compute -b -m ansible.builtin.stat -a "path=/etc/munge/munge.key get_checksum=false"
```

```text
compute-gpu01 | SUCCESS => {
    "changed": false,
    "stat": {"exists": false}
}
```

GPU VM 尚無 MUNGE 金鑰；這次查詢沒有變更檔案。
接著在台灣控制節點以 root 只查來源金鑰的
擁有者、群組、權限與檔案大小，不讀取金鑰內容。
預期由 `munge` 擁有、權限為 `600`，且檔案非空。

```bash
stat -c '%U:%G %a %s %n' /etc/munge/munge.key
```

```text
munge:munge 600 128 /etc/munge/munge.key
```

控制節點的來源金鑰存在、非空，且由 `munge` 擁有，
權限只允許擁有者讀寫。

### GPU VM MUNGE 設定 playbook

[munge-gpu.yml](../project/ansible/munge-gpu.yml)
只選 `gpu_compute`。它確保 GPU VM 的 MUNGE 目錄權限正確，
從控制節點複製現有金鑰到 GPU VM，設為 `munge:munge`、`0600`，
並讓服務啟動及開機自動啟動。
金鑰不保存在專案，複製任務隱藏輸出與差異；
日後金鑰真的變更時，handler 會重啟 GPU VM 的 MUNGE。
若需撤回，先停用 GPU VM 的 MUNGE，
確認沒有工作依賴後移除 GPU VM 上複製的金鑰；
控制節點現有金鑰與服務不受這份 playbook 管理。

先在台灣控制節點的 `/root/hpc-arch/project/ansible` 目錄
以 root 執行語法檢查。
這只解析 playbook 與模組名稱，
不連線到 GPU VM、不讀取金鑰內容，也不修改檔案或服務。

```bash
ansible-playbook munge-gpu.yml --syntax-check
```

```text
playbook: munge-gpu.yml
```

Ansible 成功解析 playbook；尚未讀取 GPU VM 狀態或套用設定。

接著在同一目錄以 root 執行預演。
`--check` 預測目錄、金鑰與服務的變更，
不應寫入 GPU VM 或啟動服務；`--diff` 只在任務允許時顯示差異，
金鑰複製任務已禁止顯示內容。
Ansible 仍會透過 SSH 讀取遠端狀態，
可能留下登入紀錄與短暫暫存檔。
預演中的 `changed` 只表示預計變更。

```bash
ansible-playbook munge-gpu.yml --check --diff
```

```text
PLAY [設定 GPU VM 的 MUNGE 身分驗證]
TASK [Gathering Facts]                          ok: [compute-gpu01]
TASK [確保 MUNGE 目錄由服務帳號管理]            ok: [compute-gpu01] (三個目錄)
TASK [部署叢集共用的 MUNGE 金鑰]                changed: [compute-gpu01]
TASK [確保 GPU VM 的 MUNGE 已啟動]              changed: [compute-gpu01]
RUNNING HANDLER [重新啟動 GPU VM 的 MUNGE]      changed: [compute-gpu01]
PLAY RECAP
compute-gpu01 : ok=5 changed=3 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

三個目錄已符合要求；金鑰複製、服務啟動與 handler
各預計變更一次。預演未實際部署金鑰或啟動服務，
且沒有顯示金鑰內容。

### 正式部署 MUNGE

在台灣控制節點的 `/root/hpc-arch/project/ansible` 目錄
以 root 執行下列指令。
Ansible 會透過 SSH 將來源金鑰複製到 GPU VM，
必要時修正目錄與金鑰權限，啟用並啟動 `munge`；
金鑰變更會通知 handler 重啟 GPU VM 的服務。
此指令不管理控制節點的 MUNGE，也不建立新 VM。
若執行失敗或發現非預期變更，先檢查服務與檔案狀態，
再依需要停止 GPU VM 的服務並移除複製的金鑰；
不要將金鑰內容貼到終端輸出或文件。

```bash
ansible-playbook munge-gpu.yml
```

```text
PLAY [設定 GPU VM 的 MUNGE 身分驗證]
TASK [Gathering Facts]                          ok: [compute-gpu01]
TASK [確保 MUNGE 目錄由服務帳號管理]            ok: [compute-gpu01] (三個目錄)
TASK [部署叢集共用的 MUNGE 金鑰]                changed: [compute-gpu01]
TASK [確保 GPU VM 的 MUNGE 已啟動]              changed: [compute-gpu01]
RUNNING HANDLER [重新啟動 GPU VM 的 MUNGE]      changed: [compute-gpu01]
PLAY RECAP
compute-gpu01 : ok=5 changed=3 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

正式執行在 GPU VM 部署金鑰並啟動服務；
三個目錄無須修改，金鑰內容未顯示。
`changed=3` 包含金鑰複製、服務啟動與 handler 重啟，
不能單靠 playbook 成功就宣稱跨節點憑證已驗證。

### 核對金鑰保護

在台灣控制節點的 `/root/hpc-arch/project/ansible` 目錄
以 root 執行下列只讀查詢。
Ansible 在 GPU VM 上回傳檔案中繼資料；
這裡核對是否存在、擁有者、權限和大小。
`get_checksum=false` 不計算雜湊，也不顯示金鑰內容。
預期是 `munge:munge`、`0600` 且檔案非空。

```bash
ansible gpu_compute -b -m ansible.builtin.stat -a "path=/etc/munge/munge.key get_checksum=false"
```

```text
compute-gpu01 | SUCCESS => {
    "changed": false,
    "stat": {
        "exists": true,
        "pw_name": "munge",
        "gr_name": "munge",
        "mode": "0600",
        "size": 128
    }
}
```

GPU VM 的金鑰檔存在且非空，擁有者與權限符合設定；
查詢未顯示金鑰內容。下一步確認服務實際在運行。

在同一控制節點目錄以 root 執行下列只讀查詢。
Ansible 在 GPU VM 上用 `systemctl show` 讀取 MUNGE 的
`ActiveState`（目前是否運行）與 `UnitFileState`（是否設為開機啟動）。
預期為 `active` 與 `enabled`；它不啟動或重啟服務。

```bash
ansible gpu_compute -m ansible.builtin.command -a "systemctl show munge -p ActiveState -p UnitFileState"
```

```text
compute-gpu01 | CHANGED | rc=0 >>
ActiveState=active
UnitFileState=enabled
```

GPU VM 的 MUNGE 正在運行，且已設定開機自動啟動。
`CHANGED` 是 `ansible.builtin.command` 的預設標記；
這條 `systemctl show` 只讀取狀態，沒有更動服務。

### 控制節點產生、GPU VM 驗證 MUNGE 憑證

在台灣控制節點以 root 執行下列單行指令。
左半段以 `a2264` 身分呼叫本機 `munge -n` 產生短效憑證；
管線把憑證直接交給右半段的 SSH 標準輸入，
以既有私鑰登入 GPU VM，讓 GPU VM 的 `unmunge` 解碼。
`-i` 指定既有 SSH 私鑰，`IdentitiesOnly=yes` 限定使用該金鑰，
`BatchMode=yes` 避免互動詢問，`ConnectTimeout=5` 限制連線等待。
預期看到 `STATUS: Success` 和控制節點的編碼主機；
憑證與私鑰內容都不寫入專案或終端輸出。
這只驗證兩台 VM 的 MUNGE 通路，不提交 Slurm 工作，
也不修改兩台 VM 的設定。

```bash
sudo -u a2264 -- munge -n | sudo -u a2264 -- ssh -i /home/a2264/.ssh/hpc_gpu_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5 a2264@10.146.0.3 unmunge
```

```text
STATUS:          Success (0)
ENCODE_HOST:     instance-20260923-104239.asia-east1-b.c.project-78b8a95c-a2c0-461f-a08.internal (10.140.0.2)
UID:             a2264 (1000)
GID:             a2264 (1005)
```

GPU VM 成功解碼控制節點產生的短效憑證；
這是跨 VM 的 MUNGE 驗證，不是 Slurm 工作或排程結果。

### 重跑 MUNGE playbook

在台灣控制節點的 `/root/hpc-arch/project/ansible` 目錄
以 root 再執行同一份 playbook。
Ansible 會重新核對 GPU VM 的目錄、金鑰與服務；
若狀態未變，預期 `changed=0`，金鑰複製任務為 `ok`，
handler 不會重啟 MUNGE。
若期間狀態已改變，正式執行仍可能修正權限、複製金鑰
或啟動服務；不建立新 VM。

```bash
ansible-playbook munge-gpu.yml
```

```text
PLAY [設定 GPU VM 的 MUNGE 身分驗證]
TASK [Gathering Facts]                          ok: [compute-gpu01]
TASK [確保 MUNGE 目錄由服務帳號管理]            ok: [compute-gpu01] (三個目錄)
TASK [部署叢集共用的 MUNGE 金鑰]                ok: [compute-gpu01]
TASK [確保 GPU VM 的 MUNGE 已啟動]              ok: [compute-gpu01]
PLAY RECAP
compute-gpu01 : ok=4 changed=0 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0
```

重跑沒有複製金鑰、變更服務或觸發 handler；
GPU VM 的 MUNGE 設定可重跑。

## GPU VM 的 Slurm 資源探測

GPU VM 已透過 SSH 執行過 MPI rank，但尚未交由 Slurm 排程。
設定 Slurm 節點前，需要先知道它實際回報多少 CPU、記憶體和 GPU。
Slurm 原本就用 CPU 數與記憶體容量決定節點能否接工作；
**GRES**（Generic RESources，通用資源）是它計數 GPU 等額外資源的方式。
在這台 VM，`gpu:nvidia_l4:1` 的意思是「L4 類型的 GPU 一張」。
實體 GPU 由驅動辨認；Slurm 還需要在節點設定中宣告可分配的數量，
並用 `gres.conf` 對應到運算節點偵測的裝置。
例如工作用 `--gres=gpu:1` 請求一張 GPU 時，
排程器才會把這項資源列入分配；本模組尚未執行這種工作。
`slurmd -C` 只探測可作為設定依據的硬體，
不會替排程器完成 GPU 宣告或工作分配。

在 GPU VM `compute-gpu01` 上以 `a2264` 執行 `slurmd -C`；
`-C` 只列出偵測到的硬體資訊後退出，
不啟動 `slurmd` 服務、不註冊節點，也不修改設定。

```bash
slurmd -C
```

```text
NodeName=compute-gpu01 CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=2 ThreadsPerCore=2 RealMemory=15983 Gres=gpu:nvidia_l4:1
Found gpu:nvidia_l4:1 with Autodetect=nvidia (Substring of gpu name may be used instead)
UpTime=0-04:16:42
```

`CPUs=4` 是 2 個核心、每核心 2 個執行緒呈現的 4 個邏輯 CPU；
`RealMemory=15983` 是偵測到的 MiB 數，不應全數分給工作。
`Gres=gpu:nvidia_l4:1` 與下一行表示偵測到一張 NVIDIA L4；
這可作節點設定的輸入，仍須在 `slurm.conf` 宣告預期 GPU 數量、
核對 `gres.conf`，並實際驗證 Slurm 工作，
才能說 GPU 已由 Slurm 管理。
[Slurm 的 `slurmd -C` 與 GRES 說明](https://slurm.schedmd.com/gres.html)

## 控制節點排程狀態確認

GPU VM 先前已透過 SSH 執行 MPI；下一步要讓控制節點的 Slurm
把工作排到這台 VM。修改控制節點 Slurm 設定前，
先確認目前沒有正在執行或等待的工作，避免變更影響現有任務。
在台灣控制節點以 root 執行下列只讀查詢。
`squeue` 向現有 `slurmctld` 讀取工作佇列；
`-h` 不顯示標題，`-o` 依序列出工作 ID、狀態、使用者與名稱。
若沒有工作，命令會成功且沒有輸出；若有工作，
需先看狀態再決定能否改設定。
這不提交、取消工作，也不修改服務或 VM。

```bash
squeue -h -o '%i %T %u %j'
```

**結果：** 命令沒有輸出，直接返回提示字元；目前佇列沒有工作。

## 兩節點 Slurm 設定：已準備，尚未套用

現有 Slurm 只管理控制節點；GPU VM 雖已執行過 SSH 啟動的 MPI 工作，
還沒有接受 Slurm 排程。[two-node-slurm.conf](../project/slurm/two-node-slurm.conf)
保留控制節點原本的 `debug` 分區，另設只包含 GPU VM 的 `gpu` 分區。
GPU VM 的 CPU 拓撲依 `slurmd -C` 實測；
記憶體宣告 14,000 MiB，低於偵測值 15,983 MiB，
保留約 2 GiB 給作業系統與服務。
它向 Slurm 宣告一張 L4；[gpu-gres.conf](../project/slurm/gpu-gres.conf)
指定 GPU VM 的 Slurm 使用 `nvidia` 方式讀取本機裝置資訊。
這不是讓作業系統首次看見 GPU：部署此檔前，`slurmd -C`
就已在 GPU VM 找到一張 L4。若不指定 `AutoDetect=nvidia`，
也不能直接推論 Slurm 找不到 GPU；Slurm 可用其他偵測方式，
或在 `gres.conf` 明列裝置。本設定明確選用已探測可用的方式，
再由 `slurmd -G` 核對它和排程宣告是否一致。
各設定項目的用途直接寫在檔案的中文註解中。

[slurm-two-node.yml](../project/ansible/slurm-two-node.yml)
這裡有兩種位置：`project/slurm/` 是控制節點工作樹中的**來源檔**，
`/etc/slurm/` 是各 VM 上 Slurm 服務讀取設定的**部署位置**。
兩台 VM 可以有相同的 `/etc/slurm/slurm.conf` 路徑，
但它們各自磁碟上的檔案互不相同。

| 機器 | 目前已知的檔案與來源 |
|---|---|
| 控制節點 | [模組 01 的實際命令](module-01.md#slurm-設定與啟動) 已用 `install -D` 把工作樹中的 `project/slurm/single-node-slurm.conf` 複製到**控制節點自己的** `/etc/slurm/slurm.conf`；`-D` 也會建立缺少的父目錄。當時 `stat` 與 `cmp` 已驗證檔案存在且內容一致。 |
| GPU VM | `/etc/slurm` 是否已由套件建立尚未核對；兩節點 `slurm.conf` 與 `gres.conf` 尚未部署。Playbook 會先建立或核對目錄，再複製設定。 |

`project/slurm/two-node-slurm.conf` 是接下來要部署的**新版來源檔**，
不是控制節點正在使用的 `/etc/slurm/slurm.conf`。
**目前兩台 VM 都尚未收到這份兩節點設定。**
在控制節點的 `project/ansible` 目錄正式執行
`ansible-playbook slurm-two-node.yml` 時，playbook 才會按下列順序操作：

1. 在 GPU VM 建立或核對 `/etc/slurm` 目錄。
   目前沒有核對它是否已由套件建立；若不存在，這一步才會建立。
2. 從控制節點工作樹複製 `../slurm/two-node-slurm.conf`
   到 GPU VM 的 `/etc/slurm/slurm.conf`；
   再複製 `../slurm/gpu-gres.conf` 到 GPU VM 的 `/etc/slurm/gres.conf`。
   前者宣告這台節點可供排程一張 `nvidia_l4`，
   後者的 `AutoDetect=nvidia` 指定 GPU VM 上的 Slurm
   使用哪種方式讀取本機 NVIDIA GPU；它不是 GPU 驅動或硬體的開關。
3. **在 GPU VM 執行 `slurmd -G`。**
   `slurmd` 是運算節點接收工作的程式；`-G` 讓它讀取剛複製的
   `slurm.conf` 與 `gres.conf`，印出兩份設定合併後的 GPU 資源結果就退出。
   這是設定檢查，不會啟動常駐服務或執行 GPU 工作。
   playbook 要求指令成功、輸出包含 `nvidia_l4` 且沒有 `error:`；
   否則停止，不更新控制節點。
4. GPU 檢查通過後，才把同一份 `two-node-slurm.conf` 複製到控制節點
   **已在模組 01 建立**的 `/etc/slurm/slurm.conf`，取代原本的單節點內容；
   接著以 `scontrol reconfigure`
   請現有控制服務重新讀取設定。兩台各有自己的檔案；
   「共用設定」只表示內容相同，沒有共享磁碟檔案。
5. 最後啟動或重啟 GPU VM 的 `slurmd`，讓它依新設定向控制節點註冊。
   是否真的能由 Slurm 執行 GPU 工作，仍須用實際工作驗證。

下方已執行的 `--syntax-check` 只檢查 playbook 語法；
預計執行的 `--check --diff` 只預演差異。
兩者都不複製檔案，也不執行 GPU VM 上的 `slurmd -G`。
若 VM 原本已有設定檔且內容被改動，`copy` 會在該 VM 留下舊版備份。
這份 playbook 不建立新 VM、不安裝套件，也不管理 MUNGE 金鑰。

在台灣控制節點的 `project/ansible` 目錄，以 root 檢查 playbook 語法；
這只解析本機檔案，不連線或修改 VM。

```bash
ansible-playbook slurm-two-node.yml --syntax-check
```

```text
playbook: slurm-two-node.yml
```

語法檢查通過；GPU 裝置對應與兩台服務的實際狀態仍須在套用時確認。

**下一步預計執行，尚未實測：** 在台灣控制節點的 `project/ansible`
目錄以 root 預演兩台 VM 的設定差異。
`--check` 只預估支援預演的任務會如何變更，`--diff` 顯示設定檔差異；
不會修改遠端設定或啟動服務。
預演不會實際執行 `slurmd -G`，因此也不能把預演成功當成 GPU 對應完成。

```bash
ansible-playbook slurm-two-node.yml --check --diff
```

**尚未套用。** 正式執行會修改兩台 VM 的 `/etc/slurm/slurm.conf`、
GPU VM 的 `/etc/slurm/gres.conf` 與 `slurmd` 服務狀態，
並讓控制節點 Slurm 重新讀取設定；可能短暫影響排程。
若套用失敗，先依實際任務輸出定位，
必要時停止 GPU VM 的 `slurmd`、從備份還原兩台設定，
再讓控制節點重新讀取原設定。

## 尚需交付的能力證據

- 在乾淨節點核對 NFS 掛載 playbook 的首次變更與重跑結果，
  並依實際變更確認復原方式。
- 在乾淨環境重建必要帳號、MUNGE、共享路徑與 Slurm 設定，
  並在 `project/docs/` 留下實際重建步驟、版本及人工前置條件。
- 由 Slurm 執行具代表性輸入的 CPU 與 GPU 工作，
  GPU 節點須先確認驅動版本及 Slurm GRES 設定，
  核對主機、`CUDA_VISIBLE_DEVICES`、結果與 GPU 使用情況；
  單卡結果不能宣稱多卡隔離。
- 以可恢復的服務或連線故障驗證排障與復原。
- 對照現有 GCP VM 供給與 OpenStack 的 VM、網路、映像和身分管理；
  若有可用平台，須實際建立、連線及刪除 VM 才算操作證據；
  否則只保留分析，不寫成 OpenStack 實作。
