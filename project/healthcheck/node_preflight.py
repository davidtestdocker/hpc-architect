#!/usr/bin/env python3
"""以目前使用者身分檢查工作目錄與 Slurm 節點的基本執行條件。"""

import argparse
import json
import os
import stat
import subprocess
import sys


SINFO_FORMAT = "%N|%T|%c|%m"


# 將命令列的 CPU、記憶體或逾時值轉成正整數；無效值交由 argparse 回報。
def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("必須是大於零的整數")
    return number


# 在指定秒數內查詢單一 Slurm 節點；回傳節點欄位，失敗時回傳診斷訊息。
def read_node(node, timeout):
    # 不經 shell 執行，避免節點名稱被解釋成命令；逾時視為無法判斷。
    command = ["sinfo", "-N", "-h", "-n", node, "-o", SINFO_FORMAT]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return None, "sinfo 查詢逾時"
    except OSError as exc:
        return None, f"無法執行 sinfo：{exc.strerror or type(exc).__name__}"

    if result.returncode != 0:
        # 保留診斷訊息，但不輸出整段環境資料或其他命令結果。
        detail = result.stderr.strip().splitlines()[:1]
        return None, f"sinfo 退出碼 {result.returncode}：{detail[0][:200] if detail else '沒有錯誤訊息'}"

    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if len(lines) != 1:
        return None, f"預期一筆節點資料，實際取得 {len(lines)} 筆"
    fields = lines[0].split("|")
    if len(fields) != 4 or fields[0] != node:
        return None, "sinfo 節點資料格式或名稱不符"
    try:
        cpus, memory_mib = int(fields[2]), int(fields[3])
    except ValueError:
        return None, "sinfo CPU 或記憶體欄位不是整數"
    if cpus < 1 or memory_mib < 1 or not fields[1]:
        return None, "sinfo 節點資料缺少有效值"
    return {"name": fields[0], "state": fields[1].lower(), "cpus": cpus, "memory_mib": memory_mib}, None


# 以目前進程身分檢查工作目錄；回傳 pass／fail／unknown 與判斷理由。
def check_directory(path):
    # 用執行此程式的 UID/GID 檢查；跨節點時須在實際執行節點重查。
    try:
        info = os.stat(path)
    except FileNotFoundError:
        return "fail", "工作目錄不存在"
    except (PermissionError, OSError) as exc:
        return "unknown", f"無法檢查工作目錄：{exc.strerror or type(exc).__name__}"
    if not stat.S_ISDIR(info.st_mode):
        return "fail", "工作路徑不是目錄"
    if not os.access(path, os.R_OK | os.W_OK | os.X_OK):
        return "fail", "目前使用者無法讀寫並進入工作目錄"
    return "pass", "目前使用者可讀寫並進入工作目錄"


# 合併路徑與 Slurm 資源檢查，回傳含個別證據和整體狀態的字典。
def inspect(node, path, cpus, memory_mib, timeout):
    result = {
        "status": "unknown",
        "node": node,
        "path": path,
        "effective_uid": os.geteuid(),
        "requested": {"cpus": cpus, "memory_mib": memory_mib},
        "observed": {},
        "checks": [],
    }
    path_status, path_detail = check_directory(path)
    result["checks"].append({"name": "work_directory", "status": path_status, "detail": path_detail})

    node_data, error = read_node(node, timeout)
    if error:
        result["checks"].append({"name": "slurm_node", "status": "unknown", "detail": error})
    else:
        result["observed"] = node_data
        state = node_data["state"]
        if state == "idle":
            state_status = "pass"
        elif state == "mixed":
            state_status = "unknown"
        else:
            state_status = "fail"
        result["checks"].append({"name": "node_state", "status": state_status, "detail": state})
        for name, requested, available in (
            ("cpus", cpus, node_data["cpus"]),
            ("memory_mib", memory_mib, node_data["memory_mib"]),
        ):
            status = "pass" if requested <= available else "fail"
            result["checks"].append({"name": name, "status": status,
                                     "detail": f"需求 {requested}；節點設定 {available}"})

    statuses = {check["status"] for check in result["checks"]}
    result["status"] = "fail" if "fail" in statuses else "unknown" if "unknown" in statuses else "pass"
    return result


# 解析命令列、輸出一行 JSON；0／1／3 表示 pass／fail／unknown，2 留給無效參數。
def main(argv=None):
    parser = argparse.ArgumentParser(description="唯讀檢查工作目錄與 Slurm 節點設定；pass 不保證工作會被排程。")
    parser.add_argument("--node", required=True, help="Slurm 節點名稱")
    parser.add_argument("--path", required=True, help="要使用的工作目錄")
    parser.add_argument("--cpus", required=True, type=positive_int, help="工作需要的 CPU 數")
    parser.add_argument("--memory-mib", required=True, type=positive_int, help="工作需要的記憶體 MiB")
    parser.add_argument("--timeout", type=positive_int, default=5, help="sinfo 查詢逾時秒數，預設 5")
    args = parser.parse_args(argv)
    result = inspect(args.node, args.path, args.cpus, args.memory_mib, args.timeout)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return {"pass": 0, "fail": 1, "unknown": 3}[result["status"]]


if __name__ == "__main__":
    sys.exit(main())
