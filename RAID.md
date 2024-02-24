# RAID

## Install software
```bash
aurman -Syu mdadm
```

## Configure RAID arrays
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

## Configure kernel for early RAID support
```bash
nano /etc/mkinitcpio.conf
```
Change content:
```text
BINARIES=(mdmon)
# add udev and mdadm_udev in HOOKS
HOOKS=(base udev systemd autodetect modconf kms block mdadm_udev keyboard sd-vconsole sd-encrypt filesystems fsck)
```
```bash
mkinitcpio -p linux
reboot
```

## Mount additional (encrypted) RAID volumes
Get `UUID`s for RAID volumes via `sudo mdadm -E --scan`.
Check out `lsblk` for a more general overview of block devices.

### Mapping encrypted partitions
Prepare files for unlocking drives like `sudo nano /etc/<diskname>.password`.
```bash
sudo nano /etc/crypttab
```
```text
# <diskname>
crypt<diskname>    /dev/disk/by-id/md-uuid<uuid>-part<number>    /etc/<diskname>.password    tcrypt,tcrypt-veracrypt,noauto
```
Continue with the mounting in `/etc/fstab` for the `/etc/crypttab`-mapped partitions.

### Normal mounting
See [README: Normal mountig](README.md#normal-mounting)

