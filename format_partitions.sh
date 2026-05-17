#!/bin/bash

source "functions.sh"

# 询问是否已完成磁盘分区
echo
echo 'NOTE: The following operations require pre-partitioned disks.'
if confirm "Have you partitioned the disk?"
then
    echo 'Partitioning confirmed, proceeding to next step...'
else
    echo 'Manual partitioning not performed, script exits.'
    exit 1
fi

# 检查磁盘布局
echo
echo 'Disk verification starting in 5 seconds...'
echo 'Press "q" to exit.'
sleep 5
sfdisk -l | less
if confirm "Are the disks correct?"
then
    echo 'Disks verified, proceeding to next step...'
else
    echo 'Disk error detected, script exits.'
    exit 1
fi

# 检查分区布局
echo
echo 'Please verify partition layout...'
sfdisk -l -o Device,Size,Type | grep -P '^\s*(Device|/dev/)'
if confirm "Are the partitions correct?"
then
    echo 'Partitions verified, select mount points as prompted...'
else
    echo 'Partition error detected, script exits.'
    exit 1
fi

# 获取磁盘列表 (排除分区)
DISK_LIST=$(cat /proc/partitions | awk 'NR > 2 {print $4}' | grep -E "^hd[a-z]$|^sd[a-z]$|^nvme[0-9]n[0-9]$")

# 获取分区列表
PARTITION_LIST=$(cat /proc/partitions | awk 'NR > 2 {print $4}' | grep -E "^hd[a-z][0-9]$|^sd[a-z][0-9]$|^nvme[0-9]n[0-9]p[0-9]$")

# 将磁盘列表转为数组
readarray -t DISK_LIST <<< "$DISK_LIST"

# 将分区列表转为数组
readarray -t PARTITION_LIST <<< "$PARTITION_LIST"

# 排除可移动设备
TMP_LIST=()
for disk in "${DISK_LIST[@]}"
do
    removable=$(cat "/sys/block/$disk/removable")
    if [[ "$removable" == "0" ]]
    then
        # 只添加不可移动设备的分区
        for partition in "${PARTITION_LIST[@]}"
        do
            if [[ "$partition" =~ ^"$disk" ]]
            then
                TMP_LIST+=("$partition")
            fi
        done
    else
        continue
    fi
done
PARTITION_LIST=("${TMP_LIST[@]}")

# 选择要使用的磁盘分区并添加/dev前缀
while true
do
    TMP_LIST=()
    for choice_partition in "${PARTITION_LIST[@]}"
    do
        clear
        sfdisk -l -o Device,Size,Type | grep -P '^\s*(Device|/dev/)'
        if confirm "Do you want to use the disk partition /dev/$choice_partition ?"
        then
            TMP_LIST+=("/dev/$choice_partition")
        fi
    done
    # 确保至少选择2个分区
    if [[ "${#TMP_LIST[@]}" -ge "2" ]]
    then
        echo "${#TMP_LIST[@]} partitions have been selected."
    else
        echo 'The number of selected partitions cannot be less than 2. Please re-enter...'
        continue
    fi
    clear
    echo "You have selected these partitions."
    printf "%s\n" "${TMP_LIST[@]}"
    if confirm "Do you want to select these partitions? Press 'n' to reselect."
    then
        PARTITION_LIST=("${TMP_LIST[@]}")
        break
    else
        echo 'Reselect the partitions...'
    fi
done

# 选择挂载点和格式化文件系统
PS3="Input a number: "
FS_LIST=("ext4" "xfs" "f2fs" "vfat")
declare -A MOUNT_POINT  # 存储挂载点映射
declare -A PARTITION_FS # 存储文件系统选择

# 选择根分区 (/) 
clear
list_partitions
echo 'Please select the partition you want to assign to the root directory...'
select root_mount_point in "${PARTITION_LIST[@]}"
do
    if [[ -n "$root_mount_point" ]]
    then
        MOUNT_POINT["ROOT"]="$root_mount_point"
        echo 'What file system do you want to format this partition with?'
        select fs_choice in "${FS_LIST[@]}"
        do
            if [[ -n "$fs_choice" ]]
            then
                PARTITION_FS["$root_mount_point"]="$fs_choice"
                break
            fi
        done
        # 从可用分区列表中移除已选择的分区
        TMP_LIST=()
        for unused_partition in "${PARTITION_LIST[@]}"
        do
            if [[ "$root_mount_point" != "$unused_partition" ]]
            then
                TMP_LIST+=("$unused_partition")
            fi
        done
        PARTITION_LIST=("${TMP_LIST[@]}")
        break
    fi
done

# 选择启动分区 (/boot)
clear
list_partitions
echo 'Please select the partition you want to assign to the boot directory...'
select boot_mount_point in "${PARTITION_LIST[@]}"
do
    if [[ -n "$boot_mount_point" ]]
    then
        MOUNT_POINT["BOOT"]="$boot_mount_point"
        # 询问是否格式化启动分区
        if confirm "Do you want to format the boot partition? This may damage the boot loaders of other systems."
        then
            PARTITION_FS["$boot_mount_point"]="vfat"
            echo 'The boot partition will be formatted.'
        else
            echo 'The boot partition will not be formatted.'
        fi
        TMP_LIST=()
        for unused_partition in "${PARTITION_LIST[@]}"
        do
            if [[ "$boot_mount_point" != "$unused_partition" ]]
            then
                TMP_LIST+=("$unused_partition")
            fi
        done
        PARTITION_LIST=("${TMP_LIST[@]}")
        break
    fi
