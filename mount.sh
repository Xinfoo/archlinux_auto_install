#!/bin/bash

# 挂载分区

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main() {
    # f2fs 挂载参数依赖当前内核和 f2fs 驱动支持。
    # 如果未来 Arch 内核调整参数兼容性，优先检查这一行。
    mount -o noatime,lazytime,background_gc=off,atgc,nodiscard,fsync_mode=nobarrier "/dev/nvme0n1p2" "/mnt"

    mount --mkdir "/dev/nvme0n1p1" "/mnt/boot"
    mount --mkdir "/dev/sda1" "/mnt/opt"
    mount --mkdir "/dev/sda2" "/mnt/home"
    mount --mkdir "/dev/sdb1" "/mnt/var"
    swapon "/dev/sdc1"
}

if confirm "Do you want to mount the partitions automatically?"; then
    main
fi
