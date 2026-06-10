#!/bin/bash

# 恢复分区表部分

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

main(){
    sfdisk "/dev/nvme0n1" < "$SRC_DIR/partition_table/partition_nvme0n1.txt"
    sfdisk "/dev/sda" < "$SRC_DIR/partition_table/partition_sda.txt"
    sfdisk "/dev/sdb" < "$SRC_DIR/partition_table/partition_sdb.txt"
    sfdisk "/dev/sdc" < "$SRC_DIR/partition_table/partition_sdc.txt"
}

if confirm "Reconstruct the current partition table using the backed-up partition table?"
then
    main
fi
