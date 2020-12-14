# ArchLinux Installation
Dieser Guide basiert auf verschiedenen Informationen folgender Quellen:
 - [ArchWiki-Webseite](https://wiki.archlinux.org/)
 - [ArchLinux Installationsskript](https://github.com/polygamma/arch-script/)
 - [Google Drive Tool Installation](https://github.com/Dishendramishra/linux-setup#google-drive)

## Vorbereitung
### Allgemeines

> **Laden des benötigten Tastaturlayouts:**
```bash
loadkeys de-latin1-nodeadkeys
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

> **Netzwerkverbindung herstellen:**
```bash
iwctl
device list
station <device> scan
station <device> get-networks
station <device> connect <SSID>
```
Das Passwort eingeben und bestätigen.
```bash
dhcpcd
```

> **Internetverbindung prüfen**
```bash
ping 1.1.1.1
ping google.com
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
efi Partition (`ef00`), root Partition (`8300`)
```bash
gdisk /dev/<GerätFP>
n
1
<Enter>
+512M
ef00
n
2
<Enter>
<Enter>
<Enter>
w
```
für root Partition:
```bash
cryptsetup -y -v --type luks1 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 2000 --use-urandom luksFormat /dev/<rootPart>
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
> **Basissystem übertragen**
```bash
pacstrap /mnt base linux linux-firmware mkinitcpio dkms linux-headers nano
```

> **Mounttable**
```bash
genfstab /mnt >> /mnt/etc/fstab
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
hwclock --systohc
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
Inhalt: `KEYMAP=de-latin1-nodeadkeys`

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
Einrichtung von Netzwerkdiensten
```bash
pacman -S iwd systemd-resolvconf
```
```bash
exit
mkdir /mnt/var/lib/iwd
cp /var/lib/iwd/<SSID>.<type> /mnt/var/lib/iwd/
arch-chroot /mnt
nano /var/lib/iwd/<SSID>.<type>
```
Inhalt anpassen:
```text
[Security]
PreSharedKey=<PreSharedKey>
```
```bash
mkdir /etc/iwd
nano /etc/iwd/main.conf
```
```text
[General]
EnableNetworkConfiguration=true
[Network]
NameResolvingService=systemd
```
```bash
nano /etc/systemd/network/ethernet.network
```
```text
[Match]
Name=en*
[Network]
DHCP=yes
LinkLocalAddressing=no
IPv6AcceptRA=no
IPv6PrivacyExtensions=true
[DHCP]
Anonymize=true
```
```bash
systemctl enable iwd.service
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
```

> **Initramfs**
```bash
nano /etc/mkinitcpio.conf
```
Inhalt anpassen:
```text
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)
COMPRESSION="zstd"
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
GRUB_TIMEOUT=1
GRUB_CMDLINE_LINUX="rd.luks.name=<UUID>=cryptroot root=/dev/mapper/cryptroot rd.luks.options=<UUID>=cipher=aes-xts-plain64:sha512,size=512"
GRUB_ENABLE_CRYPTODISK=y
```

> **Keyfile**\
um nur einmal das Passwort beim Startvorgang angeben zu müssen
```bash
dd bs=512 count=4 if=/dev/random of=/crypto_keyfile.bin iflag=fullblock
chmod 600 /crypto_keyfile.bin
chmod 600 /boot/initramfs-linux*
cryptsetup luksAddKey /dev/<luksPart> /crypto_keyfile.bin
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

> **Root-Password**
```bash
passwd
```
Passwort für root festlegen

> **Erster Neustart**\
Test für Bootloader und alle installierten Komponenten
```bash
exit
umount -R /mnt
reboot
```

## Systemkonfiguration
> **ArchLinux-Keyring aktulisieren**
```bash
nano /etc/pacman.d/gnupg/gpg.conf
```
Inhalt anpassen:
```text
keyserver hkp://ipv4.pool.sks-keyservers.net:11371
```
```bash
pacman -Syyu archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
```

> **Swapfile einrichten**
```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
nano /etc/fstab
```
Inhalt anpassen:
```text
# SWAP
/swapfile none swap defaults 0 0
```

> **Benutzer hinzufügen und sudo einrichten**
```bash
useradd -m <username>
passwd <username>
ls /home
pacman -Syu sudo
EDITOR=nano visudo
```
Inhalt anpassen:
```text
Defaults env_reset
Defaults editor=/usr/bin/nano, !env_editor
Defaults lecture=never
<username> ALL=(ALL) ALL
```
```bash
nano /home/<username>/.bashrc
```
Inhalt anpassen:
```text
export EDITOR=nano
export VISUAL="$EDITOR"
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
Exec=/bin/sh -c "reflector --country 'Germany' --protocol http --age 1 --score 10 --sort rate --save /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
```
Reinstallieren:
```bash
sudo pacman -S pacman-mirrorlist
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
ExecStart=/usr/bin/reflector --country 'Germany' --protocol http --age 1 --score 10 --sort rate --save /etc/pacman.d/mirrorlist
[Install]
RequiredBy=multi-user.target
```
```bash
sudo systemctl enable reflector.service
```

> **AUR (Arch User Repository)**
```bash
sudo pacman -Syu --needed base-devel git
curl -O https://github.com/polygamma.gpg
gpg --import polygamma.gpg
rm polygamma.gpg
git clone https://aur.archlinux.org/aurman.git
cd aurman
makepkg --cleanbuild --install --syncdeps --needed --noconfirm --clean
cd ..
rm -rf aurman
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
aurman -Syy
```

> **Makepkg optimieren**
```bash
aurman -Syu ccache libarchive zstd
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

> **Packages downgraden**
```bash
aurman -Syu downgrade
```

> **Fehlende Treiber Pakete**
```bash
aurman -Syu wd719x-firmware aic94xx-firmware
mkinitcpio -p linux
```

> **Batterie und Thermometer**
```bash
aurman -Syu acpi
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
```

> **für Intel Grafik**\
statt Nvidia-Treiber und -Software
```bash
aurman -Syu mesa lib32-mesa xf86-video-intel
```

> **für Vulkan Unterstützung**
```bash
aurman -Syu vulkan-icd-loader lib32-vulkan-icd-loader
```
für Entwicklung zusätzlich:
```bash
aurman -Syu vulkan-headers vulkan-validation-layers vulkan-tools
```

> **Gnome Einstellungen**
```bash
aurman -Syu dconf dconf-editor
```
`gsettings` zum Ändern der Einstellungen verwenden

> **IPv6 bei VPN deaktivieren**
```bash
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

> **IPv6 allgemein ausschalten**\
Alternative:
```bash
ip -link
sudo nano /etc/sysctl.d/40-ipv6.conf
```
für alle Netzwerkkarten neue Zeile, `<nic>` jeweils ersetzen:
```text
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.<nic>.disable_ipv6 = 1
```
```bash
sudo systemctl restart systemd-sysctl.service
sudo nano /etc/hosts
```
Inhalt anpassen: `#::1`, alle IPv6-Adressen auskommentieren
```bash
sudo nano /etc/dhcpcd.conf
```
Inhalt anpassen:
```text
noipv6rs
noipv6
```
```bash
systemctl edit ntpd.service
```
im erscheinenden Editor:
```text
[Service]
ExecStart=
ExecStart=/usr/bin/ntpd -4 -g -u ntp:ntp
```
```bash
sudo nano /etc/systemd/network/20-wired.network
sudo nano /etc/systemd/network/25-wireless.network
```
Inhalt jeweils anpassen bzw. hinzufügen:
```text
[Network]
LinkLocalAddressing=ipv4
IPv6AcceptRA=no
```
```bash
/etc/gai.conf
```
Inhalt anpassen:
```text
precedence ::ffff:0:0/96  100
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

> **Scanner**
```bash
aurman -Syu imagescan
```

> **Festplatten-Utilities**
```bash
pacman -Syu gdisk ntfs-3g veracrypt
```

> **Passwortcontainer**
```bash
aurman -Syu keepass
```

>**Google Drive**
```bash
aurman -Syu grive-git
```
Einrichtung:
 - [Video](https://www.youtube.com/watch?v=TzO8FyGu4U0)
 - [Anleitung](https://github.com/Dishendramishra/linux-setup#google-drive)
```bash
grive -a --id <id> --secret <secret>
<authentication_code>
```

> **Bash Completion**
```bash
aurman -Syu bash-completion
```

> **Powerline**
```bash
aurman -Syu powerline powerline-fonts
nano ~/.bashrc
```
Inhalt anpassen:
```text
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/share/powerline/bindings/bash/powerline.sh
```
Shell neustarten und weiteres Customizen
 - [ArchWiki: Powerline](https://wiki.archlinux.org/index.php/Powerline#Customizing)
 - [Powerline Documentation](https://powerline.readthedocs.io/en/master/configuration.html)

> **VirtualBox Host**
```bash
aurman -Syu virtualbox virtualbox-guest-iso virtualbox-host-modules-arch virtualbox-ext-oracle
sudo nano /etc/modules-load.d/virtualbox.conf
```
Inhalt:
```text
vboxdrv
vboxnetadp
vboxnetflt
vboxpci
```
```bash
gpasswd -a <user> vboxusers
reboot
```

## Design
- McMojave Theme
- Capitaine Cursors
- Numix Circle Icon Theme
- Numix Folders

## VirtualBox Guest
> mit X-Server:
```bash
aurman -Syu virtualbox-guest-utils xf86-video-vmware
```
> ohne X-Server:
```bash
aurman -Syu virtualbox-guest-utils-nox
```
> Weiteres
```bash
sudo systemctl enable vboxservice.service
gpasswd -a <user> vboxsf
sudo chmod 755 /media
reboot
```

## GRUB in Windows EFI Partition für Multiboot Menü
Noch nicht abschließend!
> Boot aus ArchLinux Live-CD
```bash
loadkeys de-latin1-nodeadkeys
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
