# 模組 05：HPC 叢集建置與管理自動化

[能力路線](ROADMAP.md)｜職缺核心：叢集建置與管理自動化。

## 這個模組在做什麼

把已確認可用的人工建置步驟寫成可重跑的部署程式，
讓新節點能依角色取得一致的帳號、設定、服務與驗證方式。
重點是從乾淨環境建起來，且重跑不造成無意義的變更。
同時分清楚現有 GCP VM 供給流程與 OpenStack 提供 VM 的角色，
避免把作業系統內的設定自動化誤當成雲端資源管理。

## 目前狀態

**控制節點 NFS playbook 已正式執行，沒有產生變更。** 台灣控制節點已從 AlmaLinux
AppStream 安裝 `ansible-core-1:2.16.16-2.el10_2.1.noarch`；
套件交易回報 `Complete!`，並安裝所需的 Python 相依套件。
inventory 已列出現有兩台 VM，Ansible 已成功連到 GPU VM；
第一份 NFS playbook 已通過語法檢查、預演及正式執行；
正式執行回報 `ok=5`、`changed=0`、`failed=0`。
控制節點也已安裝 `ansible.posix:2.2.2`，供後續管理 GPU VM 的 NFS 掛載。
[GPU VM 掛載 playbook](../project/ansible/nfs-gpu-client.yml) 已建立，尚未套用。

## 要解決的問題

目前的單節點 Slurm 設定和未來的 GPU 節點若靠人工逐台配置，
新建一台 VM 時容易漏掉帳號、金鑰、共享路徑或服務順序。
本模組用 Ansible 把**已驗證的人工步驟**變成可重跑的部署。

### Ansible 是什麼，會在哪裡使用

模組 04 曾從台灣控制節點用 SSH 登入東京 GPU VM，遠端執行一條命令。
若新建多台節點，再逐台手動安裝套件、放設定檔、啟動服務，
很容易漏步驟，之後也難確認每台是否一致。

**Ansible 是把這些主機設定步驟寫成可重跑規則的工具。**
這次預計在台灣控制節點執行 Ansible，由它透過既有的 SSH 連線
設定目標 VM。先把要管理的主機及角色寫進 **inventory**，
再把希望各主機具備的帳號、套件、檔案與服務狀態寫進 **playbook**。
例如 GPU VM 應有指定版本的驅動與 `slurmd` 設定；實際套用前
會先核對現況，不把尚未部署的範例寫成成果。

執行時要看每台主機的 `ok`、`changed`、`failed`、`unreachable`：
`changed` 表示有狀態被改動；`failed` 是執行失敗，
`unreachable` 表示連不到目標。第二次用相同設定執行時，
若沒有新變更，應盡量沒有 `changed`，也不該無故重啟服務。
這是要實測的性質，不因使用 Ansible 就自動成立。

**Ansible 負責主機內的設定，Slurm 負責排工作。**
安裝 `ansible-core` 只是在控制節點取得工具，本身不會配置 GPU VM、
建立雲端 VM 或啟動 Slurm 工作；要明確執行 playbook 才會嘗試改動目標。
[Ansible 的 playbook 與執行結果說明](https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_intro.html)

| 概念 | 在這個叢集的作用 |
|---|---|
| inventory | 記錄哪些 VM 是控制、CPU 運算或 GPU 運算節點，以及連線所需的非敏感變數 |
| playbook | 描述帳號、套件、設定檔與服務應有的狀態 |
| template | 依節點角色與變數產生各自的設定檔 |
| handler | 設定真的改變時才重啟受影響的服務 |
| role | 把同一用途的設定整理在一起，供不同節點重用 |
| 冪等 | 同樣的輸入重跑時，不產生未預期變更或不必要的服務重啟 |

例如，第二次部署若設定沒有改，`slurmd` 卻每次重啟，
就要查是哪個步驟誤判為「有變更」，不能只看命令成功退出。

## 指令用途

下表說明本模組已使用的工具和仍未使用的 `--diff`。

| 工具 | 要看什麼 | 限制 |
|---|---|---|
| `ansible-inventory` | 節點分組和套用的變數 | 分組正確不代表部署成功 |
| `ansible-playbook --check` | 在可支援的步驟預演變更 | 預演不能代替實際部署 |
| `ansible-playbook` | 套用設定，再看失敗節點和變更數 | 退出碼為零仍須驗證工作功能 |
| `--diff` | 比較設定檔變化 | 可能顯示敏感設定，使用前先確認輸出範圍 |

其餘實際命令、版本、目標主機和檔案路徑等環境確認後再記錄。

## 第一個成果：列出已確認的節點角色

[inventory](../project/ansible/inventory/hosts.yml) 目前只列已存在的
台灣控制節點與東京 GPU VM。控制節點標為 `controller`，
因為 Ansible 從該處執行，所以使用本機連線；GPU VM 標為
`gpu_compute`，使用私有 IP `10.146.0.3`、帳號 `a2264`
及控制節點已存在的專用私鑰路徑。清單只保存**私鑰路徑**，
不保存私鑰內容；尚未建立的 CPU 運算節點不會被虛構進清單。
建立這個檔案只改動專案目錄，沒有連線或修改 VM。

