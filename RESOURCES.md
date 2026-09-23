# 官方教材與閱讀範圍

查閱日期：2026-09-23。課程內容是為本職缺設計的學習安排；以下是查證與延伸入口。連結中的 latest/current 會變動，開始實作時記錄實際版本，再選對應版本文件。Python 官方教學偏向已有程式概念者，初學先跟每日練習，不要求一次讀完。

| 週次 | 教材 | 只先讀什麼 |
|---|---|---|
| 1–4 | [Ubuntu 終端機入門](https://ubuntu.com/server/docs/tutorial/welcome-to-the-terminal/)、本機 man bash、man systemctl、man journalctl、git help | 路徑、檔案、權限、流程控制；每次只查當日命令 |
| 5–6 | [Python Tutorial](https://docs.python.org/3/tutorial/index.html)、[標準函式庫](https://docs.python.org/3/library/index.html) | 基本型別、控制流程、函式、檔案、例外；再查 argparse、json、subprocess、venv |
| 7–8 | [GCP 網路](https://docs.cloud.google.com/compute/docs/networking/network-overview)、本機 man ip、man ss、man ssh、man exports | VM 位址與路由，SSH 與 NFS 設定；確認發行版配套文件 |
| 9 | [Linux CPU 拓撲](https://docs.kernel.org/arch/x86/topology.html)、[GCC 文件](https://gcc.gnu.org/onlinedocs/) | 核心／執行緒／socket 概念；GCC 編譯及警告選項 |
| 10–11 | [Ansible 入門](https://docs.ansible.com/projects/ansible/latest/getting_started/index.html) | inventory、playbook、變數、模板、handlers；再查 check mode 與 roles |
| 12–13 | [Slurm 使用者指南](https://slurm.schedmd.com/quickstart.html)、[管理者指南](https://slurm.schedmd.com/quickstart_admin.html) | 工作提交與節點管理，先單節點再多節點，依安裝版本設定驗證方式 |
| 14–15 | [Open MPI 文件](https://docs.open-mpi.org/en/main/)、[啟動程式](https://docs.open-mpi.org/en/main/launching-apps/index.html) | 編譯、rank、啟動、Slurm 整合；main 入口需切換為安裝版本 |
| 16–17 | [Zabbix Quickstart](https://www.zabbix.com/documentation/current/en/manual/quickstart) | host、item、trigger、template；回頭整合服務日誌與 Slurm 狀態 |
| 18 | [Kubernetes 概念](https://kubernetes.io/docs/concepts/)、[OpenStack 文件](https://docs.openstack.org/)、[Apptainer 指南](https://apptainer.org/docs/user/latest/) | 只先讀角色、Job、運算／網路／映像，以及容器執行觀念；不要求架完整 OpenStack |
| 19–24 | 回讀以上符合自己部署版本的文件 | 對照實作補證據、架構取捨與故障復原；硬體特性用目標設備的廠商文件核對 |

每日英文練習：選三個術語，讀一小段官方說明，再用自己的話寫三句。不要把大量文件摘錄當成自己的學習心得。
