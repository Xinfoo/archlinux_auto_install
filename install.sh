#!/bin/bash

# 主入口：按顺序执行安装阶段。
# 注意：这里保留原有调用方式，不改变脚本逻辑。

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

./"$SRC_DIR/partition.sh"
./"$SRC_DIR/formation.sh"
./"$SRC_DIR/mount.sh"
./"$SRC_DIR/use_local_source.sh"
./"$SRC_DIR/install1.sh"
./"$SRC_DIR/arch_chroot.sh"
