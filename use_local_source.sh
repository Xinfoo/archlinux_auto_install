#!/bin/bash
set -e

# 获取磁盘路径为数组
devices=($(blkid -t LABEL="F2FS-DATA" -o device))

# 同名磁盘检测
if [[ ${#devices[@]} -ne 1 ]]; then
    echo "Error: expected exactly one partition with label F2FS-DATA, found ${#devices[@]}" >&2
    exit 1
fi

# 定义变量
SOURCE_PARTITION="${devices[0]}"
echo "The disk where the detected local mirror source is located: $SOURCE_PARTITION"

# 挂载分区
mount --mkdir "$SOURCE_PARTITION" "/run/media/root/F2FS-DATA"

# 关闭签名校验
sed -i 's/SigLevel    = Required DatabaseOptional/SigLevel    = Never/g' "/etc/pacman.conf"

# 修改为文件镜像源
echo 'Server = file:///run/media/root/F2FS-DATA/repo/archlinux/$repo/os/$arch' > "/etc/pacman.d/mirrorlist"
pacman -Syy &> /dev/null

# 配置 nginx
echo "Configuring Nginx..."
pacman -S --noconfirm nginx &> /dev/null
mkdir -p "/etc/nginx/conf.d"
sed -i '/http {/a\    include       conf.d/*.conf;' "/etc/nginx/nginx.conf"
echo '
types_hash_max_size 4096;
types_hash_bucket_size 128;
server {
    # 监听端口
    listen 2304;

    # 本地镜像源目录
    root /run/media/root/F2FS-DATA/repo/archlinux;

    autoindex on;
    autoindex_exact_size on;
    autoindex_localtime on;

    location / {
        try_files $uri $uri/ =404;
    }
}
' > "/etc/nginx/conf.d/local_mirror.conf"
nginx
echo "Nginx configuration is completed."

# 修改为 nginx 本地镜像源
echo 'Server = http://127.0.0.1:2304/$repo/os/$arch' > "/etc/pacman.d/mirrorlist"
pacman -Syy &> /dev/null
echo "Local mirror site set up successfully."
