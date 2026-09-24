#!/usr/bin/env bash
#SBATCH --job-name=hpc-node-smoke
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=256M
#SBATCH --time=00:02:00
#SBATCH --output=slurm-%j.out

set -euo pipefail

printf 'job_id=%s\n' "$SLURM_JOB_ID"
printf 'user=%s\n' "$(id -un)"
printf 'node=%s\n' "$(hostname -s)"
printf 'requested_nodes=%s\n' "$SLURM_JOB_NUM_NODES"
printf 'requested_cpus_per_task=%s\n' "$SLURM_CPUS_PER_TASK"
printf 'requested_memory_mb=%s\n' "$SLURM_MEM_PER_NODE"
