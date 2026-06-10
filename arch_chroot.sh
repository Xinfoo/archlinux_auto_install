#!/bin/bash

# 复制后续安装脚本并进入 chroot，退出时清理。

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$SRC_DIR/install2.sh" "/mnt/install.sh"
chmod a+x "/mnt/install.sh"

echo 'Please run ./install.sh to complete the subsequent installation.'

arch-chroot /mnt

rm "/mnt/install.sh"
