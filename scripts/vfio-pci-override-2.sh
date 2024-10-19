#!/bin/sh

# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passthrough_selected_GPU
# bind vfio-pci to specific pci devices
# e.g. DEVS="0000:03:00.0 0000:03:00.1"

DEVS=""

# if iommu is active
if [ ! -z "$(ls -A /sys/class/iommu)" ]; then
    for DEV in $DEVS; do
        # override the driver for the pci device
        echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
    done
fi

# load the module
modprobe -i vfio-pci
