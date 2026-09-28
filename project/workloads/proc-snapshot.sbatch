#!/usr/bin/env bash
# 在單節點 Slurm 工作中執行 C++ 程序快照工具，核對工作能啟動並讀取自己的 /proc 狀態。
# 需先在執行節點備妥 /tmp/proc_snapshot；輸出留在提交工作時的目錄。
# 投入模組 01 已驗證的本機 debug 分區，只申請一個節點與一個 Slurm task。
#SBATCH --job-name=proc-snapshot
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64M
#SBATCH --time=00:02:00
# 工作輸出寫入提交目錄；%j 會替換為實際工作 ID。
#SBATCH --output=proc-snapshot-%j.out

# 任一工作步驟失敗時讓批次工作回報失敗；缺少必要的 Slurm 變數也視為錯誤。
set -euo pipefail

# 留下工作 ID 與執行節點，供核對 Slurm 啟動位置。
printf 'job_id=%s\n' "$SLURM_JOB_ID"
printf 'node=%s\n' "$(hostname -s)"

# srun 在配置的節點啟動 bash；exec 保留該 PID，讓 C++ 程式讀取自己的狀態。
srun /bin/bash -c 'exec /tmp/proc_snapshot --pid "$$"'
