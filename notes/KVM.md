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

## Optional: Huge pages
- performance optimized memory management on the host
- huges pages are usually 2 MB in size (CPU arch dependent)

### Configure
1. Check if `/dev/hugepages` exists
1. Make an entry in `/etc/fstab` like:
   ```text
   hugetlbfs /dev/hugepages hugetlbfs mode=01770,gid=kvm 0 0
   ```
1. Configure the amount of hugepages
   - Get the default hugepage size in KB with:
     ```bash
     grep Hugepagesize /proc/meminfo
     ```
   - E.g. 16 GB = 8192 huge pages of 2 MB each
   - In `/etc/sysctl.d/40-hugepage.conf` set the number of pages with:
     ```text
     vm.nr_hugepages = 8192
     ```
1.  Restart the system

### Verify
Use the following command:
```bash
grep HugePages /proc/meminfo
```
See `HugePages_Total` value in the output for the amount of huge pages the system created.

### Usage with QEMU
Specify `-mem-path /dev/hugepages` on the QEMU command line.
