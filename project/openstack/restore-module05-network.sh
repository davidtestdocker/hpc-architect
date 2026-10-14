#!/usr/bin/env bash
# 在 openstack-lab01 以 root 執行，恢復模組 05 的宿主機網路設定。
# 用法：sudo bash restore-module05-network.sh；重跑只補缺少的位址與規則。
# 執行前須確認這台仍是 10.146.0.4、DevStack 的 br-ex 已存在，
# compute-cpu01 的 172.24.4.121 浮動 IP 關聯仍指向 10.0.0.32。
# 副作用：啟用 br-ex、設定 172.24.4.1/24、開啟 IPv4 轉送，
# 並在記憶體中加入兩條來源轉址和一條 TCP 6818 目的轉址規則。

set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    printf '請以 root 執行\n' >&2
    exit 1
fi

if ! ip -4 addr show dev ens4 | grep -Fq 'inet 10.146.0.4/'; then
    printf 'ens4 沒有預期的 10.146.0.4，停止以免套用到其他主機\n' >&2
    exit 1
fi

if ! ip link show dev br-ex >/dev/null 2>&1; then
    printf 'br-ex 不存在；請先確認 DevStack 網路服務已啟動\n' >&2
    exit 1
fi

if ! ip -4 addr show dev br-ex | grep -Eq 'inet 172\.24\.4\.1/24([[:space:]]|$)'; then
    ip addr add 172.24.4.1/24 dev br-ex
fi
ip link set dev br-ex up

if [[ $(sysctl -n net.ipv4.ip_forward) != 1 ]]; then
    sysctl -w net.ipv4.ip_forward=1
fi

# 只轉換 router1 的外側位址，讓 CPU 客體可連回 GCP 控制節點。
if ! iptables -w -t nat -C POSTROUTING -s 172.24.4.9/32 -o ens4 -j MASQUERADE 2>/dev/null; then
    iptables -w -t nat -A POSTROUTING -s 172.24.4.9/32 -o ens4 -j MASQUERADE
fi

# 控制節點連宿主機 TCP 6818 時，將目的轉向 CPU 客體的浮動 IP。
if ! iptables -w -t nat -C PREROUTING -i ens4 -s 10.140.0.2/32 -d 10.146.0.4/32 -p tcp --dport 6818 -j DNAT --to-destination 172.24.4.121:6818 2>/dev/null; then
    iptables -w -t nat -A PREROUTING -i ens4 -s 10.140.0.2/32 -d 10.146.0.4/32 -p tcp --dport 6818 -j DNAT --to-destination 172.24.4.121:6818
fi

# 浮動 IP 作為客體出站來源時，轉成宿主機 ens4 位址以取得 GCP 回程。
if ! iptables -w -t nat -C POSTROUTING -s 172.24.4.121/32 -o ens4 -j MASQUERADE 2>/dev/null; then
    iptables -w -t nat -A POSTROUTING -s 172.24.4.121/32 -o ens4 -j MASQUERADE
fi

printf '宿主機網路規則已恢復或原本存在；仍須從控制節點驗證 Slurm 工作。\n'
