#!/bin/bash

# 安装基本包并生成 fstab

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main() {
    # 基础包名和内核包名可能随 Arch 仓库变化。
    # 如果 pacstrap 失败，优先核对这里的包名和本地镜像完整性。
    pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode dosfstools f2fs-tools xfsprogs exfatprogs btrfs-progs ntfsprogs nano vi vim man-db man-pages texinfo

    genfstab -U /mnt >> /mnt/etc/fstab

    clear
    cat "/mnt/etc/fstab"

    if confirm "Is the fstab file generated correctly?"; then
        return 0
    else
        exit 2
    fi
}

main
