#!/bin/bash

# 安装基本包并生成fstab

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main(){
    pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware intel-ucode dosfstools f2fs-tools xfsprogs exfatprogs btrfs-progs ntfsprogs nano vi vim man-db man-pages texinfo
    genfstab -U /mnt >> /mnt/etc/fstab
    clear
    cat "/mnt/etc/fstab"
    if confirm "Is the fstab file generated correctly?"
    then
        return 0
    else
        exit 2
    fi
}

main
