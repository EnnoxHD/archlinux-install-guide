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
HOOKS=(base udev systemd autodetect microcode modconf kms keyboard sd-vconsole block mdadm_udev sd-encrypt filesystems fsck)
```
```bash
mkinitcpio -p linux
reboot
```

## Mount additional (encrypted) RAID volumes
Get `UUID`s for RAID volumes via `sudo mdadm -E --scan`.
Check out `lsblk` for a more general overview of block devices.

### Prepare password files for opening encrypted partitions
Continue with [README: Prepare password files for opening encrypted partitions](README.md#prepare-password-files-for-opening-encrypted-partitions)
and come back for the following sections.

### Mapping encrypted partitions
Edit `/etc/crypttab` for opening partitions:
```bash
sudo nano /etc/crypttab
```
Use the RAID volume `UUID` to locate the correct array:
```text
# <partname>
crypt<partname>    /dev/disk/by-id/md-uuid<uuid>-part<number>    /etc/<partname>.password    tcrypt,tcrypt-veracrypt,noauto
```
Continue with the mounting in `/etc/fstab` for the `/etc/crypttab`-mapped partitions.

### Normal mounting
See e.g. [README: Mounting NTFS partitions](README.md#mounting-ntfs-partitions).

