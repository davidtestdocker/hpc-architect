# W02 D2：路徑逐層權限

[課程總表](../ROADMAP.md) · [參考教材](../../RESOURCES.md) · [進度](../../PROGRESS.md)

狀態：單一路徑案例已完成｜實際日期：2026-09-24

## 今日目標與課前筆記

W01 已用 `id`、`ls -ld` 確認帳號與目錄權限，本日不重跑帳號盤點或建立純測試目錄。新重點是：讀取一個檔案時，不只要看檔案本身的權限，還需要能穿過路徑上的每一層父目錄。目錄權限中的 `x` 代表可穿越；缺少它，就算最裡面的檔案標成可讀，該使用者也到不了檔案。

例如一般帳號 `a2264` 想讀 `/root/hpc-arch/curriculum/week-02/day-02.md`，必須依序能穿過 `/root`、`/root/hpc-arch`、`curriculum`、`week-02`。`namei -l` 會把這些路徑元件及其權限逐層列出，適合定位卡在哪一層。

## 學習方式

帶練時一次只執行一條指令；輸出確認後，再進到下一步。

## 實作

對現有課程檔先逐層檢查權限、預測一般帳號會在哪裡受阻，再以該帳號實際嘗試讀取。若預測與結果不符，才追加 ACL 或 SELinux 診斷。本日能指出阻擋的路徑元件、用實際讀取結果驗證，並說明不應為了讀課程檔而放寬 `/root` 權限。

## 執行前計畫

本日不建立、刪除或修改檔案，也不變更權限。

1. `namei -l /root/hpc-arch/curriculum/week-02/day-02.md`：列出從 `/` 到課程檔的每一層擁有者、群組與權限，找出一般帳號是否可穿越路徑。
2. `sudo -u a2264 head -n 1 /root/hpc-arch/curriculum/week-02/day-02.md`：只對這一條唯讀命令暫時使用 `a2264` 身分，驗證該帳號能否真正讀到檔案；不切換互動式 shell，也不修改目標。若與第一步的預測不一致，再依錯誤內容決定是否需要查 ACL 或 SELinux。


## 實作紀錄

帶練時追加實際命令、重點輸出與解釋。

### 1. 逐層查看課程檔路徑權限

**實際指令**

```bash
namei -l /root/hpc-arch/curriculum/week-02/day-02.md
```

**實際輸出**

```text
f: /root/hpc-arch/curriculum/week-02/day-02.md
dr-xr-xr-x root root /
dr-xr-x--- root root root
drwxr-xr-x root root hpc-arch
drwxr-xr-x root root curriculum
drwxr-xr-x root root week-02
-rw-r--r-- root root day-02.md
```

**結果解釋**

`/root` 這一層是 `dr-xr-x---`，其他使用者沒有 `x`（穿越）權限。D02 已查過 `a2264` 不屬於 `root` 群組，因此預測它無法通過 `/root`。後續目錄雖有其他使用者的 `x`，最終檔案也有其他使用者的 `r`，仍無法繞過較前面被阻擋的目錄。

### 2. 以一般帳號驗證讀取結果

**實際指令**

```bash
sudo -u a2264 head -n 1 /root/hpc-arch/curriculum/week-02/day-02.md
```

**實際輸出**

```text
head: cannot open '/root/hpc-arch/curriculum/week-02/day-02.md' for reading: Permission denied
```

**結果解釋**

`a2264` 實際無法讀取檔案，符合上一項對 `/root` 缺少穿越權限的預測。現有 POSIX 權限已足以解釋這個拒絕結果，無需再做 ACL 或 SELinux 排查，也不應為了讀這份檔案而放寬 `/root` 權限。若要共享內容，應使用經過規劃的共享位置。這條 `sudo -u` 只影響單次 `head` 命令，原本的 root shell 不變。

本次只驗證了「父目錄缺少穿越權限」這一種拒絕原因，不能據此宣稱已能處理所有檔案權限問題。後續在真正部署共用資料路徑時，仍需依實際使用者與群組、檔案和目錄權限、可能存在的 ACL／SELinux 規則，以及執行服務的身分，完成存取設計與正反向驗證。
