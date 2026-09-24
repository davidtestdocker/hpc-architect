#!/usr/bin/env bash
# 單節點批次健檢：確認一般帳號的工作能進入 debug 分區並留下可核對的輸出。
# 申請一個節點、一個行程、一個 CPU 和 256 MiB 記憶體；兩分鐘未完成則逾時。
#SBATCH --job-name=hpc-node-smoke
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=256M
#SBATCH --time=00:02:00
# %j 會替換為工作 ID；輸出檔建立在提交工作時的目錄。
#SBATCH --output=slurm-%j.out

# 命令失敗或必要的 Slurm 環境變數不存在時，讓腳本以失敗狀態結束。
set -euo pipefail

# 留下工作身分、實際執行節點與向排程器申請的資源，供之後核對。
# 這些請求值不是 CPU 綁定或記憶體隔離已生效的證明。
printf 'job_id=%s\n' "$SLURM_JOB_ID"
printf 'user=%s\n' "$(id -un)"
printf 'node=%s\n' "$(hostname -s)"
printf 'requested_nodes=%s\n' "$SLURM_JOB_NUM_NODES"
printf 'requested_cpus_per_task=%s\n' "$SLURM_CPUS_PER_TASK"
printf 'requested_memory_mb=%s\n' "$SLURM_MEM_PER_NODE"
