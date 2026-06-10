#!/bin/bash

# 复制脚本并进入chroot，退出时清理

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$SRC_DIR/install2.sh" "/mnt/root/install.sh"
chmod a+x "/mnt/root/install.sh"
echo 'Please run ./install.sh to complete the subsequent installation.'
arch-chroot /mnt
rm "/mnt/root/install.sh"
