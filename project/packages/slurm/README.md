# Slurm 運算節點安裝檔

這裡保存控制節點為 AlmaLinux 10 x86_64 建出的 Slurm 26.05.4 套件，
供 AlmaLinux 10 運算 VM 安裝與既有控制端相同的 Slurm 版本。
`slurm` 提供共用元件，`slurm-slurmd` 提供運算節點服務；
原始碼封存檔保留建置來源。這些檔案已從控制節點的 `/tmp` 複製到工作樹，
重建時不再依賴該暫存目錄。

兩個 RPM 是在 `instance-20260923-104239` 以 Slurm 26.05.4 原始碼封存檔
`rpmbuild -ta` 建出的 `1.el10.x86_64` 套件，**沒有 RPM 簽章**。
`SHA256SUMS` 記錄這三個檔案複製後的雜湊值，可在此目錄執行
`sha256sum -c SHA256SUMS` 核對檔案是否與目前保存版本一致。
雜湊只核對檔案內容，不代表上游簽章或來源信任驗證。

`compute-cpu01` 已從這兩個 RPM 安裝 Slurm `26.05.4-1.el10`，
相依套件由 AlmaLinux 套件庫提供；實際安裝結果記於
[模組 05](../../../curriculum/module-05.md)。
MUNGE、NVIDIA 驅動與 CUDA 不在這個目錄，需依各節點用途另行處理。
