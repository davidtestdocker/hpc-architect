# 24 週課程總表

對象：有 SRE／維運經驗、會 Linux、程式略懂，希望從基礎重建。每週約 20 小時：D1–D5 各 3 小時、D6 4 小時、D7 1 小時；可將 D7 合併到 D6 留一天休息。24 週約 480 小時，依驗收調整，不跳過基礎。

週次是學習順序，不綁定日曆。已有 SRE／維運經驗的內容依實際能力壓縮；完成指令清單不代表通過驗收。每個階段以 [課程入口的能力門檻](../README.md#階段與能力門檻) 和 [面試專案驗收](../project/README.md#必做驗收) 判斷，缺少實際證據就標為未完成。跨 VM 實驗從第 7 週開始需要第二台，第 8 週規劃第三台；未準備額外資源時先做單機部分，跨節點項目標為待完成。參見 [GCP 環境方案](../ENVIRONMENT.md)。

每日文件含課前摘要、實作題、驗收與未填寫的學習紀錄；摘要是導讀，不是假裝你已完成的筆記。

| 週 | 大方向 | 每日安排 |
|---|---|---|
| 01 | 認識 HPC 與 Linux 起步 | [D1 HPC 全貌](week-01/day-01.md)；[D2 使用者、目錄與工具環境](week-01/day-02.md)；[D3 終端機與路徑](week-01/day-03.md)；[D4 檔案與 Vim](week-01/day-04.md)；[D5 查說明與錯誤](week-01/day-05.md)；[D6 程序資源限制與 cgroup](week-01/day-06.md)；[D7 情境驗收](week-01/day-07.md) |
| 02 | Linux 檔案、權限與 Git | [D1 文字處理](week-02/day-01.md)；[D2 使用者與權限](week-02/day-02.md)；[D3 群組與 sudo](week-02/day-03.md)；[D4 Git 基礎](week-02/day-04.md)；[D5 Git 分支與復原](week-02/day-05.md)；[D6 檔案封存與備份](week-02/day-06.md)；[D7 複習](week-02/day-07.md) |
| 03 | Linux 程序、服務與日誌 | [D1 程序與資源](week-03/day-01.md)；[D2 套件與相依性](week-03/day-02.md)；[D3 systemd 服務](week-03/day-03.md)；[D4 日誌排查](week-03/day-04.md)；[D5 Shell 腳本](week-03/day-05.md)；[D6 排程與復原](week-03/day-06.md)；[D7 複習](week-03/day-07.md) |
| 04 | Shell 與維運基本功複習 | [D1 標準輸入輸出](week-04/day-01.md)；[D2 引用與變數](week-04/day-02.md)；[D3 條件與迴圈](week-04/day-03.md)；[D4 函式與參數](week-04/day-04.md)；[D5 程序與訊號](week-04/day-05.md)；[D6 維運腳本審查](week-04/day-06.md)；[D7 複習](week-04/day-07.md) |
| 05 | Python 程式基礎 | [D1 變數與型別](week-05/day-01.md)；[D2 條件與迴圈](week-05/day-02.md)；[D3 串列與字典](week-05/day-03.md)；[D4 函式](week-05/day-04.md)；[D5 檔案與例外](week-05/day-05.md)；[D6 小型日誌分析器](week-05/day-06.md)；[D7 複習](week-05/day-07.md) |
| 06 | Python 系統工具 | [D1 JSON 與 CSV](week-06/day-01.md)；[D2 命令列參數](week-06/day-02.md)；[D3 執行外部命令](week-06/day-03.md)；[D4 環境與依賴](week-06/day-04.md)；[D5 測試與可維護性](week-06/day-05.md)；[D6 主機健檢工具 v1](week-06/day-06.md)；[D7 複習](week-06/day-07.md) |
| 07 | 網路基礎與診斷 | [D1 IP 與子網路](week-07/day-01.md)；[D2 路由與閘道](week-07/day-02.md)；[D3 DNS 與主機名](week-07/day-03.md)；[D4 TCP UDP 與連接埠](week-07/day-04.md)；[D5 SSH 金鑰](week-07/day-05.md)；[D6 網路診斷流程](week-07/day-06.md)；[D7 複習](week-07/day-07.md) |
| 08 | 多節點網路與儲存 | [D1 多 VM 拓撲](week-08/day-01.md)；[D2 名稱與時間一致](week-08/day-02.md)；[D3 防火牆](week-08/day-03.md)；[D4 網路封包觀察](week-08/day-04.md)；[D5 NFS 與 UID](week-08/day-05.md)；[D6 儲存故障演練](week-08/day-06.md)；[D7 複習](week-08/day-07.md) |
| 09 | 計算機架構與 C 入門 | [D1 CPU 與記憶體階層](week-09/day-01.md)；[D2 NUMA 與 PCIe](week-09/day-02.md)；[D3 C 編譯流程](week-09/day-03.md)；[D4 C 迴圈與陣列](week-09/day-04.md)；[D5 指標與配置](week-09/day-05.md)；[D6 效能量測入門](week-09/day-06.md)；[D7 複習](week-09/day-07.md) |
| 10 | Ansible 自動化入門 | [D1 Inventory](week-10/day-01.md)；[D2 第一個 Playbook](week-10/day-02.md)；[D3 變數與模板](week-10/day-03.md)；[D4 Handler 與服務](week-10/day-04.md)；[D5 冪等性](week-10/day-05.md)；[D6 自動建立基礎環境](week-10/day-06.md)；[D7 複習](week-10/day-07.md) |
| 11 | 自動化可靠度與專案起稿 | [D1 Roles 與檔案結構](week-11/day-01.md)；[D2 秘密與設定](week-11/day-02.md)；[D3 變更前驗證](week-11/day-03.md)；[D4 失敗處理](week-11/day-04.md)；[D5 重建基準](week-11/day-05.md)；[D6 專案設計審查](week-11/day-06.md)；[D7 複習](week-11/day-07.md) |
| 12 | Slurm 使用者操作 | [D1 排程器概念](week-12/day-01.md)；[D2 單節點 Slurm 實驗](week-12/day-02.md)；[D3 互動工作](week-12/day-03.md)；[D4 批次工作](week-12/day-04.md)；[D5 資源請求](week-12/day-05.md)；[D6 工作排查](week-12/day-06.md)；[D7 複習](week-12/day-07.md) |
| 13 | 多節點 Slurm 管理 | [D1 驗證與 MUNGE](week-13/day-01.md)；[D2 節點資源設定](week-13/day-02.md)；[D3 控制器與運算節點](week-13/day-03.md)；[D4 分區與限制](week-13/day-04.md)；[D5 Drain 與復原](week-13/day-05.md)；[D6 部署自動化](week-13/day-06.md)；[D7 複習](week-13/day-07.md) |
| 14 | MPI 與平行程式 | [D1 MPI 程式模型](week-14/day-01.md)；[D2 跨節點啟動](week-14/day-02.md)；[D3 資料切分](week-14/day-03.md)；[D4 集合通訊](week-14/day-04.md)；[D5 正確性與失敗](week-14/day-05.md)；[D6 第一個 HPC 工作負載](week-14/day-06.md)；[D7 複習](week-14/day-07.md) |
| 15 | 效能與瓶頸分析 | [D1 量測設計](week-15/day-01.md)；[D2 加速比與效率](week-15/day-02.md)；[D3 Amdahl 定律](week-15/day-03.md)；[D4 CPU 記憶體與 I/O](week-15/day-04.md)；[D5 網路吞吐與延遲](week-15/day-05.md)；[D6 效能報告](week-15/day-06.md)；[D7 複習](week-15/day-07.md) |
| 16 | Zabbix 監控與告警 | [D1 監控模型](week-16/day-01.md)；[D2 安裝與接入](week-16/day-02.md)；[D3 主機與模板](week-16/day-03.md)；[D4 Trigger 設計](week-16/day-04.md)；[D5 服務故障監控](week-16/day-05.md)；[D6 儀表板與處置](week-16/day-06.md)；[D7 複習](week-16/day-07.md) |
| 17 | 健檢工具與故障排除 | [D1 健檢工具 v2](week-17/day-01.md)；[D2 Slurm 狀態解析](week-17/day-02.md)；[D3 DNS 故障演練](week-17/day-03.md)；[D4 共享路徑故障](week-17/day-04.md)；[D5 节点不可用](week-17/day-05.md)；[D6 事件報告](week-17/day-06.md)；[D7 複習](week-17/day-07.md) |
| 18 | 容器、K8s 與 OpenStack 定位 | [D1 容器與 VM](week-18/day-01.md)；[D2 容器實作](week-18/day-02.md)；[D3 HPC 容器概念](week-18/day-03.md)；[D4 K8s 基本概念](week-18/day-04.md)；[D5 OpenStack 基本概念](week-18/day-05.md)；[D6 技術選擇練習](week-18/day-06.md)；[D7 複習](week-18/day-07.md) |
| 19 | HPC 架構規劃 | [D1 需求訪談](week-19/day-01.md)；[D2 容量規劃](week-19/day-02.md)；[D3 網路分工](week-19/day-03.md)；[D4 RDMA 與 GPU 概念](week-19/day-04.md)；[D5 可用性與備份](week-19/day-05.md)；[D6 架構提案](week-19/day-06.md)；[D7 複習](week-19/day-07.md) |
| 20 | 面試專案整合 | [D1 驗收凍結](week-20/day-01.md)；[D2 乾淨環境重建](week-20/day-02.md)；[D3 工作流程驗收](week-20/day-03.md)；[D4 監控與故障整合](week-20/day-04.md)；[D5 重現與版本](week-20/day-05.md)；[D6 成果整理](week-20/day-06.md)；[D7 複習](week-20/day-07.md) |
| 21 | 專案驗收與修補緩衝 | [D1 需求追蹤](week-21/day-01.md)；[D2 部署重跑](week-21/day-02.md)；[D3 測試資料整理](week-21/day-03.md)；[D4 恢復流程重測](week-21/day-04.md)；[D5 缺口修補](week-21/day-05.md)；[D6 發布候選作品](week-21/day-06.md)；[D7 複習](week-21/day-07.md) |
| 22 | 文件與展示 | [D1 README 敘事](week-22/day-01.md)；[D2 架構圖](week-22/day-02.md)；[D3 操作手冊](week-22/day-03.md)；[D4 展示腳本](week-22/day-04.md)；[D5 錄影彩排](week-22/day-05.md)；[D6 同儕檢查](week-22/day-06.md)；[D7 複習](week-22/day-07.md) |
| 23 | 履歷與技術面試 | [D1 職缺能力對照](week-23/day-01.md)；[D2 專案履歷段落](week-23/day-02.md)；[D3 Linux 與網路問答](week-23/day-03.md)；[D4 HPC 與效能問答](week-23/day-04.md)；[D5 程式與自動化問答](week-23/day-05.md)；[D6 英文與協作敘事](week-23/day-06.md)；[D7 複習](week-23/day-07.md) |
| 24 | 投遞準備與補強 | [D1 模擬面試一](week-24/day-01.md)；[D2 弱點修補](week-24/day-02.md)；[D3 模擬面試二](week-24/day-03.md)；[D4 履歷與作品核對](week-24/day-04.md)；[D5 投遞策略](week-24/day-05.md)；[D6 下一階段計畫](week-24/day-06.md)；[D7 複習](week-24/day-07.md) |
