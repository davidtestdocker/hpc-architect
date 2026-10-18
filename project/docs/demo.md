# 十分鐘作品展示提綱

這份提綱用已保存的設定與實測結果展示四節點 HPC 叢集，
依序開啟本工作樹中的文件、原始碼與結果證據；
文件中的實測結果不依賴 VM 當下在線。

| 預定時間 | 開啟的證據 | 要說清楚的事 |
|---|---|---|
| 0–1 分鐘：問題與範圍 | [拓撲](cluster-topology.md) | 用控制節點、GPU VM、兩台獨立 CPU VM 和 OpenStack 宿主機交代角色；控制端兼任 CPU 與 NFS，說明成本與單點取捨。 |
| 1–3 分鐘：網路 | [模組 04](../../curriculum/module-04.md)、[模組 05](../../curriculum/module-05.md)、[網路恢復腳本](../openstack/restore-module05-network.sh) | 私有網路與 NFS 如何連 GPU VM；OpenStack CPU 客體的 SSH 管理通路和 Slurm TCP `6817`／`6818` 如何分開，SNAT／DNAT 解決哪個方向的回程。 |
| 3–5 分鐘：自動化 | [inventory](../ansible/inventory/hosts.yml)、[四節點設定](../slurm/four-node-slurm.conf)、[playbook](../ansible/slurm-four-node.yml) | Ansible 從控制節點把設定放到四台各自的 `/etc/slurm/slurm.conf`；先拒絕非空佇列、檢查運算端，再重載控制端並只在變更時重啟運算服務。自動化範圍是既有節點的服務設定。 |
| 5–7 分鐘：工作結果 | [模組 04](../../curriculum/module-04.md)、[模組 05](../../curriculum/module-05.md)、[模組 06](../../curriculum/module-06.md) | 跨 VM MPI 是兩台各一個 CPU rank，答案 `15+40=55`；L4 熱擴散有裝置名稱與 `validation=PASS`；兩台獨立 CPU VM 用相同資源請求完成同一份熱擴散工作。 |
| 7–9 分鐘：故障處理 | [模組 06](../../curriculum/module-06.md)、[操作與復原流程](operations.md) | 停止 `compute-cpu02` 的 `slurmd` 後，Zabbix 告警、Slurm 將節點隔離，新工作落到 `compute-cpu01` 並得到正確答案；`ReturnToService=1` 後節點曾回到 `idle`。區分監控恢復、節點可排程與工作真正成功。 |
| 9–10 分鐘：取捨與邊界 | [模組 07](../../curriculum/module-07.md) | 說明單張 L4、單一控制端及一台 OpenStack CPU 客體的設計取捨，並回到已驗證的工作與復原結果。 |

展示時打開對應的原始設定與輸出，先指出哪台機器、哪個分區、
請求多少資源，再指出主機名、裝置和答案。若要深入了解單一結果，
回到該模組的緊鄰命令與輸出說明，不以圖示或設定宣告代替工作證據。
