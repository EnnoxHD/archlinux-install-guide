# ArchLinux installation
This guide is based on various information from these sources:
- https://wiki.archlinux.org/
- https://github.com/polygamma/arch-script/
- https://github.com/Dishendramishra/linux-setup#google-drive

## Preparation

### General

#### Loading of the keyboad layout
```bash
loadkeys de-latin1-nodeadkeys
```
This is only used for more comfortable input on the keyboard.
The default is the english QWERTY layout.

#### Checking whether booted in UEFI mode
```bash
ls /sys/firmware/efi/efivars
```
If there are entries, you can continue.
Otherwise it was booted in BIOS mode.

### Establishing an internet connection
```bash
iwctl
device list
station <device> scan
station <device> get-networks
station <device> connect <SSID>
```
Enter the password and confirm. 
```bash
dhcpcd
```

#### Checking the internet connection
```bash
ping 1.1.1.1
ping google.com
```

#### Getting network time
```bash
timedatectl set-ntp true
timedatectl status
```

### Deleting the hard drive
Overwriting the present data on the hard drive with random data.
```bash
dd if=/dev/urandom of=/dev/<hard_drive> bs=4096 status=progress
```

## Installation

### Partitioning
efi partition (`ef00`), root partition (`8300`)
```bash
gdisk /dev/<hard_drive>
n
1
<enter>
+512M
ef00
n
2
<enter>
<enter>
<enter>
w
```

### File systems
For the root partition:
```bash
cryptsetup -y -v --type luks1 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 2000 --use-urandom luksFormat /dev/<root_partition>
cryptsetup open /dev/<root_partition> cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```

For the efi partition:
```bash
mkfs.fat -F32 /dev/<efi_partition>
mkdir /mnt/efi
mount /dev/<efi_partition> /mnt/efi
```

### Installation of the base system

#### Transfer the base system
Install basic packages:
```bash
pacstrap /mnt base linux linux-firmware mkinitcpio dkms linux-headers nano
```

#### File system table
Generate the filesystem table:
```bash
genfstab /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

#### Change root
Change to the new system as root:
```bash
arch-chroot /mnt
```

### Configuration of the base system

#### Time and Localization
```bash
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
nano /etc/locale.gen
```

Uncomment: `en_US.UTF-8 UTF-8` and `de_DE.UTF-8 UTF-8`
```bash
locale-gen
nano /etc/locale.conf
```
Content: `LANG=de_DE.UTF-8`
```bash
nano /etc/vconsole.conf
```
Content: `KEYMAP=de-latin1-nodeadkeys`

#### Network
```bash
nano /etc/hostname
```
Content: the hostname of the computer, referred to as `<hostname>`
```bash
nano /etc/hosts
```
Content:
```text
127.0.0.1 localhost
::1 localhost
127.0.1.1 <hostname>.localdomain <hostname>
```
Installation of network services
```bash
pacman -S iwd systemd-resolvconf
```
```bash
exit # out of chroot
mkdir /mnt/var/lib/iwd
cp /var/lib/iwd/<SSID>.<type> /mnt/var/lib/iwd/
arch-chroot /mnt # enter chroot again
nano /var/lib/iwd/<SSID>.<type>
```
Change content:
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

#### Initramfs
```bash
nano /etc/mkinitcpio.conf
```
Change content:
```text
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)
COMPRESSION="zstd"
```
```bash
mkinitcpio -p linux
```

#### Bootloader GRUB 2
```bash
pacman -S grub efibootmgr
lsblk -f
```
Remember the `UUID` of the encrypted partition, referred to as `<UUID>`
```bash
nano /etc/default/grub
```
Change content:
```text
GRUB_TIMEOUT=1
GRUB_CMDLINE_LINUX="rd.luks.name=<UUID>=cryptroot root=/dev/mapper/cryptroot rd.luks.options=<UUID>=cipher=aes-xts-plain64:sha512,size=512"
GRUB_ENABLE_CRYPTODISK=y
```

#### Keyfile
Needed to enter the password only once at bootup.
```bash
dd bs=512 count=4 if=/dev/random of=/crypto_keyfile.bin iflag=fullblock
chmod 600 /crypto_keyfile.bin
chmod 600 /boot/initramfs-linux*
cryptsetup luksAddKey /dev/<luksPart> /crypto_keyfile.bin
nano /etc/mkinitcpio.conf
```
Change content:
```text
FILES=(/crypto_keyfile.bin)
```
```bash
mkinitcpio -p linux
nano /etc/default/grub
```
Change content:
```text
rd.luks.key=<UUID>=/crypto_keyfile.bin
```

#### GRUB Installation
```bash
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

#### CPU microcode
```bash
pacman -S intel-ucode
grub-mkconfig -o /boot/grub/grub.cfg
```

#### Password for root
```bash
passwd
```
Enter the password for the `root` user

#### First restart
Tests the bootloader and all main components installed so far.
```bash
exit # out of chroot
umount -R /mnt
reboot
```

## System configuration

