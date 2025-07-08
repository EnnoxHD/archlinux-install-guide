# ArchLinux installation
This guide is based on various information from the official [ArchLinux Wiki](https://wiki.archlinux.org/).

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

#### Change package mirror
```bash
nano /etc/pacman.d/mirrorlist
```
Add an entry at the top:
```
Server = https://mirror.netcologne.de/archlinux/$repo/os/$arch
```

#### Transfer the base system
Install basic packages:
```bash
pacstrap /mnt base linux linux-firmware mkinitcpio dkms linux-headers nano
```

#### File system table
Generate the filesystem table:
```bash
genfstab -U /mnt >> /mnt/etc/fstab
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
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole sd-encrypt block filesystems fsck)
COMPRESSION="zstd"
```
Build:
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
Hook for updating the GRUB installation and configuration after an upgrade:
```bash
mkdir /etc/pacman.d/hooks
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
# For Intel:
pacman -S intel-ucode
# For AMD:
pacman -S amd-ucode

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
See [RAID](RAID.md).

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
Exec=/bin/sh -c "curl -o /etc/pacman.d/mirrorlist 'https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=6'; sed -i '1s;^;Server = https://mirror.netcologne.de/archlinux/\$repo/os/\$arch\nServer = https://mirrors.n-ix.net/archlinux/\$repo/os/\$arch\nServer = https://ftp.halifax.rwth-aachen.de/archlinux/\$repo/os/\$arch\n\n;' /etc/pacman.d/mirrorlist; grep ^[^#].* /etc/pacman.d/mirrorlist; rm -f /etc/pacman.d/mirrorlist.pacnew"
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
aurman -Syu git-credential-manager git-credential-manager-extras
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
         -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \
         -fstack-clash-protection -fcf-protection \
         -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
 ...
-LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now \
+LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now,-fuse-ld=mold \
          -Wl,-z,pack-relative-relocs"
 ...
-#MAKEFLAGS="-j2"
+MAKEFLAGS="-j$(nproc)"
 ...
-BUILDENV=(!distcc color !ccache check !sign)
+BUILDENV=(!distcc color ccache check !sign)
```
```bash
sudo nano /etc/makepkg.conf.d/rust.conf
```
Change the lines according to the following:
```diff
-RUSTFLAGS="-C force-frame-pointers=yes"
+RUSTFLAGS="-C opt-level=3 -C target-cpu=native -C link-arg=-fuse-ld=mold -C force-frame-pointers=yes"
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

### Man pages
```bash
aurman -Syu man-db
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
reboot
```

### PCIe Errors
Check for PCIe Advanced Error Reports (AER) or some general advice on configuration:
```bash
sudo dmesg | grep -C5 -i error
sudo dmesg | grep -C5 -i aer
sudo dmesg | grep -C5 -i aspm
```
Maybe even a line like `ACPI FADT declares the system doesn't support PCIe ASPM, so disable it` occours
or correctable errors from the AER like this are reported:
```text
[    0.500131] pcieport 0000:00:1c.4: AER: Correctable error message received from 0000:00:1c.4
[    0.500137] pcieport 0000:00:1c.4: PCIe Bus Error: severity=Correctable, type=Physical Layer, (Receiver ID)
[    0.500139] pcieport 0000:00:1c.4:   device [8086:a294] error status/mask=00000001/00002000
[    0.500140] pcieport 0000:00:1c.4:    [ 0] RxErr                  (First)
```
In such cases disabling PCIe ASPM might help.

#### Disable PCIe ASPM
```bash
sudo nano /etc/default/grub
```
To turn off PCIe Active System Power Management add:
```text
GRUB_CMDLINE_LINUX=...pcie_aspm=off
```
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
reboot
```
Recheck `dmesg` outputs afterwards.

### Basic graphics driver
```bash
aurman -Syu xf86-video-fbdev xf86-video-vesa
```

### Xorg server (with mesa and vulkan)
```bash
aurman -Syu mesa vulkan-icd-loader
aurman -Syu xorg-server xorg-apps
```
Set the keyboard layout:
```bash
sudo localectl --no-convert set-x11-keymap de
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
aurman -Syu vulkan-intel

# for intel_gpu_top:
aurman -Syu intel-gpu-tools
```
for NVIDIA:

see [General Codenames](https://nouveau.freedesktop.org/CodeNames.html#generalcodenames)
```bash
# for newer cards (Maxwell and newer):
aurman -Syu nvidia nvidia-utils opencl-nvidia

# for older cards (Kepler, requires DKMS):
aurman -Syu nvidia-470xx-dkms nvidia-470xx-utils opencl-nvidia-470xx
```

Vulkan tools:
```bash
aurman -Syu vulkan-tools
```

### Hardware video acceleration (VA-API and VDPAU)
for NVIDIA:
```bash
aurman -Syu libvdpau libva-nvidia-driver
sudo nano /etc/environment
```
Add:
```text
LIBVA_DRIVER_NAME=nvidia
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

### Audio server and multimedia session manager
```bash
aurman -Syu pipewire libpipewire pipewire-session-manager wireplumber libwireplumber
aurman -Syu pipewire-audio pipewire-jack pipewire-pulse pipewire-alsa
```

### Fonts
```bash
aurman -Syu noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-jetbrains-mono
```

### Desktop environment
```bash
aurman -Syu gnome gnome-extra
sudo systemctl enable gdm.service
aurman -Syu networkmanager
sudo systemctl disable --now wpa_supplicant.service
sudo systemctl mask wpa_supplicant.service
sudo nano /etc/NetworkManager/conf.d/wifi_backend.conf
```
Change content:
```text
[device]
wifi.backend=iwd
```
```bash
sudo systemctl enable NetworkManager.service
reboot
```

#### Gnome settings
```bash
aurman -Syu dconf-editor
```
```bash
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
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

#### Fractional Scaling (HiDPI)
```bash
aurman -S mutter-x11-scaling gnome-keybindings-x11-scaling gnome-control-center-x11-scaling
# manual intervention may be required, reinstall mutter dependants
aurman -S gdm gnome-shell gnome-shell-extensions gnome-browser-connector
gsettings set org.gnome.mutter experimental-features "['x11-randr-fractional-scaling']"
```
An error might occur after package installation, just restart.
Enable fractional scaling in the control center and set the desired scaling factor.

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

### Pinentry program for GPG-agent
Configure which Pinentry program is used by GPG:
 - default:  `/usr/bin/pinentry-curses`
 - fallback: `/usr/bin/pinentry-tty`
 - GTK window:
   - dependencies: `aurman -Syu gtk3`
   - `echo "pinentry-program /usr/bin/pinentry-gtk" > ~/.gnupg/gpg-agent.conf`
 - Gnome prompt:
   - dependencies: `aurman -Syu gcr`
   - `echo "pinentry-program /usr/bin/pinentry-gnome3" > ~/.gnupg/gpg-agent.conf`
 - other available

Reload the agent after configuration:
```bash
gpg-connect-agent reloadagent /bye
```

### Internet browser
```bash
aurman -Syu firefox firefox-i18n-de
aurman -Syu chromium
```

### Firewall
```bash
aurman -Syu ufw
sudo systemctl start ufw.service
sudo systemctl enable ufw.service
sudo ufw default deny
sudo ufw enable
sudo ufw status

# GUI frontend
aurman -Syu gufw
```

### Firewall: SSH settings
```bash
sudo ufw limit ssh
sudo ufw reload
```

### Firewall: VPN settings

#### Filter rules
To allow IP forwarding in every case:
```bash
sudo nano /etc/default/ufw
```
Change content: from `"DROP"` to
```text
DEFAULT_FORWARD_POLICY "ACCEPT"
```

To allow IP forwarding only for a specific `<adapter>`, e.g. `wg0`:
```bash
sudo nano /etc/ufw/before.rules
```
Add these lines after `# End required lines`:
```text
# allow all on <adapter>
-A ufw-before-forward -i <adapter> -j ACCEPT
-A ufw-before-forward -o <adapter> -j ACCEPT
```

#### Setup IP forwarding
```bash
sudo nano /etc/ufw/sysctl.conf
```
Uncomment the following lines:
```text
net/ipv4/ip_forward=1
net/ipv6/conf/default/forwarding=1
net/ipv6/conf/all/forwarding=1
```

### Firmware updates
```bash
aurman -Syu fwupd udisks2 gnome-firmware
echo 'EspLocation=/efi' | sudo tee -a /etc/fwupd/fwupd.conf
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
pacman -Syu gptfdisk dosfstools ntfs-3g veracrypt
```

### Mount additional (encrypted) partitions
Get `PARTUUID`s for normal drive partions via `sudo blkid`.
Check out `lsblk` for a more general overview of block devices.
For RAID support, see [RAID: Mount additional (encrypted) RAID volumes](RAID.md#mount-additional-encrypted-raid-volumes).

#### Prepare password files for opening encrypted partitions
Prepare files with the encryption password as their content for opening partitions:
```bash
sudo nano /etc/<partname>.password

# change file ownership and permissions
sudo chown root:root /etc/<partname>.password
sudo chmod 600 /etc/<partname>.password
```

#### Mapping encrypted partitions
Edit `/etc/crypttab` for opening partitions:
```bash
sudo nano /etc/crypttab
```
```text
# <partname>
crypt<partname>    /dev/disk/by-partuuid/<partuuid>    /etc/<partname>.password    tcrypt,tcrypt-veracrypt,noauto
```
Continue with the mounting in `/etc/fstab` for the `/etc/crypttab`-mapped partitions.

#### Mounting NTFS partitions
Get the user id `uid` and the group id `gid` of the current user with the `id` command.
In general on a single-user machine this should be `uid=1000` and `gid=1000`.
```bash
id
sudo nano /etc/fstab
```
```text
# <partname>
/dev/mapper/crypt<partname>    /mnt/<partname>    ntfs3    noauto,x-systemd.automount,uid=1000,gid=1000,umask=0022,windows_names    0 0
```

### Mount remote shares

#### Prepare credential files for mounting remote shares
Prepare files with the credentials for the remote shares:
```bash
sudo nano /etc/<sharename>.credentials
```
Add the username and password for the remote share:
```text
username=<username>
password=<password>
```
```bash
# change file ownership and permissions
sudo chown root:root /etc/<sharename>.credentials
sudo chmod 600 /etc/<sharename>.credentials
```

#### Mounting remote shares like CIFS/SMB
Get the user id `uid` and the group id `gid` of the current user with the `id` command.
In general on a single-user machine this should be `uid=1000` and `gid=1000`.
```bash
id
sudo nano /etc/fstab
```
```text
# <sharename>
//<server>/<sharename>    /mnt/<sharename>    cifs    noauto,x-systemd.automount,x-systemd.mount-timeout=1,_netdev,nofail,vers=3.1.1,credentials=/etc/<sharename>.credentials,uid=1000,forceuid,gid=1000,forcegid    0 0
```
The additional mount options are:
- No automatic mount at boot time
- Mount on access
- Defined timeout in case of network issues
- Wait for the network device and a general connection
- Do not report failures
- Set the used protocol version
- Credential files are used instead of the options for user and password
- General mapping of uid and gid

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
# powerline
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/share/powerline/bindings/bash/powerline.sh
```
Configuration:
```bash
mkdir -p ~/.config/powerline/themes/shell/
cp /usr/lib/python3.x/site-packages/powerline/config_files/themes/shell/default.json ~/.config/powerline/themes/shell/
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
- Cursor: [Capitaine-cursors](https://github.com/keeferrourke/capitaine-cursors) (`community/capitaine-cursors`)
- Icons: [Numix-Circle](https://github.com/numixproject/numix-icon-theme-circle/) (`aur/numix-circle-icon-theme-git`) and [Numix-Folders](https://github.com/numixproject/numix-folders) (`aur/numix-folders-git`)

## Additional software
- [SOFTWARE](SOFTWARE.md)

## Advanced topics

### VM
- [KVM](KVM.md)
- [IOMMU](IOMMU.md)
- [QEMU](QEMU.md)

