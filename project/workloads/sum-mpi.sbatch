#!/usr/bin/env bash
# 在單節點 Slurm 工作中啟動兩個 MPI rank，核對 1 到 10 的總和與所在節點。
# 執行節點須已有 /tmp/sum_mpi 與 MPICH 模組；輸出留在提交工作時的目錄。
#SBATCH --job-name=sum-mpi
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem=128M
#SBATCH --time=00:02:00
# 工作輸出寫入提交目錄；%j 會替換為工作 ID。
#SBATCH --output=sum-mpi-%j.out

# 任何步驟失敗就讓批次工作失敗，避免把啟動錯誤當成計算成功。
set -e

# 批次 shell 不假定已載入互動 shell 的 MPICH 環境。
source /etc/profile.d/modules.sh
module load mpi/mpich-x86_64

printf 'job_id=%s\n' "$SLURM_JOB_ID"
printf 'batch_node=%s\n' "$(hostname -s)"

# pmi2 是此 Slurm 安裝列出的 MPI 啟動類型；兩個 task 各執行一次程式。
# N=10 的已知答案為 55；程式輸出各 rank 的主機、範圍與部分總和。
srun --mpi=pmi2 --ntasks=2 /tmp/sum_mpi 10
