#!/bin/bash

# 处理输入确认
confirm() {
    local choice
    local tmp_choice
    while true
    do
        read -rp "$1 [Y/n] " choice
        tmp_choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [[ "$tmp_choice" == "y" || -z "$tmp_choice" ]]
        then
            return 0
        elif [[ "$tmp_choice" == "n" ]]
        then
            return 1
        fi
    done
}

# 列出分区并显示所有可用分区及其状态
list_partitions() {
    # 使用数组收集所有输出行
    local output_lines=()
    output_lines+=("$(printf "%-16s %-16s %-8s %-20s" "Device" "FSType" "Size" "Status")")
    
    while IFS= read -r line
    do
        local device fstype size mountpoint
        read -r device fstype size mountpoint <<< "$line"
        
        # 处理未格式化的分区
        if [[ -z "$fstype" ]]
        then
            fstype="NONE"
        fi
        
        local status="" assigned_mount=""
        
        # 检查分区是否已被分配挂载点
        for mount_point in "${!MOUNT_POINT[@]}"
        do
            if [[ "${MOUNT_POINT[$mount_point]}" == "$device" ]]
            then
                assigned_mount="$mount_point"
                status="Assigned"
                break
            fi
        done
        
        # 如果未分配，检查是否为可用分区
        if [[ -z "$status" ]]
        then
            for available_device in "${PARTITION_LIST[@]}"
            do
                if [[ "$available_device" == "$device" ]]
                then
                    status="Available"
                    break
                fi
            done
        fi
        
        [[ -z "$status" ]] && continue
        
        # 检查是否有用户选择的文件系统
        local new_fs=""
        if [[ -n "${PARTITION_FS[$device]}" ]]
        then
            new_fs=" => ${PARTITION_FS[$device]}"
        fi
        
        # 检查分区是否已挂载
        local mount_status=""
        [[ -n "$mountpoint" ]] && mount_status=" WARNING: MOUNTED"
        
        local output_line=$(printf "%-16s %-16s %-8s %-20s" "$device" "${fstype}${new_fs}" "$size" "${status}(${assigned_mount})${mount_status}")
        output_lines+=("$output_line")
        
    done < <(lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT -r -n | awk '$1 ~ /(sd[a-z][0-9]|nvme[0-9]n[0-9]p[0-9]|hd[a-z][0-9])/ {print "/dev/" $1, $2, $3, $4}')
    
    # 计算最长行的长度
    local max_length=0
    for line in "${output_lines[@]}"
    do
        local line_length=${#line}
        if [[ $line_length -gt $max_length ]]
        then
            max_length=$line_length
        fi
    done
    
    # 生成动态分隔线
    local separator=""
    for ((i=0; i<max_length; i++))
    do
        separator+="="
    done
    
    # 输出最终结果
    echo "$separator"
    for line in "${output_lines[@]}"
    do
        echo "$line"
    done
    echo "$separator"
}