#### Get the network time
```bash
nano /etc/systemd/timesyncd.conf
```
Change content:
```text
[Time]
NTP=0.de.pool.ntp.org 1.de.pool.ntp.org 2.de.pool.ntp.org 3.de.pool.ntp.org
FallbackNTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
```
```bash
timedatectl set-ntp true
timedatectl status
timedatectl timesync-status
timedatectl show-timesync --all
```

#### Update the archlinux-keyring
```bash
nano /etc/pacman.d/gnupg/gpg.conf
```
Change content:
```text
keyserver hkp://ipv4.pool.sks-keyservers.net:11371
```
```bash
pacman -Syyu archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
```

#### Swap file
```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
nano /etc/fstab
```
Change content:
```text
# SWAP
/swapfile	none	swap	defaults	0 0
```

#### WLAN frequencies and signal strength regulations
```bash
pacman -Syu wireless-regdb
nano /etc/conf.d/wireless-regdom
```
Uncomment your region:
```text
WIRELESS_REGDOM="DE"
```
```bash
reboot
```

#### Adding users and giving them sudo rights
```bash
useradd -m <username>
passwd <username>
ls /home
pacman -Syu sudo
EDITOR=nano visudo
```
Change content:
```text
Defaults env_reset
Defaults editor=/usr/bin/nano, !env_editor
Defaults lecture=never
<username> ALL=(ALL) ALL
```
```bash
nano /home/<username>/.bashrc
```
Change content:
```text
export EDITOR=nano
export VISUAL="$EDITOR"
```
```bash
reboot
```
Logon with the new user account

#### 32-bit packages
```bash
sudo nano /etc/pacman.conf
```
Uncomment:
```text
[multilib]
Include=/etc/pacman.d/mirrorlist
```
```bash
pacman -Syyu
```

#### reflector with pacman hook
##### Triggered on pacman mirrorlist update
```bash
sudo pacman -Syu reflector
sudo mkdir /etc/pacman.d/hooks
sudo nano /etc/pacman.d/hooks/mirrorupgrade.hook
```
Content:
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
Reinstall:
```bash
sudo pacman -S pacman-mirrorlist
```
##### Triggered on every bootup if network is available
```bash
sudo nano /etc/systemd/system/reflector.service
```
Content:
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

#### AUR (Arch User Repository)
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
Content:
```text
[miscellaneous]
devel
keyserver=hkp://ipv4.pool.sks-keyservers.net:11371
noedit
pgp_fetch
solution_way
use_ask
```
Update package lists and install "mainline" `aurman` (not `aurman-git`)
```bash
aurman -Syy
aurman -S aurman
```

#### Optimize makepkg
```bash
aurman -Syu ccache
sudo nano /etc/makepkg.conf
```
Change the lines according to the following:
- CFLAGS: `-march=native`
- CXXFLAGS: `"$CFLAGS"`
- RUSTFLAGS: `opt-level=3 -C target-cpu=native`
- MAKEFLAGS: `-j$(nproc)`
- BUILDENV: `ccache`
- COMPRESSZST: `--threads=0`
- PKGEXT: `.pkg.tar.zst`

Overview with all changes:
```text
CFLAGS="-march=native -O2 -pipe -fno-plt"
CXXFLAGS="$CFLAGS"
RUSTFLAGS="-C opt-level=3 -C target-cpu=native"
MAKEFLAGS="-j$(nproc)"
BUILDENV=(!distcc color ccache check !sign)
COMPRESSZST=(zstd -c -z -q - --threads=0)
PKGEXT='.pkg.tar.zst'
```
```bash
sudo nano ~/.bashrc
```
Add the following:
```text
export PATH="/usr/lib/ccache/bin/:$PATH"
```
```bash
source ~/.bashrc
```

#### Downgrading packages
```bash
aurman -Syu downgrade
```

#### USB information
```bash
aurman -Syu usbutils
```

#### Battery and Temperatures
```bash
aurman -Syu acpi
```

#### Basic graphics driver
```bash
aurman -Syu xf86-video-vesa
```

#### Xorg server
```bash
aurman -Syu xorg-server
```

#### Graphics driver
for NVIDIA:
```bash
# aurman -R mesa
aurman -Syu nvidia nvidia-utils lib32-nvidia-utils
```
for Intel:
```bash
aurman -Syu xf86-video-intel mesa lib32-mesa
```
for AMD:
```bash
aurman -Syu xf86-video-amdgpu mesa lib32-mesa
```

#### Desktop environment
```bash
aurman -Syu gnome gnome-extra
sudo systemctl enable gdm.service
aurman -Syu gdm3setup gdm3setup-utils
aurman -Syu nvidia-settings
aurman -Syu networkmanager networkmanager-openvpn
sudo systemctl enable NetworkManager.service
aurman -Syu firefox firefox-i18n-de
reboot
```
Gnome settings:
- Region and language: Change keymap accordingly
- Adjust monitor settings
  - then do:
```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm/.config/
sudo chown gdm:gdm /var/lib/gdm/.config/monitors.xml
```
- Connect with WLAN
- Change audio
- Work on energy management settings

#### for Vulkan support
```bash
aurman -Syu vulkan-icd-loader lib32-vulkan-icd-loader
```

