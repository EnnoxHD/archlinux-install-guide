#!/bin/bash

# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Ensuring_that_the_groups_are_valid
# outputs mapping information about iommu groups and their devices

# expand filename patterns to null instead of the pattern itself if no matches were found
shopt -s nullglob

# get all iommu groups and sort them
for g in `find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V`; do
    # shorten filepath to group name and print
	echo "IOMMU Group ${g##*/}:"
	# for every device within the iommu group
	for d in $g/devices/*; do
	    # shorten filepath to device's pci address and print information about the device
		echo -e "\t$(lspci -nns ${d##*/})"
	done;
done;
