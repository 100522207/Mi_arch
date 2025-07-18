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
 mkpart ESP fat32 1MiB 513MiB \
 set 1 esp on \
 mkpart primary ext4 513MiB 100%

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
pacstrap -K /mnt base linux linux-firmware vim networkmanager sudo git base-devel bash-completion man-db man-pages less

echo "[+] Generando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF

echo "[+] Configurando zona horaria y locale..."
ln -sf /usr/share/zoneinfo/$REGION /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "[+] Configurando red..."
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts <<END
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME
END

echo "[+] Instalando GRUB y configurando red..."
pacman -S --noconfirm grub efibootmgr networkmanager $EDITOR

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager

echo "[+] Creando usuario..."
useradd -mG wheel $USUARIO

echo "[!] Establece la contraseña para root:"
passwd

echo "[!] Establece la contraseña para $USUARIO:"
passwd $USUARIO

echo "[+] Habilitando sudo para grupo wheel..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[+] Instalando Hyprland y herramientas..."
pacman -S --noconfirm hyprland kitty waybar dunst rofi network-manager-applet \
thunar tumbler thunar-archive-plugin thunar-volman gvfs \
xdg-user-dirs xdg-desktop-portal-hyprland \
pipewire wireplumber pipewire-audio pipewire-pulse \
pamixer brightnessctl wl-clipboard polkit-gnome ttf-jetbrains-mono neofetch unzip

EOF

echo "[+] Instalación finalizada. \nReiniciando..."
umount -R /mnt
reboot