done
echo 'Wait for 3 seconds...'
sleep 3

# 选择交换分区 (SWAP)
if [[ "${#PARTITION_LIST[@]}" != "0" ]]
then
    clear
    if confirm "Do you want to enable the SWAP partition?"
    then
        clear
        list_partitions
        echo 'Please select the partition you want to mount to SWAP.'
        select swap_partition in "${PARTITION_LIST[@]}"
        do
            if [[ -n "$swap_partition" ]]
            then
                MOUNT_POINT["SWAP"]="$swap_partition"
                PARTITION_FS["$swap_partition"]="swap"
                TMP_LIST=()
                for unused_partition in "${PARTITION_LIST[@]}"
                do
                    if [[ "$swap_partition" != "$unused_partition" ]]
                    then
                        TMP_LIST+=("$unused_partition")
                    fi
                done
                PARTITION_LIST=("${TMP_LIST[@]}")
                break
            fi
        done
    fi
fi

# 其他可选的挂载点 (/home, /opt, /var)
OPTIONAL_MOUNT_POINT=("HOME" "OPT" "VAR")
for optional_mount_point in "${OPTIONAL_MOUNT_POINT[@]}"
do
    if [[ "${#PARTITION_LIST[@]}" == "0" ]]
    then
        continue
    fi
    clear
    lower_optional_mount_point=$(echo "$optional_mount_point" | tr '[:upper:]' '[:lower:]')
    if confirm "Do you want to mount /$lower_optional_mount_point to a partition?"
    then
        clear
        list_partitions
        echo "Please select the partition you want to assign to the $lower_optional_mount_point directory..."
        select mount_point_options in "${PARTITION_LIST[@]}"
        do
            if [[ -n "$mount_point_options" ]]
            then
                MOUNT_POINT["$optional_mount_point"]="$mount_point_options"
                echo 'What file system do you want to format this partition with?'
                select fs_choice in "${FS_LIST[@]}"
                do
                    if [[ -n "$fs_choice" ]]
                    then
                        PARTITION_FS["$mount_point_options"]="$fs_choice"
                        break
                    fi
                done
                TMP_LIST=()
                for unused_partition in "${PARTITION_LIST[@]}"
                do
                    if [[ "$mount_point_options" != "$unused_partition" ]]
                    then
                        TMP_LIST+=("$unused_partition")
                    fi
                done
                PARTITION_LIST=("${TMP_LIST[@]}")
                break
            fi
        done
    fi
done

# 最终配置确认
clear
echo 'Your partition will be formatted as...'
list_partitions
if confirm "Is the above configuration correct?"
then
    if confirm "Confirm hard drive formatting? Data will be unrecoverable."
    then
        echo 'The disk will be formatted, waiting for 5 seconds...'
        sleep 5
    else
        echo 'The formatting is not confirmed, so the script exits.'
        exit 1
    fi
else
    echo 'Configuration error, script exited.'
    exit 1
fi

# 格式化分区阶段
ERROR_FORMAT='An error occurred during partition formatting, and the script exited.'
for partition in "${!PARTITION_FS[@]}"
do
    case ${PARTITION_FS[$partition]} in
        "ext4")
            mkfs.ext4 -F "$partition" || { echo "$ERROR_FORMAT"; exit 1; }
            ;;
        "xfs")
            mkfs.xfs -f "$partition" || { echo "$ERROR_FORMAT"; exit 1; }
            ;;
        "f2fs")
            mkfs.f2fs -f -O extra_attr,inode_checksum,sb_checksum,compression "$partition" || { echo "$ERROR_FORMAT"; exit 1; }
            ;;
        "vfat")
            mkfs.fat -F 32 "$partition" || { echo "$ERROR_FORMAT"; exit 1; }
            ;;
        "swap")
            mkswap -f "$partition" || { echo "$ERROR_FORMAT"; exit 1; }
            ;;
    esac
done

# 挂载分区阶段
ERROR_MOUNT='An error occurred during partition mounting, and the script exited.'

# 挂载根分区
mount "${MOUNT_POINT["ROOT"]}" "/mnt" || { echo "$ERROR_MOUNT"; exit 1; }

# 挂载其他分区
for mount_point in "${!MOUNT_POINT[@]}"
do
    partition="${MOUNT_POINT[$mount_point]}"
    case $mount_point in
        "ROOT")
            continue  # 根分区已经挂载
            ;;
        "BOOT")
            mount --mkdir "$partition" "/mnt/boot" || { echo "$ERROR_MOUNT"; exit 1; }
            ;;
        "VAR")
            mount --mkdir "$partition" "/mnt/var" || { echo "$ERROR_MOUNT"; exit 1; }
            ;;
        "OPT")
            mount --mkdir "$partition" "/mnt/opt" || { echo "$ERROR_MOUNT"; exit 1; }
            ;;
        "HOME")
            mount --mkdir "$partition" "/mnt/home" || { echo "$ERROR_MOUNT"; exit 1; }
            ;;
        "SWAP")
            swapon "$partition" || { echo "$ERROR_MOUNT"; exit 1; }
            ;;
    esac
done
