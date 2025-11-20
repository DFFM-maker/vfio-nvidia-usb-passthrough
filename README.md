# KVM VFIO Guide: NVIDIA GPU & USB Passthrough

A comprehensive guide and script collection for setting up GPU and USB passthrough on Linux using KVM/QEMU with VFIO (Virtual Function I/O).

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Installation Guide](#installation-guide)
  - [1. Enable IOMMU](#1-enable-iommu)
  - [2. Identify Hardware](#2-identify-hardware)
  - [3. Isolate GPU](#3-isolate-gpu)
  - [4. Configure USB Passthrough](#4-configure-usb-passthrough)
- [Setup Scripts](#setup-scripts)
- [VM Configuration Examples](#vm-configuration-examples)
- [Troubleshooting](#troubleshooting)
- [Performance Tuning](#performance-tuning)
- [Security Considerations](#security-considerations)

## Overview

This guide helps you configure PCI passthrough for NVIDIA GPUs and USB controllers to virtual machines, enabling near-native performance for graphics workloads and direct USB device access. This is ideal for:

- Gaming VMs with dedicated GPU
- GPU-accelerated workloads (machine learning, rendering)
- Development environments requiring specific USB hardware
- Multi-user systems with device isolation

## Prerequisites

- Linux host system (tested on Ubuntu 20.04+, Fedora 35+, Arch Linux)
- CPU with virtualization support (Intel VT-x/VT-d or AMD-V/AMD-Vi)
- Motherboard with IOMMU support
- NVIDIA GPU (not in use by host)
- USB controller (separate from host keyboard/mouse recommended)
- UEFI firmware (BIOS may work but UEFI recommended)

## System Requirements

### Minimum Hardware

- **CPU**: Intel with VT-x/VT-d or AMD with AMD-V/AMD-Vi
- **RAM**: 16GB+ (8GB minimum for VM, 4GB+ for host)
- **GPU**: NVIDIA GPU (GeForce, Quadro, or Tesla)
- **Storage**: SSD recommended for VM disk images

### Software Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf

# Fedora/RHEL
sudo dnf install @virtualization ovmf

# Arch Linux
sudo pacman -S qemu libvirt edk2-ovmf virt-manager
```

## Installation Guide

### 1. Enable IOMMU

#### Intel CPU (VT-d)

Edit GRUB configuration:

```bash
sudo nano /etc/default/grub
```

Add to `GRUB_CMDLINE_LINUX_DEFAULT`:

```
intel_iommu=on iommu=pt
```

#### AMD CPU (AMD-Vi)

```
amd_iommu=on iommu=pt
```

Update GRUB and reboot:

```bash
sudo update-grub  # Ubuntu/Debian
sudo grub2-mkconfig -o /boot/grub2/grub.cfg  # Fedora/RHEL
sudo grub-mkconfig -o /boot/grub/grub.cfg  # Arch

sudo reboot
```

Verify IOMMU is enabled:

```bash
dmesg | grep -i iommu
```

You should see messages about IOMMU being enabled.

### 2. Identify Hardware

Use the provided script to identify your hardware and IOMMU groups:

```bash
./scripts/check-iommu.sh
```

Or manually:

```bash
# List PCI devices
lspci -nn

# Check IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done
```

**Important**: Note the IOMMU group of your NVIDIA GPU. All devices in the same IOMMU group must be passed through together.

### 3. Isolate GPU

#### Find GPU PCI IDs

```bash
lspci -nn | grep -i nvidia
```

Example output:
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP106 [GeForce GTX 1060 6GB] [10de:1c03]
01:00.1 Audio device [0403]: NVIDIA Corporation GP106 High Definition Audio Controller [10de:10f1]
```

Note the vendor:device IDs (e.g., `10de:1c03` and `10de:10f1`).

#### Bind GPU to VFIO

Create `/etc/modprobe.d/vfio.conf`:

```bash
sudo nano /etc/modprobe.d/vfio.conf
```

Add (replace with your GPU IDs):

```
options vfio-pci ids=10de:1c03,10de:10f1
softdep nvidia pre: vfio-pci
softdep nouveau pre: vfio-pci
```

Update initramfs:

```bash
# Ubuntu/Debian
sudo update-initramfs -u

# Fedora/RHEL
sudo dracut -f

# Arch
sudo mkinitcpio -P
```

Add VFIO modules to load at boot. Create `/etc/modules-load.d/vfio.conf`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Reboot and verify:

```bash
lspci -nnk -d 10de:1c03
```

You should see `Kernel driver in use: vfio-pci`.

### 4. Configure USB Passthrough

#### Identify USB Controller

```bash
lspci -nn | grep -i usb
```

Example output:
```
00:14.0 USB controller [0c03]: Intel Corporation Device [8086:a36d]
```

#### Option A: Pass Entire USB Controller

Recommended for dedicated USB ports. Add the USB controller PCI ID to `/etc/modprobe.d/vfio.conf`:

```
options vfio-pci ids=10de:1c03,10de:10f1,8086:a36d
```

#### Option B: Pass Individual USB Devices

Less reliable but more flexible. Identify device:

```bash
lsusb
```

Example output:
```
Bus 001 Device 003: ID 046d:c52b Logitech, Inc. Unifying Receiver
```

In your VM configuration, add the device using vendor:product ID (`046d:c52b`).

## Setup Scripts

This repository includes helper scripts in the `scripts/` directory:

### check-iommu.sh

Checks IOMMU status and lists all IOMMU groups with devices:

```bash
./scripts/check-iommu.sh
```

### bind-vfio.sh

Dynamically binds/unbinds devices to VFIO driver:

```bash
# Bind GPU to VFIO
sudo ./scripts/bind-vfio.sh bind 01:00.0 01:00.1

# Unbind from VFIO (return to original driver)
sudo ./scripts/bind-vfio.sh unbind 01:00.0 01:00.1
```

### setup-system.sh

Automated system preparation (interactive):

```bash
sudo ./scripts/setup-system.sh
```

This script will:
- Check for virtualization support
- Enable IOMMU if needed
- Install required packages
- Configure VFIO modules
- Generate example configurations

## VM Configuration Examples

### QEMU Command Line

Example QEMU command with GPU and USB passthrough:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 8192 \
  -cpu host,kvm=off,hv_vendor_id=null \
  -smp 4,sockets=1,cores=4,threads=1 \
  -bios /usr/share/ovmf/OVMF.fd \
  -device vfio-pci,host=01:00.0,multifunction=on \
  -device vfio-pci,host=01:00.1 \
  -device vfio-pci,host=00:14.0 \
  -drive file=/var/lib/libvirt/images/win10.qcow2,format=qcow2 \
  -net nic -net user
```

### Libvirt XML

See `examples/` directory for complete libvirt XML configurations:

- `examples/windows10-gaming.xml` - Windows 10 gaming VM with GPU passthrough
- `examples/ubuntu-workstation.xml` - Ubuntu workstation with USB passthrough
- `examples/gpu-compute.xml` - GPU compute VM for machine learning

#### Quick Start with Libvirt

```bash
# Define VM from XML
virsh define examples/windows10-gaming.xml

# Start VM
virsh start windows10-gaming

# Connect with virt-manager
virt-manager
```

### Key Configuration Elements

#### GPU Passthrough in Libvirt

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
  <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
</hostdev>
```

#### USB Controller Passthrough

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x00' slot='0x14' function='0x0'/>
  </source>
</hostdev>
```

#### USB Device Passthrough

```xml
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x046d'/>
    <product id='0xc52b'/>
  </source>
</hostdev>
```

## Troubleshooting

### Common Issues

#### IOMMU Not Enabled

**Symptom**: No IOMMU groups visible or `dmesg | grep -i iommu` shows nothing.

**Solution**:
1. Enable VT-d/AMD-Vi in BIOS/UEFI
2. Verify kernel parameters in `/etc/default/grub`
3. Ensure GRUB was updated after editing
4. Reboot

#### GPU Still Used by Host

**Symptom**: `lspci -nnk` shows `nvidia` or `nouveau` driver in use.

**Solution**:
1. Verify PCI IDs in `/etc/modprobe.d/vfio.conf`
2. Check initramfs was updated
3. Ensure VFIO modules are loaded: `lsmod | grep vfio`
4. Try blacklisting nvidia/nouveau explicitly

Create `/etc/modprobe.d/blacklist-nvidia.conf`:
```
blacklist nvidia
blacklist nouveau
```

#### Code 43 Error (NVIDIA GPU in Windows)

**Symptom**: GPU shows error Code 43 in Windows Device Manager.

**Solution**:
1. Hide KVM from guest:
   ```xml
   <features>
     <hyperv>
       <vendor_id state='on' value='1234567890ab'/>
     </hyperv>
     <kvm>
       <hidden state='on'/>
     </kvm>
   </features>
   ```

2. Use QEMU flag: `-cpu host,kvm=off`

3. Ensure using UEFI (OVMF) not BIOS

#### Reset Bug (GPU Not Working After VM Shutdown)

**Symptom**: GPU stops working after VM shutdown, requires host reboot.

**Solution**:
1. Update motherboard BIOS
2. Use vendor-reset kernel module (for some AMD GPUs)
3. Use `virsh nodedev-reset` before starting VM
4. Consider GPU reset script in VM shutdown hooks

#### USB Device Not Detected

**Symptom**: USB devices not visible in guest.

**Solution**:
1. Check IOMMU group isolation
2. Try individual device passthrough instead of controller
3. Use USB 3.0 controller if available
4. Verify USB device IDs: `lsusb`

### Debug Commands

```bash
# Check IOMMU groups
./scripts/check-iommu.sh

# Verify VFIO driver
lspci -nnk -d 10de:

# Check loaded modules
lsmod | grep vfio

# View libvirt logs
journalctl -u libvirtd -f

# Test QEMU with verbose output
qemu-system-x86_64 -device vfio-pci,host=01:00.0 -d int,guest_errors

# Check VM status
virsh list --all
virsh dumpxml VM_NAME
```

## Performance Tuning

### CPU Pinning

Pin vCPUs to physical cores for better performance:

```xml
<vcpu placement='static'>4</vcpu>
<cputune>
  <vcpupin vcpu='0' cpuset='2'/>
  <vcpupin vcpu='1' cpuset='3'/>
  <vcpupin vcpu='2' cpuset='4'/>
  <vcpupin vcpu='3' cpuset='5'/>
</cputune>
```

### Hugepages

Enable hugepages for better memory performance:

```bash
# Add to kernel parameters
hugepagesz=1G hugepages=8
```

In VM XML:
```xml
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

### I/O Threads

Use I/O threads for better storage performance:

```xml
<iothreads>2</iothreads>
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' iothread='1'/>
  ...
</disk>
```

### NVIDIA-Specific

For GeForce cards, you may need to patch the driver to remove VM detection. See [nvidia-patch](https://github.com/keylase/nvidia-patch).

## Security Considerations

### Important Security Notes

1. **Device Access**: Passed-through devices have direct hardware access. Untrusted VMs could potentially attack hardware or other VMs.

2. **DMA Attacks**: VFIO provides IOMMU protection, but ensure IOMMU is properly enabled.

3. **NVIDIA Driver EULA**: Be aware of NVIDIA's licensing terms regarding virtualization, especially for GeForce cards.

4. **USB Security**: USB controller passthrough gives the VM control over all devices on that controller.

### Best Practices

- Use separate USB controllers for host and guest
- Keep host system updated
- Use UEFI Secure Boot if possible
- Isolate untrusted VMs on separate IOMMU groups
- Monitor for hardware errors: `dmesg | grep -i error`
- Regular backups of VM configurations

## Additional Resources

- [VFIO Documentation](https://www.kernel.org/doc/Documentation/vfio.txt)
- [Arch Wiki - PCI Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Reddit r/VFIO](https://www.reddit.com/r/VFIO/)
- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [Libvirt Domain XML Format](https://libvirt.org/formatdomain.html)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests with:

- Additional troubleshooting tips
- Hardware compatibility reports
- Example configurations
- Script improvements

## License

MIT License - See LICENSE file for details

## Disclaimer

This guide is provided as-is. Hardware passthrough can potentially cause system instability. Always backup your data and test in a non-production environment first.