"""檢查健檢分類，特別防止查詢失敗時誤報 pass。"""

import contextlib
import io
import subprocess
import unittest
from unittest.mock import patch

import node_preflight


class NodePreflightTests(unittest.TestCase):
    # 模擬可存取目錄與 idle 節點，確認符合設定需求時回傳 pass。
    def test_idle_node_and_accessible_directory_pass(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, "node01|idle|2|3000\n", "")):
            result = node_preflight.inspect("node01", "/work", 1, 256, 5)
        self.assertEqual("pass", result["status"])

    # 模擬 CPU 需求超過節點設定，確認明確條件不符會回傳 fail。
    def test_request_above_node_setting_fails(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, "node01|idle|2|3000\n", "")):
            result = node_preflight.inspect("node01", "/work", 3, 256, 5)
        self.assertEqual("fail", result["status"])
        self.assertEqual("fail", next(c for c in result["checks"] if c["name"] == "cpus")["status"])

    # 模擬控制器查詢失敗，確認未取得資料時不會誤報 pass。
    def test_scheduler_failure_is_unknown(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 1, "", "controller unavailable\n")):
            result = node_preflight.inspect("node01", "/work", 1, 256, 5)
        self.assertEqual("unknown", result["status"])

    # 模擬路徑缺失與查詢逾時同時發生，確認保留兩項證據並回傳 fail。
    def test_missing_directory_fails_even_when_scheduler_times_out(self):
        with patch.object(node_preflight, "check_directory", return_value=("fail", "工作目錄不存在")), \
             patch.object(node_preflight.subprocess, "run", side_effect=subprocess.TimeoutExpired("sinfo", 5)):
            result = node_preflight.inspect("node01", "/missing", 1, 256, 5)
        self.assertEqual("fail", result["status"])
        self.assertEqual("unknown", next(c for c in result["checks"] if c["name"] == "slurm_node")["status"])

    # 模擬 sinfo 數值欄位損壞，確認程式回傳 unknown 而非猜測資源量。
    def test_malformed_node_data_is_unknown(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, "node01|idle|two|3000\n", "")):
            result = node_preflight.inspect("node01", "/work", 1, 256, 5)
        self.assertEqual("unknown", result["status"])

    # 確認無法判斷與命令列參數錯誤使用不同退出碼，方便腳本分流處理。
    def test_unknown_and_invalid_arguments_have_distinct_exit_codes(self):
        with patch.object(node_preflight, "inspect", return_value={"status": "unknown"}), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(3, node_preflight.main([
                "--node", "node01", "--path", "/work", "--cpus", "1", "--memory-mib", "256"
            ]))
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                node_preflight.main([
                    "--node", "node01", "--path", "/work", "--cpus", "0", "--memory-mib", "256"
                ])
        self.assertEqual(2, error.exception.code)


if __name__ == "__main__":
    unittest.main()
