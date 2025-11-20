# Example VM Configurations

This directory contains example libvirt XML configurations for different use cases.

## Available Examples

### windows10-gaming.xml
A fully-featured Windows 10 gaming VM with:
- NVIDIA GPU passthrough
- CPU pinning for optimal performance
- Hyper-V enlightenments to avoid Code 43 error
- KVM hidden state
- UEFI firmware
- 16GB RAM, 8 vCPUs

**Use case**: Gaming, GPU-intensive Windows applications

### ubuntu-workstation.xml
Ubuntu desktop VM with:
- USB controller passthrough for direct USB device access
- CPU pinning
- 8GB RAM, 4 vCPUs
- UEFI firmware

**Use case**: Development work requiring specific USB hardware, USB device testing

### gpu-compute.xml
Minimal compute VM with:
- NVIDIA GPU passthrough
- No display (headless)
- SSH access via serial console
- Separate data disk
- 16GB RAM, 8 vCPUs

**Use case**: Machine learning, GPU computing, rendering farms

## How to Use These Examples

### 1. Identify Your Hardware

Run the check-iommu script to find your device addresses:

```bash
./scripts/check-iommu.sh
```

Note the PCI addresses of:
- Your NVIDIA GPU (e.g., `01:00.0`)
- Your NVIDIA GPU audio device (e.g., `01:00.1`)
- Your USB controller if needed (e.g., `00:14.0`)

### 2. Customize the Configuration

Edit the XML file and replace the PCI addresses in the `<hostdev>` sections:

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <!-- Replace these values with your actual device addresses -->
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
  <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
</hostdev>
```

Convert your PCI address from `BB:DD.F` format to XML format:
- `01:00.0` becomes: `bus='0x01' slot='0x00' function='0x0'`
- `00:14.0` becomes: `bus='0x00' slot='0x14' function='0x0'`

### 3. Update Disk Paths

Change the disk paths to match your setup:

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='writeback'/>
  <source file='/var/lib/libvirt/images/YOUR-VM-NAME.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

Create the disk image:

```bash
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/YOUR-VM-NAME.qcow2 120G
```

### 4. Adjust CPU Pinning

Check your CPU topology:

```bash
lscpu -e
```

Adjust the `<vcpupin>` settings to match your available CPUs. It's best to:
- Reserve CPU 0 for the host
- Pin guest vCPUs to physical cores on the same die/socket
- Use sibling threads for the same vCPU if using SMT/Hyper-Threading

Example for CPUs 2-9:
```xml
<cputune>
  <vcpupin vcpu='0' cpuset='2'/>
  <vcpupin vcpu='1' cpuset='3'/>
  <vcpupin vcpu='2' cpuset='4'/>
  <vcpupin vcpu='3' cpuset='5'/>
  <!-- ... -->
</cputune>
```

### 5. Define and Start the VM

```bash
# Define the VM (makes it known to libvirt)
sudo virsh define examples/windows10-gaming.xml

# List all VMs to verify
sudo virsh list --all

# Start the VM
sudo virsh start windows10-gaming

# Connect with virt-manager (GUI)
sudo virt-manager

# Or connect to console
sudo virsh console windows10-gaming
```

## Additional Configuration Options

### Individual USB Device Passthrough

Instead of passing an entire USB controller, you can pass individual devices:

```xml
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x046d'/>
    <product id='0xc52b'/>
  </source>
</hostdev>
```

Find vendor/product IDs with `lsusb`.

### Enable Hugepages for Better Performance

On the host:

```bash
# Add to kernel parameters
hugepagesz=1G hugepages=20
```

In VM XML:

```xml
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

### Looking Glass for Display Sharing

[Looking Glass](https://looking-glass.io/) allows you to view the GPU output without a second monitor:

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>32</size>
</shmem>
```

### SCREAM for Audio

Use [SCREAM](https://github.com/duncanthrax/scream) for low-latency audio from Windows guests over the network.

## Troubleshooting

### VM Won't Start

Check libvirt logs:
```bash
sudo journalctl -u libvirtd -f
```

Validate XML:
```bash
sudo virt-xml-validate examples/windows10-gaming.xml
```

### GPU Not Working in Guest

1. Verify device is bound to vfio-pci on host: `lspci -nnk`
2. Check VM has KVM hidden: `<kvm><hidden state='on'/></kvm>`
3. Verify vendor_id is set in hyperv section
4. Ensure using UEFI (OVMF) not BIOS

### USB Devices Not Detected

1. Verify entire IOMMU group is passed or properly isolated
2. Try passing individual USB devices instead of controller
3. Check USB version (3.0 controller recommended)

## Performance Tips

1. **CPU Governor**: Set to `performance` mode
   ```bash
   sudo cpupower frequency-set -g performance
   ```

2. **Disable C-States**: Add to kernel parameters: `processor.max_cstate=1`

3. **MSI/MSI-X**: Most modern GPUs use this automatically, but verify in guest

4. **I/O Thread**: Use separate I/O threads for disks (examples include this)

5. **Network**: Use virtio-net for best performance

## Resources

- Main repository README for setup instructions
- [Libvirt Domain XML Documentation](https://libvirt.org/formatdomain.html)
- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [Arch Wiki - PCI Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
