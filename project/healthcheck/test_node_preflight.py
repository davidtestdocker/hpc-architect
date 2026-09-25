"""檢查健檢分類，特別防止查詢失敗時誤報 pass。"""

import subprocess
import unittest
from unittest.mock import patch

import node_preflight


class NodePreflightTests(unittest.TestCase):
    def test_idle_node_and_accessible_directory_pass(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, "node01|idle|2|3000\n", "")):
            result = node_preflight.inspect("node01", "/work", 1, 256, 5)
        self.assertEqual("pass", result["status"])

    def test_request_above_node_setting_fails(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, "node01|idle|2|3000\n", "")):
            result = node_preflight.inspect("node01", "/work", 3, 256, 5)
        self.assertEqual("fail", result["status"])
        self.assertEqual("fail", next(c for c in result["checks"] if c["name"] == "cpus")["status"])

    def test_scheduler_failure_is_unknown(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 1, "", "controller unavailable\n")):
            result = node_preflight.inspect("node01", "/work", 1, 256, 5)
        self.assertEqual("unknown", result["status"])

    def test_missing_directory_fails_even_when_scheduler_times_out(self):
        with patch.object(node_preflight, "check_directory", return_value=("fail", "工作目錄不存在")), \
             patch.object(node_preflight.subprocess, "run", side_effect=subprocess.TimeoutExpired("sinfo", 5)):
            result = node_preflight.inspect("node01", "/missing", 1, 256, 5)
        self.assertEqual("fail", result["status"])
        self.assertEqual("unknown", next(c for c in result["checks"] if c["name"] == "slurm_node")["status"])

    def test_malformed_node_data_is_unknown(self):
        with patch.object(node_preflight, "check_directory", return_value=("pass", "可存取")), \
             patch.object(node_preflight.subprocess, "run",
                          return_value=subprocess.CompletedProcess([], 0, "node01|idle|two|3000\n", "")):
            result = node_preflight.inspect("node01", "/work", 1, 256, 5)
        self.assertEqual("unknown", result["status"])


if __name__ == "__main__":
    unittest.main()
