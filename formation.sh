#!/bin/bash

# 格式化分区

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main() {
    # 文件系统工具和特性选项可能随 Arch 安装环境中的工具版本变化。
    # 特别是 f2fs 的 -O 特性列表，需要和当前 mkfs.f2fs 支持项保持一致。
    mkfs.fat -F 32 "/dev/nvme0n1p1"
    mkfs.f2fs -f -O extra_attr,inode_checksum,sb_checksum,compression "/dev/nvme0n1p2"
    mkfs.xfs -f "/dev/sda1"
    mkfs.xfs -f "/dev/sda2"
    mkfs.xfs -f "/dev/sdb1"
    mkfs.ext4 -F "/dev/sdb2"
    mkfs.ext4 -F "/dev/sdc2"
    mkswap -f "/dev/sdc1"
}

if confirm "Quick format all partitions?"; then
    main
fi
