# 按實作查閱的官方資料

以下是資料入口，不要求先讀完。開始安裝或編譯前，先確認 VM 上的發行版、套件及軟體版本，再選對應版本的文件；連結中的 latest/current 可能變動。

| 模組 | 資料入口 | 查閱目的 |
|---|---|---|
| 1 | [Python 教學](https://docs.python.org/3/tutorial/index.html)、[標準函式庫](https://docs.python.org/3/library/index.html) | `argparse`、`json`、`subprocess`、例外與測試所需部分；Linux 機制先看本機 man 與 `/proc` |
| 2、5 | [Slurm 管理者指南](https://slurm.schedmd.com/quickstart_admin.html)、[Slurm 使用者指南](https://slurm.schedmd.com/quickstart.html) | 節點、服務、工作生命週期與已安裝版本的設定 |
| 3 | [GCC 文件](https://gcc.gnu.org/onlinedocs/)、[Open MPI 文件](https://docs.open-mpi.org/en/main/) | 編譯、rank、通訊與 Slurm 整合；以實際版本核對 |
| 4 | [GCP 網路文件](https://docs.cloud.google.com/compute/docs/networking/network-overview)、本機 `man ip`、`man ssh`、`man exports` | 網路規則、名稱、SSH 與 NFS |
| 5 | [Ansible 入門](https://docs.ansible.com/projects/ansible/latest/getting_started/index.html) | inventory、playbook、roles、handlers 與冪等性 |
| 6 | [Zabbix 文件](https://www.zabbix.com/documentation/current/en/manual/quickstart) | 若採用 Zabbix，核對 host、item、trigger 與版本 |
| 7 | [Linux CPU 拓撲](https://docs.kernel.org/arch/x86/topology.html)、[Kubernetes 概念](https://kubernetes.io/docs/concepts/)、[OpenStack 文件](https://docs.openstack.org/) | 量測解釋與技術邊界；不要求部署完整平台 |

需要容器實作時再查 [Apptainer 指南](https://apptainer.org/docs/user/latest/)；GPU、RDMA 或平行檔案系統須有具體需求和硬體條件，才加深到安裝或調校。
