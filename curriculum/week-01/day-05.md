# W01 D5：查說明與錯誤

[課程總表](../ROADMAP.md) · [參考教材](../../RESOURCES.md) · [進度](../../PROGRESS.md)

狀態：已完成｜實際日期：2026-09-24｜實際時間：未另行記錄

## 今日目標與課前筆記

命令、選項、參數有不同角色；錯誤訊息是診斷線索。

## 學習方式

帶練時一次只執行一條指令；輸出確認後，再進到下一步。

## 實作

讀 man ls，試兩種選項；對不存在的練習路徑執行 ls，記錄錯誤與修正。

## 執行前計畫

本日不建立或修改任何檔案；所有指令僅讀取說明或目錄資訊。

1. `man ls | head -n 20`：讀取 `ls` 手冊的開頭，辨識命令名稱與用途。
2. `ls -la curriculum/week-01`：以 `-l` 顯示詳細資訊、以 `-a` 顯示點開頭項目，觀察兩個選項的作用。
3. `ls /tmp/w01d05-path-does-not-exist`：刻意查詢不存在的路徑，讀取錯誤訊息中的診斷線索；此命令不會建立該路徑。
4. `ls -ld /tmp`：改查已知存在的 `/tmp`，確認修正後的指令與目標路徑有效。


## 實作紀錄

帶練時追加實際命令、重點輸出與解釋。

### 1. 讀取 `ls` 手冊開頭

**實際指令**

```bash
man ls | head -n 20
```

**重點輸出**

```text
NAME
       ls - list directory contents

SYNOPSIS
       ls [OPTION]... [FILE]...

       -a, --all
              do not ignore entries starting with .
```

**結果解釋**

`ls` 用於列出目錄內容。`SYNOPSIS` 顯示選項與目標路徑的角色：選項改變列出方式，`FILE` 指定要查看的路徑；省略路徑時使用目前目錄。`-a` 會顯示點開頭的項目，`-A` 則會保留隱藏項目但排除 `.` 和 `..`。

### 2. 同時使用 `-l` 與 `-a`

**實際指令**

```bash
ls -la curriculum/week-01
```

**重點輸出**

```text
drwxr-xr-x.  2 root root   125 Sep 23 14:23 .
drwxr-xr-x. 26 root root  4096 Sep 23 11:43 ..
-rw-r--r--.  1 root root 12750 Sep 23 15:00 day-01.md
...
-rw-r--r--.  1 root root   295 Sep 23 14:23 day-07.md
```

**結果解釋**

`-l` 顯示每個項目的權限、擁有者、大小與修改時間；`-a` 額外顯示 `.`（目前目錄）及 `..`（父目錄）。輸出確認 `curriculum/week-01` 內有 D01 至 D07 的課程檔。

### 3. 讀取不存在路徑的錯誤

**實際指令**

```bash
ls /tmp/w01d05-path-does-not-exist
```

**重點輸出**

```text
ls: cannot access '/tmp/w01d05-path-does-not-exist': No such file or directory
```

**結果解釋**

`cannot access` 表示操作失敗，`No such file or directory` 說明指定的路徑不存在。這是讀取操作，沒有建立任何檔案或目錄；修正時應確認目標名稱，或改查已知存在的路徑。

### 4. 改查已知存在的目錄

**實際指令**

```bash
ls -ld /tmp
```

**重點輸出**

```text
drwxrwxrwt. 11 root root 4096 Sep 24 05:29 /tmp
```

**結果解釋**

`/tmp` 存在且可存取。權限末尾的 `t` 是 sticky bit：所有使用者可在此建立項目，但通常只能刪除或改名自己擁有的項目。這證實前一步的問題是指定路徑不存在，而非 `/tmp` 無法使用。
