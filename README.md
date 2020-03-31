# ArchLinux Installation
Dieser Guide basiert auf verschiedenen Informationen
der [ArchWiki-Webseite](https://wiki.archlinux.org/).

## Vorbereitung
### Allgemeines

> **Laden des benötigten Tastaturlayouts:**
```bash
loadkeys de-latin1
```
Wird nur für die komfortablere Eingabe auf der Tastatur verwendet.
Als Standard ist die englische QWERTY-Tastatur eingestellt.

> **Prüfen, ob im UEFI-Modus gebootet wurde:**
```bash
ls /sys/firmware/efi/efivars
```
Wenn Einträge vorhanden sind, kann fortgefahren werden.
Ansonsten wurde im BIOS-Modus gebootet.

### Internetverbindung herstellen
> **Name des Netzwerkadapters ermitteln:**
```bash
ip link
```
Die Ausgabe des Befehls ist auszuwerten.

> **Netzwerkverbindung herstellen:**
```bash
cp /etc/netctl/examples/wireless-wpa-static /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
nano /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
netctl start <Netzwerkadapter>-<WLAN-SSID>
```

> **Internetverbindung prüfen**
```bash
ping 1.1.1.1
```

> **Netzwerkzeit beziehen**
```bash
timedatectl set-ntp true
timedatectl status
```

### Festplatte löschen
> **Daten auf der Festplatte mit Random-Daten überschreiben**
```bash
dd if=/dev/urandom of=/dev/<GerätFP> bs=4096 status=progress
```

## Installation
### Partitionierung und Dateisysteme
> **Partitionierung**
```bash
gdisk /dev/<GerätFP>
```
efi Partition (`ef00`), root Partition\
für root Partition:
```bash
cryptsetup -y -v --type luks1 --cipher aes-xts-plain64 --key-size 512 --hash sha256 --iter-time 2000 --use-urandom luksFormat /dev/<rootPart>
cryptsetup open /dev/<rootPart> cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```
für efi Partition:
```bash
mkfs.fat -F32 /dev/<efiPart>
mkdir /mnt/efi
mount /dev/<efiPart> /mnt/efi
```

### Installation des Basissystems
> **Package-Mirrors**
```bash
nano /etc/pacman.d/mirrorlist
```
Anpassen, sodass nur noch deutsche Mirror vorhanden

> **Basissystem übertragen**
```bash
pacstrap /mnt base linux dkms linux-firmware nano
```

> **Mounttable**
```bash
genfstab /mnt >> /mnt/etc/genfstab
cat /mnt/etc/fstab
```

> **root wechseln**
```bash
arch-chroot /mnt
```

### Konfiguration des Basissystems
> **Zeit und Lokalisierung**
```bash
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --sysothc
nano /etc/locale.gen
```
einkommentieren von: `en_US.UTF-8 UTF-8` (minimal) und `de_DE.UTF-8 UTF-8`
```bash
locale-gen
nano /etc/locale.conf
```
Inhalt: `LANG=de_DE.UTF-8`
```bash
nano /etc/vconsole.conf
```
Inhalt: `KEYMAP=de-latin1`

> **Netzwerk**
```bash
nano /etc/hostname
```
Inhalt: `<hostname>`
```bash
nano /etc/hosts
```
Inhalt:
```text
127.0.0.1 localhost
::1 localhost
127.0.1.1 <hostname>.localdomain <hostname>
```
Installation von Netzwerkmanagern
```bash
pacman -S netctl systemd-resolvconf wpa-supplicant
```
Fix für netctl / systemd (möglicherweise nicht mehr relevant):
```bash
ln -s /usr/lib/systemd/system/systemd-resolve.service /usr/lib/systemd/system/dbus-org.freedesktop.resolve1.service
```
```bash
cp /etc/netctl/examples/wireless-wpa-static /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
wpa_passphrase <SSID> <Password> >> /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
nano /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
```

> **Initramfs**
```bash
nano /etc/mkinitcpio.conf
```
Inhalt anpassen:
```text
HOOKS=(base systemd autodetect keyboard sd-console modconf block sd-encrypt filesystems fsck)
```
```bash
mkinitcpio -p linux
```

> **Bootloader GRUB 2**
```bash
pacman -S grub efibootmgr
lsblk -f
```
`UUID` der verschlüsselten Partition merken `<UUID>`
```bash
nano /etc/default/grub
```
Inhalt anpassen:
```text
GRUB_ENABLE_CRYPTODISK=y
GRUB_TIMEOUT=1
GRUB_CMDLINE_LINUX="rd.luks.name=<UUID>=cryptroot root=/dev/mapper/cryptroot rd.luks.options=<UUID>=cipher=aes-xts-plain64:sha256,size=512"
```

> **Keyfile**\
um nur einmal das Passwort beim Startvorgang angeben zu müssen
```bash
dd bs=512 count=4 if=/dev/random of=/crypto_keyfile.bin iflag=fullblock
chmod 600 /crypto_keyfile.bin
chmod 600 /boot/initramfs-linux *
cryptsetup luksAddKey /dev/<luksPart>/crypto_keyfile.bin
nano /etc/mkinitcpio.conf
```
Inhalt anpassen:
```text
FILES=(/crypto_keyfile.bin)
```
```bash
mkinitcpio -p linux
nano /etc/default/grub
```
Inhalt anpassen:
```text
rd.luks.key=<UUID>=/crypto_keyfile.bin
```

> **GRUB Installation**
```bash
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

> **Microcode**
```bash
pacman -S intel-ucode
grub-mkconfig -o /boot/grub/grub.cfg
```

> **Erster Neustart**\
Test für Bootloader und alle installierten Komponenten
```bash
exit
umount -R /mount
reboot
```

## Systemkonfiguration
> **Festplatten-Utilities**
```bash
pacman -Syu gdisk ntfs-3g
```

> **ArchLinux-Keyring aktulisieren**
```bash
pacman -Syyu archlinux-keyring
pacman-key --refresh-keys
```

> **Swap**\
Swappiness auf `0` setzen, wenn Swap nicht verwendet; prüfen:
```bash
sysctl vm.swappiness
nano /etc/sysctl.d/99-swappiness.conf
```
Inhalt anpassen:
```text
vm.swappiness=0
```
```bash
reboot
sysctl vm.swappiness
```
**alternativ: Swapfile einrichten**
```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sudo nano /etc/fstab
```
Inhalt anpassen:
```text
/swapfile none swap defaults 0 0
```

> **Benutzer hinzufügen und sudo einrichten**
```bash
useradd -m <username>
passwd <username>
pacman -Syu sudo
ls /home
nano /etc/sudoers
```
Inhalt anpassen:
```text
EDITOR=nano visudo
Defaults env_reset
Defaults editor=/usr/bin/nano, !env_editor
<username> ALL=(ALL) ALL
```
```bash
cat /etc/sudoers
nano /home/<username>/.bashrc
```
Inhalt anpassen:
```text
export VISUAL=nano
export EDITOR="$VISUAL"
```
```bash
reboot
```
mit neuem Benutzer anmelden

> **32 Bit Packages**
```bash
sudo nano /etc/pacman.conf
```
auskommentieren:
```text
[multilib]
Include=/etc/pacman.d/mirrorlist
```
```bash
pacman -Syyu
```

> **Reflector mit pacman Hook**\
bei pacman mirrorlist Update:
```bash
sudo pacman -Syu reflector
sudo mkdir /etc/pacman.d/hooks
sudo nano /etc/pacman.d/hooks/mirrorupgrade.hook
```
Inhalt:
```text
[Trigger]
Operation=Upgrade
Type=Package
Target=pacman-mirrorlist
[Action]
Description=Updating pacman-mirrorlist with reflector and removing pacnew...
When=PostTransaction
Depends=reflector
Exec=/bin/sh -c "reflector --coutry 'Germany' --protocol https --age 1 --score 10 --sort rate --save /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
```
Reinstallieren:
```bash
pacman -S pacman-mirrorlist
```
bei jedem Boot, wenn Netzwerk aktiv
```bash
sudo nano /etc/systemd/system/reflector.service
```
Inhalt:
```text
[Unit]
Description=pacman mirrorlist update via reflector
Wants=network-online.target
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --country 'Germany' --protocol https --age 1 --score 10 --sort rate --save /etc/pacman.d/mirrorlist
[Install]
RequiredBy=multi-user.target
```
```bash
systemctl enable reflector.service
systemctl start reflector.service
systemctl status reflector.service
```

> **AUR (Arch User Repository)**
```bash
sudo pacman -Syu --needed base-devel git
mkdir ~/aur
cd aur
curl -O https://github.com/polygamma.gpg
gpg --import polygamma.gpg
rm -rf polygamma.gpg
git clone https://aur.archlinux.org/aurman-git.git
cd aurman-git
makepkg --cleanbuild --install --syncdeps --needed --noconfirm --clean
cd ../..
rm -rf aur
ls
mkdir -p ~/.config/aurman/
sudo nano ~/.config/aurman/aurman_config
```
Inhalt:
```text
[miscellaneous]
devel
keyserver=hkp://ipv4.pool.sks-keyservers.net:11371
noedit
pgp_fetch
solution_way
use_ask
```
```bash
aurman -Syyu downgrade
```

> **Makepkg optimieren**
```bash
aurman -Syu ccache libarchive zst
sudo nano /etc/makepkg.conf
```
Inhalt anpassen: `ccache`, `-march=native`, `--threads=0`, `-j$(nproc)`, `.pkg.tar.zst`
```text
BUILDENV=(!distcc color ccache check !sign)
CFLAGS="-march=native -O2 -pipe -fstack-protector-strong -fno-plt"
COMPRESSZST=(zstd -c -z -q - --threads=0)
MAKEFLAGS="-j$(nproc)"
PKGEXT='.pkg.tar.zst'
```
```bash
sudo nano ~/.bashrc
```
Inhalt in `PATH` erweitern um `/usr/lib/ccache/bin/`, Trennzeichen ist `:`

> **Fehlende Treiber Pakete**
```bash
aurman -Syu wd719x-firmware aic94xx-firmware
mkinitcpio -p linux
```

> **GUI**
```bash
aurman -Syu xorg
aurman -Syu nvidia nvidia-utils lib32-nvidia-utils
aurman -Syu gnome gnome-extra
sudo systemctl enable gdm.service
aurman -Syu gdm3setup gdm3setup-utils
aurman -Syu nvidia-settings
aurman -Syu networkmanager networkmanager-openvpn
sudo systemctl enable NetworkManager.service
aurman -Syu firefox firefox-i18n-de
reboot
```
Gnome Settings:
- Region und Sprache: Tastatur auf Deutsch einstellen
- Bildschirme ausrichten
  - dann:
```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm/.config/
sudo chown gdm:gdm /var/lib/gdm/.config/monitors.xml
```
- mit WLAN verbinden
- Audio einrichten
- Energiemanagement einstellen
- Terminal:
```bash
ping 1.1.1.1
aurman -Syyu
aurman -Syu vlc ntp
sudo nano /etc/NetworkManager/dispatcher.d/10-vpn-ipv6
```
Inhalt anpassen:
```text
#!/bin/sh

case "$2" in
	vpn-up)
		echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
		;;
	vpn-down)
		echo 0 > /proc/sys/net/ipv6/conf/all/disable_ipv6
		;;
