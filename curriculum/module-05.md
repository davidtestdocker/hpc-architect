# 模組 05：HPC 叢集建置與管理自動化

[能力路線](ROADMAP.md)｜職缺核心：叢集建置與管理自動化。

## 這個模組在做什麼

目前兩台 VM 的 NFS 資料路徑已由人工建好。
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
