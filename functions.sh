#!/bin/bash

# 处理输入确认。
confirm() {
    local choice
    local tmp_choice

    while true; do
        read -rp "$1 [Y/n] " choice
        tmp_choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

        if [[ "$tmp_choice" == "y" || -z "$tmp_choice" ]]; then
            return 0
        elif [[ "$tmp_choice" == "n" ]]; then
            return 1
        fi
    done
}
