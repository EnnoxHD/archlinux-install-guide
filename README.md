# ArchLinux installation
This guide is based on various information from the official [ArchLinux Wiki](https://wiki.archlinux.org/).

A small hack for reading the wiki on bigger screens:\
Enlarge the content area and arrange several elements on the sites with the following JS bookmark:
```javascript
javascript:function changeMaxWidth(byid,name,value){if(byid){document.getElementById(name).style.maxWidth=value;}else{var elements=document.getElementsByClassName(name);var i;for(i=0;i<elements.length;i++){elements[i].style.maxWidth=value;}}};function run(){changeMaxWidth(false,"mw-page-container","100%");changeMaxWidth(false,"mw-content-container","100%");changeMaxWidth(false,"mw-article-toolbar-container","100%");changeMaxWidth(true,"searchform","100%");document.getElementById("p-search").children[1].style.margin="auto";};run();
```
The formatted JS part:
```javascript
function changeMaxWidth(byid, name, value) {
	if(byid) {
		document.getElementById(name).style.maxWidth = value;
	} else {
		var elements = document.getElementsByClassName(name);
		var i;
		for(i = 0; i < elements.length; i++) {
			elements[i].style.maxWidth = value;
		}
	}
};
function run() {
	changeMaxWidth(false, "mw-page-container", "100%");
	changeMaxWidth(false, "mw-content-container", "100%");
	changeMaxWidth(false, "mw-article-toolbar-container", "100%");
	changeMaxWidth(true, "searchform", "100%");
	document.getElementById("p-search").children[1].style.margin = "auto";
};
run();
```

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
iwctl device list
iwctl station <device> scan
iwctl station <device> get-networks
iwctl --passphrase=<'password'> station <device> connect <SSID>
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
lsblk
blockdev --getbsz /dev/<drive> # value for bs parameter in dd command
dd if=/dev/urandom of=/dev/<drive> bs=4096 status=progress
```

## Installation

### Partitioning
```bash
sgdisk --zap-all /dev/<hard_drive>
sgdisk --new=1:0:+512M /dev/<hard_drive> # EFI partition
sgdisk --typecode=1:ef00 /dev/<hard_drive>
sgdisk --new=2:0:0 /dev/<hard_drive> # root partition
sgdisk --typecode=2:8300 /dev/<hard_drive>
```

### File systems
For the root partition:
```bash
cryptsetup -y -v --type luks1 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 2000 --use-urandom luksFormat /dev/<root_partition>
YES
<passphrase_for_root_partition>
<passphrase_for_root_partition>
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
HOOKS=(base systemd autodetect modconf kms block keyboard sd-vconsole sd-encrypt filesystems fsck)
COMPRESSION="zstd"
```
```bash
mkinitcpio -p linux
```

#### Bootloader GRUB 2
```bash
pacman -S grub efibootmgr
exit # out of chroot
lsblk -f # get UUID
arch-chroot /mnt # enter chroot again
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
GRUB_DISABLE_OS_PROBER=true
GRUB_LANG=en
```
Hook for updating the GRUB configuration after a kernel upgrade:
```bash
nano /etc/pacman.d/hooks/linuxupgrade.hook
```
Content:
```text
[Trigger]
Operation=Upgrade
Type=Package
Target=linux
[Action]
Description=Updating GRUB configuration after kernel upgrade...
When=PostTransaction
Depends=grub
Exec=/bin/sh -c "grub-mkconfig -o /boot/grub/grub.cfg"
```
Hook for updating the GRUB installation and configuration after an upgrade:
```bash
nano /etc/pacman.d/hooks/grubupgrade.hook
```
Content:
```text
[Trigger]
Operation=Upgrade
Type=Package
Target=grub
[Action]
Description=Updating GRUB installation and configuration after upgrade...
When=PostTransaction
Depends=grub
Exec=/bin/sh -c "grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB && grub-mkconfig -o /boot/grub/grub.cfg"
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
GRUB_CMDLINE_LINUX="... rd.luks.key=<UUID>=/crypto_keyfile.bin"
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

### GRUB framebuffer resolution
```bash
nano /etc/default/grub
```
Change content:
```text
GRUB_GFXMODE=1920x1080x32,auto
GRUB_GFXPAYLOAD_LINUX=text
```
A list of available graphics modes can be shown in the native GRUB command line with `videoinfo`.
```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

### Configure RAID arrays
```bash
nano /etc/mdadm.conf
```
Change content:
```text
#DEVICE partitions
```
```bash
mdadm -E --scan >>/etc/mdadm.conf
```

### Configure kernel for early RAID support
```bash
nano /etc/mkinitcpio.conf
```
Change content:
```text
BINARIES=(mdmon)
# add udev and mdadm_udev in HOOKS
HOOKS=(base udev systemd autodetect modconf block mdadm_udev keyboard sd-vconsole sd-encrypt filesystems fsck)
```
```bash
mkinitcpio -p linux
reboot
```

### Get the network time
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

### Update the archlinux-keyring
```bash
nano /etc/pacman.d/gnupg/gpg.conf
```
Change content:
```text
keyserver hkps://keyserver.ubuntu.com
```
```bash
pacman -Syyu archlinux-keyring
pacman-key --init
pacman-key --populate
```

### Swap file
```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swaplabel /swapfile >> /etc/fstab
nano /etc/fstab
```
Change content:
```text
# UUID=<swapfile-uuid>
/swapfile	none	swap	defaults	0 0
```

### Enable TRIM for SSDs
```bash
systemctl enable fstrim.timer
```

### WLAN frequencies and signal strength regulations
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

### Adding users and giving them sudo rights
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
<username> ALL=(ALL:ALL) ALL
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

### 32-bit packages
```bash
sudo nano /etc/pacman.conf
```
Uncomment:
```text
[multilib]
Include = /etc/pacman.d/mirrorlist
```
```bash
sudo pacman -Syyu
```

### Parallel pacman downloads
```bash
sudo nano /etc/pacman.conf
```
Uncomment:
```text
ParallelDownloads = 5
```

### Hook for changing the preferred mirrors after a pacman-mirrorlist upgrade
```bash
sudo nano /etc/pacman.d/hooks/mirrorupgrade.hook
```
Content:
```text
[Trigger]
Operation=Upgrade
Type=Package
Target=pacman-mirrorlist
[Action]
Description=Updating pacman mirrorlist, using preferred mirrors and removing pacnew...
When=PostTransaction
Depends=curl
Depends=sed
Depends=grep
Exec=/bin/sh -c "curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/https/; sed -i '/\(mirror\.f4st\.host\|mirror\.netcologne\.de\)/s/^#//g' /etc/pacman.d/mirrorlist; grep ^[^#].* /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
```
Reinstall:
```bash
sudo pacman -S pacman-mirrorlist
```

### Git and gitconfig
```bash
sudo pacman -Syu git gnupg pass
git clone https://github.com/EnnoxHD/dotfiles.git
cd ./dotfiles/linux
chmod +x copy.sh
./copy.sh
cd ~
rm -rf ./dotfiles
nano ~/.bashrc
```
Add content:
```text
alias git='LANG=en_US.UTF-8 git'
```
```bash
source ~/.bashrc
```

### AUR (Arch User Repository)
```bash
sudo pacman -Syu base-devel
curl -O https://github.com/polygamma.gpg
gpg --import polygamma.gpg
rm polygamma.gpg
git clone https://aur.archlinux.org/aurman.git
cd aurman
makepkg --cleanbuild --install --syncdeps --needed --noconfirm --clean
cd ..
rm -rf aurman
mkdir -p ~/.config/aurman/
nano ~/.config/aurman/aurman_config
```
Content:
```text
[miscellaneous]
devel
keyserver=hkps://keyserver.ubuntu.com
noedit
pgp_fetch
solution_way
use_ask
```
Reinstall:
```bash
aurman -Syu aurman
```

### Transfer GPG keys from another device
Get your existing GPG public/private keypair identified by `<key-id>`:
```bash
gpg --list-keys
gpg --output public.gpg --export <key-id>
gpg --list-secret-keys
gpg --output private.key --export-secret-key <key-id>
```
Safely transfer and import them to the new device.
```bash
gpg --import public.gpg
gpg --import private.key
```
Trust your own key:
```bash
gpg --list-keys
gpg --list-secret-keys
gpg --edit-key <key-id>
```
Then `trust` > `5` > `y` > `quit`.

### Git-Credential-Manager
```bash
aurman -Syu git-credential-manager-core git-credential-manager-core-extras
pass init <key-id>
nano ~/.bashrc
```
Add content:
```text
export GPG_TTY=$(tty)
```
Work with a repository to add the credentials (e.g. personal access token) to the `~/.password-store` of pass.

### Optimize makepkg
```bash
aurman -Syu ccache mold
sudo nano /etc/makepkg.conf
```
Change the lines according to the following:
```diff
-CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions \
+CFLAGS="-march=native -O2 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection"
 ...
-LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"
+LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now,-fuse-ld=mold"
 ...
-#RUSTFLAGS="-C opt-level=2"
+RUSTFLAGS="-C opt-level=3 -C target-cpu=native -C link-arg=-fuse-ld=mold"
 ...
-#MAKEFLAGS="-j2"
+MAKEFLAGS="-j$(nproc)"
 ...
-BUILDENV=(!distcc color !ccache check !sign)
+BUILDENV=(!distcc color ccache check !sign)
 ...
-COMPRESSZST=(zstd -c -z -q -)
+COMPRESSZST=(zstd -c -z -q --threads=0 -)
```
```bash
nano ~/.bashrc
```
Add the following:
```text
export PATH="/usr/lib/ccache/bin:$PATH"
```
```bash
source ~/.bashrc
```

### USB information
```bash
aurman -Syu usbutils
```

### Battery and Temperatures
```bash
aurman -Syu acpi
```

### ACPI support
```bash
aurman -Syu acpid
sudo systemctl enable acpid.service
sudo systemctl start acpid.service
```

### Basic graphics driver
```bash
aurman -Syu xf86-video-fbdev xf86-video-vesa
```

### Xorg server (with mesa and vulkan)
```bash
aurman -Syu mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
aurman -Syu xorg-server xorg-apps
```

### Graphics driver (and vulkan tools)
for Intel:

see [Values for](https://wiki.archlinux.org/title/Intel_graphics#Enable_GuC_/_HuC_firmware_loading) `enable_guc`:
|enable_guc value|GuC Submission|HuC Firmware Loading|Default for platforms|Supported on platforms|
|---|---|---|---|---|
|0|no |no |Tiger Lake, Rocket Lake, and Pre-Gen12|All|
|1|yes|no |-|Alder Lake-P (Mobile) and newer|
|2|no |yes|Alder Lake-S (Desktop)|Gen9 and newer|
|3|yes|yes|Alder Lake-P (Mobile) and newer|Alder Lake-P (Mobile) and newer|

```bash
# for newer cards (Gen 10 and newer):
aurman -Syu intel-media-driver
# enable GuC and HuC
sudo nano /etc/modprobe.d/i915.conf
# options i915 enable_guc=3
sudo mkinitcpio -p linux
# reboot and check dmesg output for GuC and HuC

# for older cards (Gen 2 to Gen 9):
aurman -Syu xf86-video-intel

# for vulkan support on Intel:
aurman -Syu vulkan-intel lib32-vulkan-intel
```
for NVIDIA:

see [General Codenames](https://nouveau.freedesktop.org/CodeNames.html#generalcodenames)
```bash
# for newer cards (Maxwell and newer):
aurman -Syu nvidia nvidia-utils lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia

# for older cards (Kepler, requires DKMS):
aurman -Syu nvidia-470xx-dkms nvidia-470xx-utils lib32-nvidia-470xx-utils opencl-nvidia-470xx lib32-opencl-nvidia-470xx
```

Vulkan tools:
```bash
aurman -Syu vulkan-tools
```

### Hardware video acceleration (VA-API and VDPAU)
for NVIDIA:
```bash
aurman -Syu libva-vdpau-driver
sudo nano /etc/environment
```
Add:
```text
VDPAU_DRIVER=nvidia
```
Verification:
```bash
reboot
# VA-API
aurman -Syu libva-utils
vainfo
# VDPAU
aurman -Syu vdpauinfo
vdpauinfo
```

### Audio driver
```bash
aurman -Syu jack2
```

### Fonts
```bash
aurman -Syu noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra
```

### Desktop environment
```bash
aurman -Syu gnome # curate applications
# aurman -Syu gnome-extra # curate applications
sudo systemctl enable gdm.service
aurman -Syu networkmanager
sudo systemctl enable NetworkManager.service
# consider: networkmanager-iwd (AUR) to remove wpa_supplicant
sudo nano /etc/NetworkManager/conf.d/wifi_backend.conf
```
Change content:
```text
[device]
wifi.backend=iwd
```
```bash
reboot
```

#### Gnome settings
```bash
aurman -Syu dconf-editor
```
```bash
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'de')]" # or configure via Xorg
```

#### Gnome custom keybindings
- Super + e = nautilus
- Super + r = gnome-terminal

```bash
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Files'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'nautilus'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>e'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'Terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'gnome-terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>r'
```

#### Screen layout
for NVIDIA (optional):
```bash
# for newer cards:
aurman -Syu nvidia-settings
# for older cards:
aurman -Syu nvidia-470xx-settings
```
In general adjust monitor settings, then do:
```bash
sudo cp ~/.config/monitors.xml /var/lib/gdm/.config/
sudo chown gdm:gdm /var/lib/gdm/.config/monitors.xml
```

### Internet browser
```bash
aurman -Syu firefox firefox-i18n-de
```

### Deactivate IPv6 on VPN connection
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

### Turn off IPv6 in general
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
sudo systemctl edit ntpd.service
```
Write the following in the appearing editor and
change `ExecStart=/usr/bin/ntpd -g -u ntp:ntp` with the `-4` parameter:
```text
[Unit]
Description=Network Time Service
After=network.target nss-lookup.target
Conflicts=systemd-timesyncd.service

[Service]
Type=forking
PrivateTmp=true
ExecStart=/usr/bin/ntpd -4 -g -u ntp:ntp
Restart=always

[Install]
WantedBy=multi-user.target
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

### Firewall
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

### Bluetooth
```bash
sudo systemctl enable bluetooth.service
```

### Printer driver and PDF
See [CUPS](CUPS.md).

### Scanner
```bash
aurman -Syu sane simple-scan
```

### Disk utilities
```bash
pacman -Syu gptfdisk ntfs-3g veracrypt
```

### Mount additional (encrypted/RAID) partitions
Get `PARTUUID`s for normal drive partions via `sudo blkid`.
Or get `UUID`s for RAID volumes via `sudo mdadm -E --scan`.
Check out `lsblk` for a more general overview of block devices.

#### Mapping encrypted partitions
Prepare files for unlocking drives like `sudo nano /etc/<diskname>.password`.
```bash
sudo nano /etc/crypttab
```
```text
# <diskname>
crypt<diskname>    /dev/disk/by-partuuid/<partuuid>    /etc/<diskname>.password    tcrypt,tcrypt-veracrypt,noauto
# or
crypt<diskname>    /dev/disk/by-id/md-uuid<uuid>-part<number>    /etc/<diskname>.password    tcrypt,tcrypt-veracrypt,noauto
```
Continue with the mounting in `/etc/fstab` for the `/etc/crypttab`-mapped partitions.

#### Normal mounting
Get the user id `uid` and the group id `gid` of the current user with the `id` command.
In general on a single-user machine this should be `uid=1000` and `gid=1000`.
```bash
id
sudo nano /etc/fstab
```
```text
# <diskname>
/dev/mapper/crypt<diskname>    /mnt/<diskname>    ntfs-3g    noauto,x-systemd.automount,uid=1000,gid=1000,dmask=0022,fmask=0033,windows_names    0 0
```


### Links to drives
```bash
nano ~/.profile
```
Content:
```text
for dir in $(ls -1d /mnt/*/);do ln -sfn $dir ~/$(basename $dir);done
```

### Password container
```bash
aurman -Syu keepassxc
```

### Enhancing Bash

#### Bash completion
```bash
aurman -Syu bash-completion
nano ~/.inputrc
```
Content:
```text
$include /etc/inputrc
set completion-ignore-case on
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
Configuration:
```bash
mkdir -p ~/.config/powerline/themes/shell/
cp /usr/lib/python3.10/site-packages/powerline/config_files/themes/shell/default.json ~/.config/powerline/themes/shell/
nano ~/.config/powerline/themes/shell/default.json
```
Changes based on:
- https://powerline.readthedocs.io/en/latest/configuration/segments/common.html#module-powerline.segments.common.time
- https://strftime.org/

Changes:
```diff
 			{
 				"function": "powerline.segments.shell.mode"
 			},
+			{
+				"function": "powerline.segments.common.time.date",
+				"args": {
+					"format": "%H:%M:%S",
+					"istime": true
+				},
+				"priority": 5,
+				"draw_hard_divider": false,
+				"after": " "
+			},
 			{
 				"function": "powerline.segments.common.net.hostname",
 				"priority": 10
 			},
 			{
 				"function": "powerline.segments.common.env.user",
-				"priority": 30
+				"priority": 30,
+				"before": " "
 			},
 			{
 				"function": "powerline.segments.common.env.virtualenv",
```
Restart the shell

## Design
```bash
aurman -Syu gnome-tweaks
```
- Shell and applications: [WhiteSur-dark-solid-blue](https://github.com/vinceliuice/WhiteSur-gtk-theme) (`aur/whitesur-gtk-theme-git`)
- Cursor: [Capitaine-cursors](https://github.com/keeferrourke/capitaine-cursors) (`community/capitaine-cursors`)
- Icons: [Numix-Circle](https://github.com/numixproject/numix-icon-theme-circle/) (`aur/numix-circle-icon-theme-git`) and [Numix-Folders](https://github.com/numixproject/numix-folders) (`aur/numix-folders-git`)

## Additional software

### Gnome extensions
```bash
aurman -Syu gnome-browser-connector
```
Firefox browser extension:
https://addons.mozilla.org/de/firefox/addon/gnome-shell-integration

Used extensions:
- Dash to Dock
- Just Perfection
- No overview at start-up
- Removable Drive Menu
- Tiling Assistant
- Tray Icons: Reloaded
- User Themes

### VLC
Install vlc media player via
```bash
aurman -Syu vlc
```
After installation start vlc and go to the preferences -> Interface section -> Embed video in interface:
- uncheck, save
- check, save

Possible preferences bug: see https://superuser.com/a/126528, #48

Additionally check the following if vlc crashes on playback:
Go to preferences -> Show settings: all -> Video - Output module -> Video output module: VDPAU-Output,
then save

### MTP
Install MTP and add the user `<username>` to the group `uucp`:
```bash
aurman -Syu libmtp
sudo gpasswd -a <username> uucp
```

### ADB
Install android platform tools and add the user `<username>` to the group `adbusers`:
```bash
aurman -Syu android-tools
sudo gpasswd -a <username> adbusers
```

### Command for shredding files
Add a function to the `.bashrc`:
```bash
function shred {
  /usr/bin/shred "$1" && rm "$1"
}
```

### Eclipse IDE
Install the IDE:
```bash
aurman -Syu eclipse-java
```
Add an alias to the `.bashrc`:
```bash
alias eclipse='GTK_THEME=Adwaita:dark eclipse'
```
Add a pacman hook for updating the `eclipse.desktop` file:
```bash
sudo nano /etc/pacman.d/hooks/eclipseupgrade.hook
```
Content:
```text
[Trigger]
Operation=Upgrade
Type=Package
Target=eclipse-java
[Action]
Description=Updating eclipse.desktop file after upgrade...
When=PostTransaction
Depends=sed
Exec=/bin/sh -c "sed -i 's/\(Exec=\)\(.*\)/\1env GTK_THEME=Adwaita:dark \2/' /usr/share/applications/eclipse.desktop"
```

To resolve shortcut conflicts under Gnome configure the following:
```bash
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-down "['']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-up "['']"
```
