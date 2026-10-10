#!/usr/bin/env python3
"""在 DevStack 主機產生含隨機密碼的 local.conf，不把密碼寫回工作樹。"""

import argparse
import os
from pathlib import Path
import secrets


def main() -> None:
    """收取 DevStack 目錄及主機 IP，建立只有檔案擁有者可讀的設定檔。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("devstack_dir", type=Path, help="已下載的 DevStack 目錄")
    parser.add_argument("host_ip", help="此 VM 的私有 IP")
    args = parser.parse_args()

    target = args.devstack_dir / "local.conf"
    if not (args.devstack_dir / "stack.sh").is_file():
        parser.error("DevStack 目錄中找不到 stack.sh")
    if target.exists():
        parser.error(f"設定檔已存在，不覆寫：{target}")

    # local.conf 會由 stack.sh 讀取；限定權限並只在 VM 上產生密碼。
    password = secrets.token_hex(20)
    content = (
        "[[local|localrc]]\n"
        f"HOST_IP={args.host_ip}\n"
        "LIBVIRT_TYPE=qemu\n"
        f"ADMIN_PASSWORD={password}\n"
        "DATABASE_PASSWORD=$ADMIN_PASSWORD\n"
        "RABBIT_PASSWORD=$ADMIN_PASSWORD\n"
        "SERVICE_PASSWORD=$ADMIN_PASSWORD\n"
    )
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as config:
        config.write(content)
    print(f"created {target} (mode 600)")


if __name__ == "__main__":
    main()
