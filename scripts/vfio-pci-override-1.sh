#!/bin/sh

# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Passthrough_all_GPUs_but_the_boot_GPU
# bind vfio-pci to all GPUs but the boot GPU

# look for all GPUs
for i in /sys/bus/pci/devices/*/boot_vga; do
    # if it is not the boot GPU
    if [ $(cat "$i") -eq 0 ]; then
        # GPU, AUDIO and USB contain the pci address
        GPU="${i%/boot_vga}"
        AUDIO="$(echo "$GPU" | sed -e "s/0$/1/")"
        USB="$(echo "$GPU" | sed -e "s/0$/2/")"

        # override the driver for each pci device function
        echo "vfio-pci" > "$GPU/driver_override"
        # if there is an onboard audio device
        if [ -d "$AUDIO" ]; then
            echo "vfio-pci" > "$AUDIO/driver_override"
        fi
        # if there is an onboard USB device
        if [ -d "$USB" ]; then
            echo "vfio-pci" > "$USB/driver_override"
        fi
    fi
done

# load the module
modprobe -i vfio-pci
