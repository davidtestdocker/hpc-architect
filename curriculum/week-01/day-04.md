# W01 D4：檔案與 Vim

[課程總表](../ROADMAP.md) · [參考教材](../../RESOURCES.md) · [進度](../../PROGRESS.md)

狀態：進行中｜實際日期：2026-09-24｜實際時間：進行中

## 今日目標與課前筆記

檔案內容與檔名是不同概念；複製後的檔案可以獨立修改。使用業界常見的終端機編輯器 Vim，掌握開啟、插入、儲存與離開的基本操作。

## 學習方式

帶練時一次只執行一條指令；輸出確認後，再進到下一步。

## 實作

用 Vim 寫五行文字，練習 `cp`、`mv`、`cat`，確認原件與副本差異。


## 實作紀錄

帶練時追加實際命令、重點輸出與解釋。

### 1. 確認 Vim 可用

**指令與目的**

```bash
vim --version | head -n 1
```

確認 VM 已安裝 Vim，並顯示版本資訊的第一行。

**重點輸出**

```text
VIM - Vi IMproved 9.1 (2024 Jan 02, compiled Sep 04 2026 00:00:00)
```

**結果解釋**

VM 已安裝 Vim 9.1，可直接使用。Vim 是業界常見的終端機文字編輯器，足以進行今天的檔案編輯練習。

### 2. 用 Vim 建立原始文字檔

**指令與目的**

```bash
vim .w01d04-vim-original.txt
```

開啟 Vim 建立文字檔；按 `i` 進入插入模式，輸入五行文字後按 `Esc`，以 `:wq` 儲存並離開。

**重點輸出**

```text
[root@instance-20260923-104239 hpc-arch]#
```

**結果解釋**

已回到 shell，表示 Vim 已結束。此次使用的核心操作是 `i` 進入插入模式、`Esc` 回到一般模式，以及 `:wq` 寫入檔案並離開；檔案內容將以下一步確認。

### 3. 讀取原始檔內容

**指令與目的**

```bash
cat .w01d04-vim-original.txt
```

將文字檔內容直接輸出到終端機，確認 Vim 已正確寫入。

**重點輸出**

```text
  HPC file practice
  Vim edits text files.
  This is the original file.
  Copies can change independently.
  Week 01 Day 04
```

**結果解釋**

已成功讀出五行內容。每行開頭的兩個空白也是檔案內容的一部分，代表 Vim 會精確保留輸入的字元。

### 4. 確認副本已建立

**驗證指令與目的**

```bash
ls -l .w01d04-vim-original.txt .w01d04-vim-copy.txt
```

確認原始檔與副本都存在，並比較基本檔案資訊。

**重點輸出**

```text
-rw-r--r--. 1 root root 125 Sep 24 03:33 .w01d04-vim-copy.txt
-rw-r--r--. 1 root root 125 Sep 24 03:31 .w01d04-vim-original.txt
```

**結果解釋**

兩個檔案都存在，權限相同且大小皆為 125 bytes。副本的時間較晚，符合原始檔複製後新建副本的結果；接著只修改副本，以驗證兩者可獨立變更。

### 5. 修改副本內容

**指令與目的**

```bash
vim .w01d04-vim-copy.txt && cat .w01d04-vim-copy.txt
```

以 Vim 修改副本的第三行，離開後立即讀取副本內容。

**重點輸出**

```text
  HPC file practice
  Vim edits text files.
  This is the modified copy.Copies can change independently.
  Week 01 Day 04
```

**結果解釋**

副本已與原始檔不同，但 `modified copy.` 與原本第四行的 `Copies...` 被接為同一行，表示兩段文字之間少了換行。下一步在此位置補入換行；原始檔不受此修改影響。

## Vim 基本指令摘要

- `vim 檔名`：開啟或建立檔案。
- `i`：進入插入模式，開始輸入文字；`Esc`：回到一般模式。
- `:w`：儲存；`:q`：離開；`:wq`：儲存並離開；`:q!`：放棄未儲存變更並離開。
- `dd`：刪除目前整行；`u`：復原上一步。
- `/文字`：搜尋文字；`n`：前往下一個搜尋結果。
