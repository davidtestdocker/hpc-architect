#!/usr/bin/env bash
# 單節點批次健檢：確認一般帳號的工作能進入 debug 分區並留下可核對的輸出。
# 以下 #SBATCH 指示由 sbatch 在提交時讀取，用來建立工作請求。
# 工作名稱，方便在佇列及工作紀錄中辨認。
#SBATCH --job-name=hpc-node-smoke
# 投入 debug 分區；該分區目前只有這台教學 VM。
#SBATCH --partition=debug
# 申請一個運算節點。
#SBATCH --nodes=1
# 在所分配的節點啟動一個工作行程。
#SBATCH --ntasks=1
# 為這個行程申請一個 CPU；不是指定它必須綁在哪顆 CPU。
#SBATCH --cpus-per-task=1
# 為整個工作申請 256 MiB 記憶體；請求值不等於已驗證記憶體隔離。
#SBATCH --mem=256M
# 執行時間上限為兩分鐘；超時時 Slurm 會終止工作。
#SBATCH --time=00:02:00
# 標準輸出寫到提交時的工作目錄；%j 會替換為工作 ID。
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
