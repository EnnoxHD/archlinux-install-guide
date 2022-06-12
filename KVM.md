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
In the output check that `CONFIG_KVM` and (depending on the CPU) either `CONFIG_KVM_AMD` or `CONFIG_KVM_INTEL` are all listed as `y` or `m`.

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

## Optional: Nested virtualization
- useful for Docker or WSL2 on Windows

### Configure kernel module
Use one of the following configuration steps:
- Volatile configuration:
  ```bash
  modprobe -r kvm_intel
  modprobe kvm_intel nested=1
  ```
- Permanent configuration (depending on CPU):
  - in `/etc/modprobe.d/kvm_intel.conf` configure:
  ```text
  options kvm_intel nested=1
  ```
  - in `/etc/modprobe.d/kvm_amd.conf` configure:
  ```text
  options kvm_amd nested=1
  ```

### Verify on host
Use the following command:
```bash
systool -m kvm_intel -v | grep nested
```
The output should be `nested = "Y"`.

### Usage with QEMU
On VM creation enable host-passthrough for the CPU:
- QEMU commandline: `-cpu host`
- Virtual Machine Manager: `CPU` configuration `host-passthrough`
- libvirt:
  ```xml
  <cpu mode='host-passthrough' check='partial'/>
  ```

### Verify in Linux guest
Use the following command:
```bash
grep -E --color=auto 'vmx|svm' /proc/cpuinfo
```
The output should contain hightlighted `vmx` or `svm` flags for every available CPU core.
