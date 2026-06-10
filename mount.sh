#!/bin/bash

# 挂载分区部分

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main(){
    mount -o noatime,lazytime,background_gc=off,atgc,nodiscard,fsync_mode=nobarrier "/dev/nvme0n1p2" "/mnt"
    mount --mkdir "/dev/nvme0n1p1" "/mnt/boot"
    mount --mkdir "/dev/sda1" "/mnt/opt"
    mount --mkdir "/dev/sda2" "/mnt/home"
    mount --mkdir "/dev/sdb1" "/mnt/var"
    swapon "/dev/sdc1"
}

if confirm "Do you want to mount the partitions automatically?"
then
    main
fi