`ansible-inventory` 是 Ansible 用來讀取與顯示節點清單的命令。
先從台灣控制節點以 `root` 執行下列唯讀檢查，確認分組與主機名
被正確讀入。`-i` 指向清單檔，`--graph` 把群組和成員列成樹狀；
它不會 SSH 登入目標，也不會套用設定或改動檔案、服務。
預期看到 `controller` 下有 `instance-20260923-104239`，
`gpu_compute` 下有 `compute-gpu01`；這只驗證清單語法與分組，
還不能證明目標 VM 目前可連線。

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

`controller` 與 `gpu_compute` 各有預期的一台 VM；
`ungrouped` 沒有成員。清單已能被 Ansible 解析，
但這一步沒有測試 SSH 或遠端執行。

### 用 Ansible 確認 GPU 節點可管理

這裡的 `ansible.builtin.ping` **不是**前面使用的 ICMP `ping`。
它讓控制節點依 inventory 透過 SSH 連到 GPU VM，
以 `a2264` 執行一個很小的 Ansible 模組，再回傳 `pong`。
成功會證明清單中的位址、帳號、金鑰和遠端 Python 執行通路可用；
不代表部署設定或 GPU 工作已成功。

在台灣控制節點的 `root` shell 執行。`-i` 指定剛驗證的清單，
`gpu_compute` 只選東京 GPU VM，`-m` 指定這個測試模組。
它不改服務或雲端資源；SSH 會留下登入紀錄，
Ansible 可能短暫建立並清理遠端模組暫存檔。

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

`gpu_compute` 群組選中 `compute-gpu01`。Ansible 從控制節點讀取
inventory 中的 `ansible_host=10.146.0.3`、`ansible_user=a2264`
與 `ansible_ssh_private_key_file`；該私鑰已在模組 04 建立，
對應公鑰也已加入 GPU VM 的 SSH 登入設定，不是這次新建立的金鑰。
`SUCCESS` 與 `pong` 證明 Ansible 已透過這條連線在 GPU VM 執行模組；
`discovered_interpreter_python` 表示找到遠端 Python，
`changed: false` 表示這次沒有改動受管設定。

## 第一份部署程式：控制節點的 NFS 分享

[nfs-controller.yml](../project/ansible/nfs-controller.yml) 是第一份
**playbook**：寫出控制節點應有的狀態，而不是逐台手敲命令。
它只選 inventory 的 `controller` 群組，確保 `nfs-utils` 已安裝、
`/srv/hpc-share` 屬於 `a2264` 且權限為 `0750`、
匯出檔與 [既有設定來源](../project/nfs/hpc-share.exports) 一致，
並讓 `nfs-server` 保持啟動與開機自動啟動。
匯出檔真的變更時才由 **handler** 執行 `exportfs -ra` 更新分享清單；
各參數與副作用寫在 playbook 的中文註解中。

這份 playbook 目前只處理 NFS 伺服器，不能單獨建成整個叢集；
它假設控制節點已有 `a2264` 帳號，尚未處理 GPU VM 的掛載。
實際套用時若狀態不符，可能安裝套件、改動目錄或
`/etc/exports.d/`、啟動服務並更新 NFS 匯出；
本次執行沒有產生變更。