esac
```

> **für Intel Grafik**\
statt Nvidia-Treiber und -Software
```bash
aurman -Syu mesa lib32-mesa xf86-video-intel
```

> **Firewall**
```bash
aurman -Syu ufw
sudo systemctl start ufw.service
sudo systemctl enable ufw.service
sudo ufw default deny
sudo ufw limit ssh
sudo ufw enable
sudo ufw status
sudo nano /etc/default/ufw
```
Inhalt anpassen: von `"DROP"` auf
```text
DEFAULT_FORWARD_POLICY "ACCEPT"
```
```bash
aurman -Syu gufw
```

> **SSD Trim**
```bash
sudo systemctl start fstrim.service
sudo systemctl status fstrim.service
sudo systemctl enable fstrim.service
```

> **Drucker**
```bash
aurman -Syu cups cups-pdf
sudo nano /etc/cups/cups-pdf.conf
```
Inhalt anpassen:
```text
Out /home/${USER}
```
```bash
sudo systemctl start org.cups.cupsd.service
sudo systemctl enable org.cups.cupsd.service
```

> **Bash Completion**
```bash
aurman -Syu bash-completion
```

## Design und Weiteres
- McMojave Theme
- Capitaine Cursors
- Firefox Add-On für Gnome Shell Erweiterungen

## GRUB in Windows EFI Partition für Multiboot Menü
Noch nicht abschließend!
> Boot aus ArchLinux Live-CD
```bash
loadkeys de-latin1
ls /sys/firmware/efi/efivars
ip link
cp /etc/netctl/examples/wireless-wpa-static /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
nano /etc/netctl/<Netzwerkadapter>-<WLAN-SSID>
netctl start <Netzwerkadapter>-<WLAN-SSID>
ping 1.1.1.1
```

> EFI Partition mounten und GRUB installieren
```bash
fdisk -l
mount /dev/<efiPart> /mnt
ls /mnt
pacman -Syy grub efibootmgr
grub-install --target=x86_64-efi --recheck --removable --efi-directory=/mnt --boot-directory=/mnt/EFI --bootloader-id=MENU
nano /mnt/EFI/grub/grub.cfg
```
Inhalt anpassen:
```text
menuentry "Firmware" {
     fwsetup
}
```

> Neustarten
```bash
umount /mnt
reboot
```
