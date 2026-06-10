#!/bin/bash

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC_DIR/functions.sh"

./"$SRC_DIR/partition.sh"
./"$SRC_DIR/formation.sh"
./"$SRC_DIR/mount.sh"
./"$SRC_DIR/use_local_source.sh"
