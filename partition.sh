#!/bin/bash

# 恢复分区表

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main() {
    # 强依赖当前机器的设备名和分区表文件。
    # 如果 Arch Live 环境中的磁盘枚举顺序变化，这里需要人工确认。
    sfdisk "/dev/nvme0n1" < "$SRC_DIR/partition_table/partition_nvme0n1.txt"
    sfdisk "/dev/sda" < "$SRC_DIR/partition_table/partition_sda.txt"
    sfdisk "/dev/sdb" < "$SRC_DIR/partition_table/partition_sdb.txt"
    sfdisk "/dev/sdc" < "$SRC_DIR/partition_table/partition_sdc.txt"
}

if confirm "Reconstruct the current partition table using the backed-up partition table?"; then
    main
fi
