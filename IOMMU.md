# IOMMU
IOMMU allows for PCIe device isolation on a low level and therefore it's possible to use these devices in VM applications.
For example one may isolate a second GPU for dedicated use inside a VM.

## Enable IOMMU
Use the kernel parameter `intel_iommu=on` on Intel CPUs to enable IOMMU and the remapping of I/O.

```bash
sudo nano /etc/default/grub
```
```text
GRUB_CMD_LINE_DEFAULT="... intel_iommu=on"
```
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Enable 1:1 I/O mapping for passthrough
The additional kernel parameter `iommu=pt` might be useful in passthrough scenarios to make it work.
But in general it's considered a bug if one has to use it.
The consequence is an internal 1:1 mapping for the IOMMU devices and it prevents Linux from touching devices that cannot be passed through.
In other cases it may even improve the performance of a passthrough application.

```bash
sudo nano /etc/default/grub
```
```text
GRUB_CMD_LINE_DEFAULT="... intel_iommu=on iommu=pt"
```
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Confirm IOMMU is working
Reboot and check with:
```bash
dmesg | grep -i -e DMAR -e IOMMU
```

### Validating IOMMU groups
Install `pciutils` and use the prepared script in this repository to identify IOMMU groups and their devices:
```bash
aurman -Syu pciutils
sudo ./scripts/iommugroups.sh
```

A Note on unisolated CPU-based PCIe slots:
An additional CPU PCIe related device may appear in the same group as the device you are targeting,
but that's okay as long as the main device is isolated without any other devices in the group besides the CPU PCIe device.
The targeted device may provide multiple functions such as video and audio capabilities in case of a GPU.

Output example for a specific IOMMU group and the targeted GPU device on PCI location `01:00` with it's two functions and a CPU related `PCI bridge` device:
```text
IOMMU Group 1:
  00:01.0 PCI bridge: Intel Corporation Xeon E3-1200 v2/3rd Gen Core processor PCI Express Root Port (rev 09)
  01:00.0 VGA compatible controller: NVIDIA Corporation GM107 [GeForce GTX 750] (rev a2)
  01:00.1 Audio device: NVIDIA Corporation Device 0fbc (rev a1)
```

If other devices appear in the targeted group together with the desired device to isolate, one may otherwise use the
[ACS override patch](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Bypassing_the_IOMMU_groups_(ACS_override_patch)).

## PCIe device isolation
First enable IOMMU, then isolate the device and bind it via vfio.

### Bind vfio-pci via device id
Binding via device id is only suitable if no other identical device is present.
Example device ids: `10de:1b06` and `10de:10ef`.
```bash
sudo nano /etc/default/grub
```
```text
# list the device ids
GRUB_CMD_LINE_DEFAULT="... vfio-pci.ids=10de:1b06,10de:10ef"
```
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Bind vfio-pci via pci address
In the case where multiple identical devices are present (e.g. NVMe drives) a script `/usr/local/bin/vfio-pci-override.sh` is needed to identify the device(s) by pci address.
There are prepared scripts in this repository (see `scripts/vfio-pci-override-*.sh`) that may be used.
Example pci addresses: `0000:03:00.0` and `0000:03:00.1`.

```bash
sudo mv scripts/vfio-pci-override-*.sh /usr/local/bin/vfio-pci-override.sh
# modify and configure the script
sudo nano /usr/local/bin/vfio-pci-override.sh

sudo nano /etc/mkinitcpio.conf
```
```text
FILES=(... /usr/local/bin/vfio-pci-override.sh)

# ensure 'modconf' hook is present
HOOKS=(... modconf ...)
```
```bash
sudo nano /etc/modprobe.d/vfio.conf
```
```text
install vfio-pci /usr/local/bin/vfio-pci-override.sh
```
```bash
sudo mkinitcpio -p linux
```

### Load vfio-pci early
```bash
sudo nano /etc/mkinitcpio.conf
```
```text
# add modules, MUST preceed graphics drivers
MODULES=(... vfio_pci vfio vfio_iommu_type1 ...)

# ensure 'modconf' hook is present
HOOKS=(... modconf ...)
```
```bash
sudo mkinitcpio -p linux
```

### Verify
Reboot and check:
```bash
dmesg | grep -i vfio

# via device id
lspci -nnk -d 10de:1b06
lspci -nnk -d 10de:10ef

# via pci address
lspci -nnk -s 0000:03:00.0
lspci -nnk -s 0000:03:00.1
```

## GPU passthrough
First enable IOMMU and isolate the PCIe device.
To successfully passthrough a GPU there are multiple complex aspects to be considered in addition.
The display output may temporarily break entirely due to misconfiguration or configuration interference!

### Isolate the GPU Framebuffer
Linux may use the framebuffer of the GPU in the boot process even though vfio grabs the device afterwards and the device may be busy.
The result is if a VM boots and grabs the GPU but then no correct output is given.
An example of some output may be described as a black or white background with some colored dots.

The solution is to deactivate the use of the GPU framebuffer in EFI mode:
```bash
sudo nano /etc/default/grub
```
```text
GRUB_CMDLINE_LINUX_DEFAULT="... video=efifb:off"
```
```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Isolate a GPU from the Xorg server
Even though the GPU is isolated at a quite low level the Xorg server might have some impact.
``` bash
sudo nano /etc/X11/xorg.conf
```
 - In the [Section "ServerLayout"](https://man.archlinux.org/man/extra/xorg-server/xorg.conf.5.en#SERVERLAYOUT_SECTION)
   add the `Option "IsolateDevice" "PCI:1:0:0"` according to the guest GPUs IOMMU group/device/function.
 - In the [Section "Device"](https://man.archlinux.org/man/extra/xorg-server/xorg.conf.5.en#DEVICE_SECTION)
   add the `Option "BusID" "PCI:5:0:0"` according to the host GPUs IOMMU group/device/function.

Additional configuration of the output ports on the host might be needed.
As this is highly individual some further research is likely necessary.
``` bash
sudo nano /etc/X11/xorg.conf
```
 - In the [Section "Screen"](https://man.archlinux.org/man/extra/xorg-server/xorg.conf.5.en#SCREEN_SECTION)
    - add e.g. `Option "nvidiaXineramaInfoOrder" "DFP-0,DFP-2"` (https://man.archlinux.org/man/nvidia-xconfig.1)
      where `DFP-0,DFP-2` are the given names of the output ports to use.
    - add e.g. `Option "metamodes" "DFP-2: nvidia-auto-select +0+0 {Rotation=left, ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, DFP-0: nvidia-auto-select +1080+840 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"`
      (https://man.archlinux.org/man/nvidia-xconfig.1) and use the given names of the output ports to further setup the screens.

