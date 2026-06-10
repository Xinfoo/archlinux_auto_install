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

ERROR_PACKAGE_INSTALL='Package installation failed, script exits...'


# -----------------------------------------------------------------------------
# 系统基础配置
# -----------------------------------------------------------------------------

echo 'Setting timezone...'
while true; do
    read -p '(Enter region/city e.g. "Asia/Shanghai"): ' REGION

    if ln -sf "/usr/share/zoneinfo/$REGION" "/etc/localtime" &> /dev/null; then
        echo 'Configuring hardware clock...'
        break
    else
        echo 'Timezone error: Specified timezone not found.Please re-enter.'
    fi
done

hwclock --systohc

echo 'Generating locale...'
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
sed -i 's/#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo 'LANG=zh_CN.UTF-8' > /etc/locale.conf

echo 'Setting hostname...'
read -p '(Enter hostname, usually uppercase with hyphens): ' HOSTNAME
echo "$HOSTNAME" > "/etc/hostname"

echo 'Configuring hosts file...'
echo "127.0.0.1        $HOSTNAME.localdomain $HOSTNAME" >> "/etc/hosts"

echo 'Configuring key board...'
echo "KEYMAP=us" > "/etc/vconsole.conf"

echo 'Set root password...'
while true; do
    if passwd root; then
        break
    else
        echo 'Please re-enter your root password...'
    fi
done


# -----------------------------------------------------------------------------
# 包管理器与基础软件
# -----------------------------------------------------------------------------

echo 'Configuring package manager...'
sed -i 's/#Color/Color/g' "/etc/pacman.conf"
sleep 1

echo 'Updating package lists...'
if pacman -Syy &> /dev/null; then
    echo 'Package lists updated successfully.'
else
    echo 'Package list update failed. Check network connection.'
    exit 1
fi

echo 'Installing zsh (5s delay)...'
sleep 5

# 包名随 Arch 仓库变化时，需要从这里开始核对。
pacman -S zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting grml-zsh-config --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

echo 'Installing network services (5s delay)...'
sleep 5
pacman -S networkmanager iwd dhcpcd iftop nethogs --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

echo 'Installing development tools (5s delay)...'
sleep 5
pacman -S git --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

echo 'Installing fonts (5s delay)...'
sleep 5
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-jetbrains-mono ttf-dejavu ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }


# -----------------------------------------------------------------------------
# 硬件驱动与桌面环境
# -----------------------------------------------------------------------------

echo 'Installing NVIDIA Driver (5s delay)...'
sleep 5

# Arch 的 mkinitcpio 默认 MODULES/HOOKS 行可能变化。
# 这里是精确字符串替换，若默认文件格式变化，需要手动检查。
sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' "/etc/mkinitcpio.conf"
sed -i 's/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)/g' "/etc/mkinitcpio.conf"

# NVIDIA 包名和推荐驱动组合可能随 Arch/NVIDIA 更新变化。
pacman -S nvidia-open-dkms nvidia-utils vdpauinfo --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

echo 'Installing Bluetooth Driver (5s delay)...'
sleep 5
pacman -S bluez bluez-utils wireless-regdb --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

echo 'Installing desktop environment (5s delay)...'

# plasma 组/包内容会随 KDE Plasma 在 Arch 中的打包方式变化。
pacman -S --needed --noconfirm plasma || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
pacman -S --needed --noconfirm konsole dolphin ark kate partitionmanager filelight kcalc gwenview okular kcharselect ksystemlog kompare k3b kid3 mpv haruna || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
pacman -S --needed --noconfirm fcitx5-im fcitx5-chinese-addons || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }

echo '
XMODIFIERS=@im=fcitx
ELECTRON_OZONE_PLATFORM_HINT=auto' >> "/etc/environment"

echo 'Installing additional tools (5s delay)...'
sleep 5

# 工具包名可能随 Arch 仓库变化，失败时优先核对这组包。
pacman -S --needed --noconfirm firewalld cups htop nvtop tmux cmus lynx unzip 7zip unrar wget aria2 usbutils man-pages-zh_cn || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }


# -----------------------------------------------------------------------------
# 系统服务配置
# -----------------------------------------------------------------------------

echo 'Configuring NetworkManager...'
sleep 1

# NetworkManager 配置项如果改名，WiFi 后端设置会失效。
echo '[device]
wifi.backend=iwd' > "/etc/NetworkManager/conf.d/wifi_backend.conf"

echo 'Configuring time synchronization...'
sleep 1

# systemd-timesyncd.conf 默认 NTP 行如果变化，这个替换会失效。
sed -i 's/#NTP=/NTP=cn.ntp.org.cn time.windows.com cn.pool.ntp.org time.cloudflare.com/g' "/etc/systemd/timesyncd.conf"

echo 'Disabling core dumps...'
sleep 1
mkdir "/etc/systemd/coredump.conf.d/"
sleep 1

echo '[Coredump]
Storage=none
ProcessSizeMax=0' > "/etc/systemd/coredump.conf.d/custom.conf"

echo 'Enabling services...'
sleep 2

# 服务名如果随包更新变化，需要在这里核对。
systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
systemctl enable bluetooth.service
systemctl enable fstrim.timer  # SSD优化
systemctl enable firewalld.service
systemctl enable cups.socket
systemctl enable sddm.service


# -----------------------------------------------------------------------------
# 可选软件与用户账户
# -----------------------------------------------------------------------------

echo 'Installing extra software...'

# 可选软件包名随 Arch 仓库变化时，优先核对这个数组。
EXTRA_SOFTWARE1=("alacritty" "neovim" "neovide" "lua51" "luarocks" "fd" "wl-clipboard" "chromium")
echo "${EXTRA_SOFTWARE1[@]}"

if confirm "Do you want to install these software?"; then
    pacman -S --noconfirm ${EXTRA_SOFTWARE1[@]}
fi

echo 'Creating user account...'
while true; do
    read -p 'Enter username: ' USER_NAME

    if [[ -z "$USER_NAME" ]]; then
        echo 'The username cannot be empty.'
    else
        break
    fi
done

useradd -m -G wheel -s /bin/zsh "$USER_NAME"

echo 'Set user password:'
while true; do
    if passwd "$USER_NAME"; then
        break
    else
        echo 'Please re-enter your password...'
    fi
done

echo 'Edit sudoers file by own (10s delay)...'
sleep 10
visudo


# -----------------------------------------------------------------------------
# 引导程序
# -----------------------------------------------------------------------------

echo 'Installing bootloader (5s delay)...'
sleep 5

# GRUB/UEFI 工具包名和 grub-install 参数兼容性需要随 Arch 更新留意。
pacman -S grub efibootmgr os-prober --noconfirm || { echo "$ERROR_PACKAGE_INSTALL"; exit 1; }
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id='Arch Linux' --removable || { echo "GRUB installation failed"; exit 1; }
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id='Arch Linux' || { echo "GRUB installation failed"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg


# -----------------------------------------------------------------------------
# 大型可选软件
# -----------------------------------------------------------------------------

echo 'Installing extra software...'

# 大型软件包名、JDK 版本包名、CUDA 打包方式都容易随 Arch 更新变化。
EXTRA_SOFTWARE2=("firefox" "firefox-i18n-zh-cn" "thunderbird" "thunderbird-i18n-zh-cn" "jdk25-openjdk" "r" "cuda" "geogebra" "gimp" "inkscape" "blender")
echo "${EXTRA_SOFTWARE2[@]}"

if confirm "Do you want to install these software?"; then
    pacman -S --noconfirm ${EXTRA_SOFTWARE2[@]}
fi

echo "Please manually execute exit to exit the chroot environment."
