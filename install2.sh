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

# 包安装错误信息
ERROR_PACKAGE_INSTALL='Package installation failed, script exits...'

# 系统基础配置阶段
# 设置时区
echo 'Setting timezone...'
while true
do
    read -p '(Enter region/city e.g. "Asia/Shanghai"): ' REGION
    # 创建时区软链接
    if ln -sf "/usr/share/zoneinfo/$REGION" "/etc/localtime" &> /dev/null
    then
        echo 'Configuring hardware clock...'
        break
    else
        echo 'Timezone error: Specified timezone not found.Please re-enter.'
    fi
done
# 同步硬件时钟
hwclock --systohc

# 设置本地化
echo 'Generating locale...'
# 启用英文UTF-8本地化
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
# 启用中文UTF-8本地化
sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/g' /etc/locale.gen
# 生成本地化文件
locale-gen
# 设置系统默认语言为中文
echo 'LANG=zh_CN.UTF-8' > /etc/locale.conf

# 设置主机名与hosts文件
echo 'Setting hostname...'
read -p '(Enter hostname, usually uppercase with hyphens): ' HOSTNAME
# 写入主机名
echo "$HOSTNAME" > "/etc/hostname"
echo 'Configuring hosts file...'
# 配置本地hosts解析
echo "127.0.0.1        $HOSTNAME.localdomain $HOSTNAME" >> "/etc/hosts"

# 设置Root密码
echo 'Set root password...'
while true
do
    if passwd root
    then
        break
    else
        echo 'Please re-enter your root password...'
    fi
done

# 配置包管理器
echo 'Configuring package manager...'
# 启用pacman彩色输出
sed -i 's/#Color/Color/g' "/etc/pacman.conf"
sleep 1
echo 'Updating package lists...'
# 更新包数据库
if pacman -Syy &> /dev/null
then
    echo 'Package lists updated successfully.'
else
    echo 'Package list update failed. Check network connection.'
    exit 1
fi

# 安装Z-shell及其相关组件
echo 'Installing zsh (2s delay)...'
sleep 2
pacman -S zsh zsh-completions grml-zsh-config --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 安装网络工具和服务
echo 'Installing network services (5s delay)...'
sleep 5
pacman -S networkmanager iwd dhcpcd iftop nethogs --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 安装开发工具
echo 'Installing development tools (5s delay)...'
sleep 5
pacman -S gdb git --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 安装字体包
echo 'Installing fonts (5s delay)...'
sleep 5
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-jetbrains-mono ttf-dejavu ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 安装英伟达显卡驱动
echo 'Installing NVIDIA Driver (5s delay)...'
sleep 5
sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' "/etc/mkinitcpio.conf"
sed -i 's/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)/g' "/etc/mkinitcpio.conf"
pacman -S nvidia-open-dkms nvidia-utils vdpauinfo --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 安装蓝牙支持
echo 'Installing Bluetooth Driver (5s delay)...'
sleep 5
pacman -S bluez bluez-utils wireless-regdb --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 安装桌面环境
echo 'Installing desktop environment (5s delay)...'
pacman -S --needed --noconfirm plasma || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
pacman -S --needed --noconfirm konsole dolphin ark kate partitionmanager filelight spectacle kcalc gwenview okular kcharselect ksystemlog kompare k3b kid3 mpv haruna || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
pacman -S --needed --noconfirm fcitx5-im fcitx5-chinese-addons || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
echo '
XMODIFIERS=@im=fcitx
ELECTRON_OZONE_PLATFORM_HINT=auto' >> "/etc/environment"

# 安装系统工具
echo 'Installing additional tools (5s delay)...'
sleep 5
pacman -S --needed --noconfirm firewalld cups htop nvtop tmux cmus lynx unzip 7zip unrar wget aria2 usbutils man-pages-zh_cn || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

# 配置网络管理器
echo 'Configuring NetworkManager...'
sleep 1
# 设置NetworkManager使用iwd作为WiFi后端
echo '[device]
wifi.backend=iwd' > "/etc/NetworkManager/conf.d/wifi_backend.conf"

# 配置网络时间同步
echo 'Configuring time synchronization...'
sleep 1
# 设置NTP时间服务器（中国境内优化）
sed -i 's/#NTP=/NTP=cn.ntp.org.cn time.windows.com cn.pool.ntp.org time.cloudflare.com/g' "/etc/systemd/timesyncd.conf"

# 禁用核心转储以节省磁盘空间和提高安全性
echo 'Disabling core dumps...'
sleep 1
mkdir "/etc/systemd/coredump.conf.d/"
sleep 1
echo '[Coredump]
Storage=none
ProcessSizeMax=0' > "/etc/systemd/coredump.conf.d/custom.conf"

# 启用系统服务
echo 'Enabling services...'
sleep 2
systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
systemctl enable bluetooth.service
systemctl enable fstrim.timer  # SSD优化
systemctl enable firewalld.service
systemctl enable cups.socket
systemctl enable sddm.service

# 安装第一组额外软件
echo 'Installing extra software...'
EXTRA_SOFTWARE1=("alacritty" "neovim" "neovide" "lua51" "luarocks" "ripgrep" "fd" "wl-clipboard" "chromium")
echo "${EXTRA_SOFTWARE1[@]}"
if confirm "Do you want to install these software?"
then
    pacman -S --noconfirm ${EXTRA_SOFTWARE1[@]}
fi

# 创建普通用户账户
echo 'Creating user account...'
while true
do
    read -p 'Enter username: ' USER_NAME
    if [[ -z "$USER_NAME" ]]
    then
        echo 'The username cannot be empty.'
    else
        break
    fi
done
# 创建用户，添加到wheel组，使用zsh作为默认shell
useradd -m -G wheel -s /bin/zsh "$USER_NAME"
echo 'Set user password:'
while true
do
    if passwd "$USER_NAME"
    then
        break
    else
        echo 'Please re-enter your password...'
    fi
done

# 配置sudo权限
echo 'Edit sudoers file by own (10s delay)...'
sleep 10
# 手动编辑sudoers文件，为用户授予权限
visudo

# 安装引导程序
echo 'Installing bootloader (5s delay)...'
sleep 5
pacman -S grub efibootmgr os-prober --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id='Arch Linux' --removable || { echo "GRUB installation failed"; exit 1; }
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id='Arch Linux' || { echo "GRUB installation failed"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg

# 安装第二组额外软件
echo 'Installing extra software...'
EXTRA_SOFTWARE2=("firefox" "firefox-i18n-zh-cn" "thunderbird" "thunderbird-i18n-zh-cn" "jdk25-openjdk" "r" "cuda" "geogebra" "gimp" "inkscape" "blender")
echo "${EXTRA_SOFTWARE2[@]}"
if confirm "Do you want to install these software?"
then
    pacman -S --noconfirm ${EXTRA_SOFTWARE2[@]}
fi

# 安装完成提示
echo "Please manually execute exit to exit the chroot environment."

