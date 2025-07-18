#!/bin/bash
set -e

### CONFIGURACIONES ###
DISCO="/dev/sda"
USUARIO="irdy"
HOSTNAME="Bird-pc"
LOCALE="es_ES.UTF-8"
REGION="Europe/Madrid"
EDITOR="vim"
#------------------------------------------#

echo "[+] Formateando disco..."
wipefs -af $DISCO
sgdisk -Zo $DISCO

echo "[+] Creando particiones..."
parted $DISCO --script mklabel gpt \
 mkpart ESP fat32 1MiB 512MiB \
 set 1 esp on \
 mkpart primary ext4 512MiB 100%

EFI="${DISCO}1"
ROOT="${DISCO}2"

echo "[+] Formateando particiones..."
mkfs.fat -F32 $EFI
mkfs.ext4 -F $ROOT

echo "[+] Montando..."
mount $ROOT /mnt
mkdir /mnt/boot
mount $EFI /mnt/boot

echo "[+] Instalando sistema base..."
pacstrap -K /mnt base linux linux-firmware vim networkmanager sudo git base-devel

echo "[+] Generando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/$REGION /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts <<END
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME
END

echo "[+] Configurando usuario y sudo..."
useradd -mG wheel $USUARIO
echo "Establece contraseña para root:"
passwd
echo "Establece contraseña para $USUARIO:"
passwd $USUARIO
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[+] Instalando grub y red..."
pacman -S --noconfirm grub efibootmgr networkmanager $EDITOR

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager

echo "[+] Instalando Chaotic-AUR..."
pacman -S --noconfirm curl
curl -O https://aur.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst
curl -O https://aur.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst
pacman -U --noconfirm chaotic-keyring.pkg.tar.zst chaotic-mirrorlist.pkg.tar.zst
echo -e "[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf
pacman -Syu --noconfirm

echo "[+] Instalando Hyprland y herramientas..."
pacman -S --noconfirm hyprland kitty waybar dunst rofi network-manager-applet \
thunar tumbler thunar-archive-plugin thunar-volman gvfs xdg-desktop-portal-hyprland \
xdg-user-dirs pipewire wireplumber pipewire-audio pipewire-pulse \
pamixer brightnessctl wl-clipboard polkit-gnome ttf-jetbrains-mono neofetch unzip

EOF

echo "[+] Listo!"
umount -R /mnt
reboot
