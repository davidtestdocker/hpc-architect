# 現有四節點 Slurm 叢集操作與復原

這份手冊供從 GCP 控制節點 `instance-20260923-104239` 管理
現有教學叢集時使用。它把設定來源、服務變更及結果證據接起來；
完整實測命令與輸出在[模組 05](../../curriculum/module-05.md)及
[模組 06](../../curriculum/module-06.md)。
本文的 VM 名稱和位址屬於這套環境，不能直接套用到新建叢集。

## 操作前先辨認位置

[拓撲](cluster-topology.md)列出控制節點、GPU VM、兩台 CPU VM
及承載 DevStack 的 `openstack-lab01`。從控制節點工作樹執行 Ansible；
[inventory](../ansible/inventory/hosts.yml)把主機名稱對應至各 VM 的
位址、帳號和 SSH 路徑。OpenStack CPU 客體的管理 SSH 經宿主機
網路命名空間代理；Slurm TCP `6818` 則走宿主機轉送與浮動 IP。

| 工作樹來源 | 實際目標與讀取者 | 使用前提 |
|---|---|---|
| [四節點 Slurm 設定](../slurm/four-node-slurm.conf) | [playbook](../ansible/slurm-four-node.yml)複製到控制節點、GPU VM、兩台 CPU VM 各自的 `/etc/slurm/slurm.conf`；`slurmctld`、`slurmd` 各讀自己的檔案 | 節點名稱、位址、CPU／記憶體與 GRES 須對得上現有 VM；playbook 先拒絕非空佇列 |
| [GPU GRES 設定](../slurm/gpu-gres.conf) | [兩節點部署 playbook](../ansible/slurm-two-node.yml)曾複製到 GPU VM 自己的 `/etc/slurm/gres.conf`；GPU VM 的 `slurmd` 讀取 | L4 與 `/dev/nvidia0` 的對應已有模組 05 實測；四節點 playbook 不更新此檔 |
| [NFS 匯出](../nfs/hpc-share.exports) | [控制端 playbook](../ansible/nfs-controller.yml)複製到控制節點自己的 `/etc/exports.d/hpc-share.exports`；NFS 伺服器讀取 | 匯出只允許 GPU VM `10.146.0.3`；[GPU 掛載 playbook](../ansible/nfs-gpu-client.yml)寫入 GPU VM 的掛載設定 |
| 控制節點現有 `/etc/munge/munge.key` | [GPU](../ansible/munge-gpu.yml)與 [CPU](../ansible/munge-cpu.yml) playbook 經 SSH 複製到運算節點各自的同名路徑；`munged` 讀取 | 金鑰不在工作樹，不把內容輸出到終端；新控制節點必須先安全建立並分發金鑰 |

Ansible 設定變更後，[四節點 playbook](../ansible/slurm-four-node.yml)
會在運算端核對 `slurmd -G`，然後使控制端重讀設定；
只有運算端設定檔真的變更時才重啟其 `slurmd`。
這會短暫影響該節點接工作，因此正式執行前先按
[模組 06 的部署紀錄](../../curriculum/module-06.md)核對佇列、
目標節點和預期變更。`--syntax-check` 與 `--check` 只作解析或預演，
不能當成已完成部署。

**現有四節點叢集的設定更新只使用四節點設定來源。**
[兩節點](../ansible/slurm-two-node.yml)、
[三節點 CPU](../ansible/slurm-cpu-node.yml)與
[GPU 重新加入](../ansible/slurm-gpu-rejoin.yml) playbook
是先前擴充時的紀錄，分別會複製兩節點或三節點設定；
直接在目前四節點叢集執行，會把較新的節點宣告覆蓋掉。
同樣地，`cpu_compute` 群組目前含兩台 CPU VM，
重新執行[CPU 套件](../ansible/slurm-cpu-packages.yml)、
[身分](../ansible/slurm-cpu-identity.yml)或
[MUNGE](../ansible/munge-cpu.yml) playbook 時會選到兩台，
須先確認目標與影響。

## 開機後的網路與節點恢復

`openstack-lab01` 重開後，宿主機 `br-ex` 位址與轉送規則可能需要恢復。
先核對宿主機仍為 `10.146.0.4`、DevStack 客體實際開機，
浮動 IP `172.24.4.121` 仍關聯 `compute-cpu01` 的 `10.0.0.32`；
再按[模組 05 的已實測流程](../../curriculum/module-05.md)
執行[網路恢復腳本](../openstack/restore-module05-network.sh)。
腳本成功只代表宿主機規則已就緒，後續仍需分別核對管理 SSH、
Slurm 節點狀態和 CPU 工作結果。客體曾因開機掛載等待進入
emergency mode；Nova 顯示 `ACTIVE` 不能代替客體已正常開機的證據。

GPU VM 開機後若仍被 Slurm 列為 `DOWN`，先核對 VM、`slurmd`、
節點實際讀取的設定與 GRES 對應。模組 05 曾在確認原因是
`Node unexpectedly rebooted` 後才執行人工 `RESUME`；
該次結果不表示往後每個 `DOWN` 都應直接 `RESUME`。
[模組 06](../../curriculum/module-06.md)已部署 `ReturnToService=1`，
`compute-cpu02` 因失聯而 `down*` 後重新註冊曾自動回到 `idle`。

## 故障時按通路定位

1. **工作不能排入節點：** 先從控制節點看佇列、分區、節點狀態及
   Slurm 給的原因。`idle` 只表示控制端願意分配工作，
   工作是否成功仍看節點與程式輸出。
2. **OpenStack CPU 客體無法接工作：** 分開核對控制端到宿主機
   TCP `6818` 的轉送、客體到控制端 TCP `6817` 的回程，
   以及 MUNGE／`slurmd`。SSH 能登入客體只證明管理通路，
   不能證明這兩條 Slurm 服務通路。
3. **共享檔案或 GPU 工作失敗：** 在 GPU VM 核對 NFS 掛載、
   Slurm GRES 與實體 L4 的對應；[模組 05](../../curriculum/module-05.md)
   保存 `slurmd -G` 與熱擴散工作實測。
4. **監控告警：** 以 Zabbix 事件對照節點的服務及 Slurm 狀態，
   依[模組 06](../../curriculum/module-06.md)的故障與復原順序判讀；
   單看告警解除或服務 `active` 不代表工作已恢復。

## 可核對的工作結果

| 路徑 | 已保存的判讀依據 |
|---|---|
| 控制節點與 GPU VM 的共享資料及 CPU MPI | [模組 04](../../curriculum/module-04.md)：兩台 VM 各一個 rank，部分總和 `15+40=55` |
| Slurm 分配 L4 工作 | [模組 05](../../curriculum/module-05.md)：`host=compute-gpu01`、`device=NVIDIA L4`、`validation=PASS` |
| 兩台 CPU VM 的工作與故障轉移 | [模組 06](../../curriculum/module-06.md)：相同資源請求在兩台節點得到同一答案；`compute-cpu02` 故障時新工作落到 `compute-cpu01.novalocal` 並回報 `PASS` |

這些是已完成的實測證據，讀取本手冊不會重新執行工作。
現有 playbook 從已建立且可連線的 VM 開始；VM 供給、控制節點初始安裝、
GPU 驅動與 Zabbix 網頁設定並非單一 playbook 可從零完成的範圍。
