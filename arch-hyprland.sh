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

loadkeys es
reflector --country Spain --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Particionado automático
echo "[+] Borrando y creando particiones en $DISCO..."
sgdisk -Z "$DISCO"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISCO"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux" "$DISCO"

# Formateo
mkfs.fat -F32 "${DISCO}1"
mkfs.ext4 "${DISCO}2"

# Montaje
mount "${DISCO}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISCO}1" /mnt/boot/efi

# Instalación base
echo "[+] Instalando sistema base..."
pacstrap /mnt base base-devel linux linux-firmware networkmanager sudo git grub efibootmgr $EDITOR

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Contraseñas
read -s -p "Contraseña para root: " rootpass; echo
read -s -p "Confirma contraseña para root: " rootpass2; echo
[[ "$rootpass" != "$rootpass2" ]] && echo "No coinciden." && exit 1

read -s -p "Contraseña para $USUARIO: " userpass; echo
read -s -p "Confirma contraseña para $USUARIO: " userpass2; echo
[[ "$userpass" != "$userpass2" ]] && echo "No coinciden." && exit 1

echo "root:$rootpass" > /mnt/rootpass
echo "$USUARIO:$userpass" > /mnt/userpass
unset rootpass rootpass2 userpass userpass2

# Script en chroot
arch-chroot /mnt /bin/bash <<EOF
set -e
echo "[+] Configurando zona horaria, idioma y red..."
ln -sf /usr/share/zoneinfo/$REGION /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Contraseñas y usuario
echo "[+] Aplicando contraseñas..."
chpasswd < /rootpass
useradd -m -G wheel -s /bin/bash "$USUARIO"
chpasswd < /userpass
rm /rootpass /userpass

# Sudo
echo "[+] Habilitando sudo para grupo wheel..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# GRUB
echo "[+] Instalando GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# NetworkManager
systemctl enable NetworkManager

# Chaotic-AUR (descarga keyring + mirrorlist)
echo "[+] Agregando Chaotic-AUR..."
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo '[chaotic-aur]' >> /etc/pacman.conf
echo 'Include = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf
pacman -Sy


# Hyprland y apps
echo "[+] Instalando entorno Hyprland..."
pacman -S --noconfirm hyprland-bin kitty waybar thunar network-manager-applet firefox ttf-font-awesome noto-fonts

# Instalar neofetch desde AUR
echo "[+] Instalando neofetch desde AUR (puede tardar)..."
sudo -u "$USUARIO" bash <<INNER
cd ~
git clone https://aur.archlinux.org/neofetch.git
cd neofetch
makepkg -si --noconfirm
cd ..
rm -rf neofetch
INNER

EOF

echo "[+] Instalación finalizada. \nReiniciando..."
umount -R /mnt
reboot
