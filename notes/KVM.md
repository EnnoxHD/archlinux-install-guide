# KVM
- means Kernel Based Virtualization
- is a hypervisor in the Linux kernel itself
- uses the CPU virtualization extensions
- is commonly used together with QEMU

## Hardware and BIOS support
Check for KVM support with at least one of these methods.

### Check via `lscpu`
Use the following command:
```bash
LC_ALL=C lscpu | grep Virtualization
```
The output should show `VT-x` or `AMD-V` depending on your CPU.

### Alternative: Check via `/proc/cpuinfo`
Use the following command:
```bash
grep -E --color=auto 'vmx|svm|0xc0f' /proc/cpuinfo
```
Either `vmx`, `svm` or `0xc0f` should be highlighted in the output.

## Kernel support
Check for general kernel support and automatic module loading.

### Check for general support
Use the following command:
```bash
zgrep CONFIG_KVM /proc/config.gz
```
In the output check that `kvm` and (depending on the CPU) either `kvm_amd` or `kvm_intel` are all listed as `y` or `m`.

### Check for automatic module loading
Use the following command:
```bash
lsmod | grep kvm
```
Should return at least `kvm` and (depending on the CPU) either `kvm_amd` or `kvm_intel` as the output.