先在台灣控制節點以 `root` 執行 **`--syntax-check`**。
`-i` 指向已驗證的 inventory；命令只檢查 playbook 能否解析，
不 SSH 到 GPU VM，也不修改檔案或服務。成功時會列出 playbook 路徑；
這只能證明語法可讀，不能代替預演或實際部署。

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-controller.yml --syntax-check
```

```text
playbook: /root/hpc-arch/project/ansible/nfs-controller.yml
```

Ansible 成功解析這份 playbook；這次沒有套用 NFS 設定，
也還不知道目前控制節點是否需要變更。

### 預演控制節點會發生的變更

接著在台灣控制節點以 `root` 執行下列指令。
它沿用同一份 inventory 和 playbook，`--check` 要求 Ansible
盡可能只預演任務，列出會維持原狀、預計變更或失敗的項目；
目標只有 inventory 中的 `controller`，不配置 GPU VM。
預演仍會讀取控制節點狀態並可能留下 Ansible 暫存或操作紀錄，
但不應安裝套件、改寫 NFS 匯出檔或重啟服務。
看各任務的 `ok`、`changed`、`failed` 和最後的 recap；
`changed` 是預計變更，不是已經部署成功。
預演無法證明 NFS 分享已更新或 GPU VM 能掛載。

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

五項檢查都符合預期，沒有預計變更，也沒有連線或任務失敗。
這表示目前控制節點狀態與 playbook 一致；
`--check` 沒有實際部署，仍須正式套用與檢查結果。

### 正式套用現有 NFS 設定

在台灣控制節點以 `root` 執行下列指令，目標只限 inventory 的
`controller`，不配置 GPU VM 或建立雲端資源。
這次拿掉 `--check`，Ansible 會實際確保 `nfs-utils`、
`/srv/hpc-share`、`/etc/exports.d/hpc-share.exports` 和
`nfs-server` 符合 playbook；若匯出檔變動，handler 會執行
`exportfs -ra`。剛才預演為 `changed=0`，因此預期正式套用也不需改動；
若執行時環境已變，仍可能安裝套件、改動檔案或啟動服務。
復原時須依實際 `changed` 項目處理：匯出設定可恢復原檔後執行
`exportfs -ra`，目錄權限與服務狀態則恢復成執行前的值。

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

正式執行時，套件、目錄、匯出檔與服務都已符合指定狀態，
所以 Ansible 沒有安裝、複製、修改或重新載入 NFS 匯出。
`changed=0` 是這次正式套用沒有變更的證據。
模組 04 已驗證 GPU VM 的掛載與雙向讀寫；本次控制節點沒有
設定變更，不重複執行相同的掛載檢查。

### GPU VM 掛載自動化的準備

控制節點已從 Ansible Galaxy 安裝 `ansible.posix:2.2.2`；
安裝回報 `ansible.posix:2.2.2 was installed successfully`。
這個 collection 提供 `ansible.posix.mount` 模組，
可管理 GPU VM 的掛載設定與目前掛載狀態。
安裝只增加控制節點的 Ansible 模組，沒有修改 GPU VM 或 NFS 服務；
GPU VM 的掛載 playbook 尚未套用。

[collection 需求檔](../project/ansible/requirements.yml) 固定已安裝的
`ansible.posix:2.2.2`，供重建控制節點的 Ansible 環境時使用。
[GPU VM 掛載 playbook](../project/ansible/nfs-gpu-client.yml) 只選
inventory 的 `gpu_compute` 群組，先確保 `nfs-utils` 已安裝，
再把控制節點 `10.140.0.2:/srv/hpc-share` 設成 GPU VM 的
`/srv/hpc-share` 掛載來源。
`ansible.posix.mount` 的 `state: mounted` 同時確保目前掛載與
`/etc/fstab` 的開機設定；`vers=4.2` 沿用模組 04 已驗證的協定版本。
修改 fstab 時，`backup: true` 會保留修改前的備份。
`_netdev` 告知系統此掛載依賴網路，`nofail` 避免分享不可達時
阻斷開機；它們不保證伺服器故障時工作仍能讀取資料。
各欄位的具體作用也寫在 playbook 的中文註解中。

這份 playbook 目前只存在於專案檔案，沒有連到或修改 GPU VM。
正式套用可能安裝套件、寫入 GPU VM 的 `/etc/fstab` 並掛載共享目錄；
若要撤回開機掛載設定，可參考修改前的 fstab 備份並移除該 NFS 項目；
若也要停止目前掛載，再卸載 `/srv/hpc-share`，但應先確認沒有工作使用它。

先在台灣控制節點以 `root` 執行語法檢查。
`-i` 指向目前 inventory，playbook 路徑指定新檔案；
`--syntax-check` 只檢查 Ansible 是否能解析檔案及找到所需模組，
不 SSH 到 GPU VM，也不改動掛載或服務。
預期成功時列出 playbook 路徑；這不代表預演或部署成功。

```bash
ansible-playbook -i /root/hpc-arch/project/ansible/inventory/hosts.yml /root/hpc-arch/project/ansible/nfs-gpu-client.yml --syntax-check
```

## 實作與過關證據

1. 將已驗證的控制／運算節點角色、服務帳號、MUNGE 驗證、共享路徑及 Slurm 設定轉為部署程式。
2. GPU 節點只套用已確認相容的驅動版本；設定 Slurm GRES，讓工作明確請求一張 GPU。
3. 從乾淨實驗 VM 部署，記錄版本、人工前置條件與預期服務重啟。
4. 由 Slurm 執行 CPU 與 GPU 工作，核對執行主機、`CUDA_VISIBLE_DEVICES`、計算答案與 GPU 使用情況。
5. 重跑部署，逐項解釋非預期變更；再用可恢復的服務或連線故障驗證復原。
6. 對照現有 GCP VM 供給與 OpenStack 的 VM、網路、映像及身分管理，
   說明哪些步驟屬於雲端資源供給、哪些屬於 Ansible 的主機設定。
   若有可用 OpenStack 平台，先確認成本與清除方式，再以實際建立、連線及刪除 VM 驗證；
   沒有平台時保留對照分析，明確標示尚無 OpenStack 操作證據。

預期交付在 `project/ansible/` 的部署程式、非敏感 inventory 範例與版本要求，
以及 `project/docs/` 的實際重建步驟。
過關要有乾淨環境重建、CPU／GPU 工作結果、重跑與復原證據，
以及 OpenStack 與現有供給流程的具體對照；
單張 GPU 只能驗證單卡分配，不能宣稱多卡隔離或卡間通訊。

開始實作前，先確認目標 VM 沒有重要工作，再在本文件寫下確定要執行的命令、
作用的主機與檔案、服務影響及復原方式；執行後只記必要結果。
