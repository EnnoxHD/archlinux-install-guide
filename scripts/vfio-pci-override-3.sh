#!/bin/sh

# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passthrough_IOMMU_Group_based_of_GPU
# bind vfio-pci to all devices in the same iommu group as the specified pci devices
# e.g. DEVS="0000:03:00.0" binds 0000:03:00.0 and 0000:03:00.1 and potential other devices of the same group

DEVS=""

# if iommu is active
if [ ! -z "$(ls -A /sys/class/iommu)" ]; then
    for DEV in $DEVS; do
        # for every device in the iommu group derived from the specified device (including itself)
        for IOMMUDEV in $(ls /sys/bus/pci/devices/$DEV/iommu_group/devices) ; do
            # override the driver for the pci device
            echo "vfio-pci" > /sys/bus/pci/devices/$IOMMUDEV/driver_override
        done
    done
fi

# load the module
modprobe -i vfio-pci
