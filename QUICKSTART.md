# Quick Start Guide

This is a condensed quick-start guide for experienced users. For detailed instructions, see [README.md](README.md).

## Prerequisites Checklist

- [ ] CPU with VT-x/VT-d (Intel) or AMD-V/AMD-Vi (AMD)
- [ ] IOMMU enabled in BIOS/UEFI
- [ ] NVIDIA GPU not in use by host
- [ ] Separate USB controller (optional, for USB passthrough)

## Quick Setup (5 Steps)

### 1. Enable IOMMU

Edit `/etc/default/grub`:

```bash
# Intel
GRUB_CMDLINE_LINUX_DEFAULT="... intel_iommu=on iommu=pt"

# AMD
GRUB_CMDLINE_LINUX_DEFAULT="... amd_iommu=on iommu=pt"
```

Update GRUB and reboot:
```bash
sudo update-grub && sudo reboot
```

### 2. Install Packages

```bash
# Ubuntu/Debian
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager ovmf

# Fedora
sudo dnf install @virtualization ovmf

# Arch
sudo pacman -S qemu libvirt edk2-ovmf virt-manager
```

### 3. Identify Devices

```bash
./scripts/check-iommu.sh
```

Note your GPU PCI IDs (e.g., `10de:1c03,10de:10f1`).

### 4. Bind GPU to VFIO

Create `/etc/modprobe.d/vfio.conf`:

```bash
options vfio-pci ids=10de:1c03,10de:10f1
softdep nvidia pre: vfio-pci
softdep nouveau pre: vfio-pci
```

Create `/etc/modules-load.d/vfio.conf`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Update initramfs and reboot:

```bash
# Ubuntu/Debian
sudo update-initramfs -u && sudo reboot

# Fedora
sudo dracut -f && sudo reboot

# Arch
sudo mkinitcpio -P && sudo reboot
```

### 5. Create VM

```bash
# Customize example config
cp examples/windows10-gaming.xml my-vm.xml
nano my-vm.xml  # Update PCI addresses

# Define and start
sudo virsh define my-vm.xml
sudo virsh start my-vm-name
```

## Automated Setup

For interactive setup:

```bash
sudo ./scripts/setup-system.sh
```

## Common Commands

```bash
# Check IOMMU status
./scripts/check-iommu.sh

# Bind device to VFIO
sudo ./scripts/bind-vfio.sh bind 01:00.0 01:00.1

# Unbind device from VFIO
sudo ./scripts/bind-vfio.sh unbind 01:00.0 01:00.1

# List VMs
sudo virsh list --all

# Start VM
sudo virsh start VM-NAME

# Stop VM
sudo virsh shutdown VM-NAME

# Force stop VM
sudo virsh destroy VM-NAME

# Open virt-manager
sudo virt-manager
```

## Troubleshooting Quick Fixes

### IOMMU Not Enabled
```bash
dmesg | grep -i iommu
# If nothing shows, check BIOS and kernel parameters
```

### GPU Not Bound to VFIO
```bash
lspci -nnk -d 10de:
# Should show: Kernel driver in use: vfio-pci
```

### Windows Code 43 Error
Ensure in VM XML:
```xml
<kvm>
  <hidden state='on'/>
</kvm>
<hyperv>
  <vendor_id state='on' value='1234567890ab'/>
</hyperv>
```

### GPU Reset Bug
Add to host:
```bash
# Install vendor-reset (for AMD)
# Or use nodedev-reset before starting VM
sudo virsh nodedev-reset pci_0000_01_00_0
```

## Performance Tuning

```bash
# CPU governor to performance
sudo cpupower frequency-set -g performance

# Hugepages
# Add to kernel: hugepagesz=1G hugepages=16
```

In VM XML:
```xml
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

## Resources

- **Full Guide**: [README.md](README.md)
- **Example Configs**: [examples/](examples/)
- **Scripts**: [scripts/](scripts/)
- **Arch Wiki**: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
- **r/VFIO**: https://reddit.com/r/VFIO

## Need Help?

1. Run `./scripts/check-iommu.sh` and share output
2. Check `dmesg | grep -i vfio` for errors
3. Review VM logs: `sudo journalctl -u libvirtd -f`
4. See [README.md](README.md) troubleshooting section