#### Advanced Gnome settings
```bash
aurman -Syu dconf dconf-editor
```
`gsettings` allows to change Gnome settings via command line

#### Deactivate IPv6 on VPN connection
```bash
sudo nano /etc/NetworkManager/dispatcher.d/10-vpn-ipv6
```
Change content:
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

#### Turn off IPv6 in general
Alternative:
```bash
ip link
sudo nano /etc/sysctl.d/40-ipv6.conf
```
Write for all network interfaces a new row where the placeholder for its identifier is `<nic>`:
```text
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.<nic>.disable_ipv6 = 1
```
```bash
sudo systemctl restart systemd-sysctl.service
sudo nano /etc/hosts
```
Change content: `#::1`, comment out all IPv6 adresses
```bash
sudo nano /etc/dhcpcd.conf
```
Change content:
```text
noipv6rs
noipv6
```
```bash
systemctl edit ntpd.service
```
Write the following in the appearing editor:
```text
[Service]
ExecStart=
ExecStart=/usr/bin/ntpd -4 -g -u ntp:ntp
```
For each file follow the below steps:
```bash
sudo nano /etc/systemd/network/20-wired.network
sudo nano /etc/systemd/network/25-wireless.network
```
Change or add these lines in every file from above:
```text
[Network]
LinkLocalAddressing=ipv4
IPv6AcceptRA=no
```
```bash
/etc/gai.conf
```
Change content:
```text
precedence ::ffff:0:0/96  100
```

#### Firewall
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
Change content: from `"DROP"` to
```text
DEFAULT_FORWARD_POLICY "ACCEPT"
```
```bash
aurman -Syu gufw
```

#### Enable TRIM for SSDs
```bash
sudo systemctl start fstrim.service
sudo systemctl status fstrim.service
```

#### Printer driver and PDF
```bash
aurman -Syu cups cups-pdf
sudo nano /etc/cups/cups-pdf.conf
```
Change content:
```text
Out /home/${USER}
```
```bash
sudo systemctl start org.cups.cupsd.service
sudo systemctl enable org.cups.cupsd.service
```

#### Scanner
```bash
aurman -Syu imagescan
```

#### Disk utilities
```bash
pacman -Syu gdisk ntfs-3g veracrypt
```

#### Password container
```bash
aurman -Syu keepass
```

#### Google Drive
```bash
aurman -Syu grive-git
```
Installation:
 - [Video](https://www.youtube.com/watch?v=TzO8FyGu4U0)
 - [Instructions](https://github.com/Dishendramishra/linux-setup#google-drive)
```bash
grive -a --id <id> --secret <secret>
<authentication_code>
```

#### Bash completion
```bash
aurman -Syu bash-completion
```

#### Powerline
```bash
aurman -Syu powerline powerline-fonts
nano ~/.bashrc
```
Change content:
```text
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/share/powerline/bindings/bash/powerline.sh
```
Restart the shell

#### VirtualBox as a host machine
```bash
aurman -Syu virtualbox virtualbox-guest-iso virtualbox-host-modules-arch virtualbox-ext-oracle
sudo nano /etc/modules-load.d/virtualbox.conf
```
Content:
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
```bash
aurman -Syu gnome-tweaks
```
- Shell and applications: [WhiteSur Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme) (`aur/whitesur-gtk-theme-git`)
- Cursor: [Capitaine Cursors](https://github.com/keeferrourke/capitaine-cursors) (`community/capitaine-cursors`)
- Icons: [Numix Circle Icon Theme](https://github.com/numixproject/numix-icon-theme-circle/) (`aur/numix-circle-icon-theme-git`)
- Icons: [Numix Folders](https://github.com/numixproject/numix-folders) (`aur/numix-folders-git`)

And several gnome extensions.

## VirtualBox as an ArchLinux guest

### Installation of packages
- with X-Server
```bash
aurman -Syu virtualbox-guest-utils xf86-video-vmware
```
- without X-Server
```bash
aurman -Syu virtualbox-guest-utils-nox
```

### Further steps
```bash
sudo systemctl enable vboxservice.service
gpasswd -a <user> vboxsf
sudo chmod 755 /media
reboot
```

## GRUB entry in Windows EFI partition for multiboot
> Not properly tested yet and old!

### Boot from an ArchLinux live image
```bash
loadkeys de-latin1-nodeadkeys
ls /sys/firmware/efi/efivars
ip link
cp /etc/netctl/examples/wireless-wpa-static /etc/netctl/<nic>-<WLAN-SSID>
nano /etc/netctl/<nic>-<WLAN-SSID>
netctl start <nic>-<WLAN-SSID>
ping 1.1.1.1
```

### Mounting the EFI partition and installing GRUB
```bash
fdisk -l
mount /dev/<efi_partition> /mnt
ls /mnt
pacman -Syy grub efibootmgr
grub-install --target=x86_64-efi --recheck --removable --efi-directory=/mnt --boot-directory=/mnt/EFI --bootloader-id=MENU
nano /mnt/EFI/grub/grub.cfg
```
Change content:
```text
menuentry "Firmware" {
     fwsetup
}
```

### Restart
```bash
umount /mnt
reboot
```
