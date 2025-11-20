#!/bin/bash

# check-iommu.sh
# Script to check IOMMU status and list all IOMMU groups with devices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}    IOMMU Configuration Checker${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Note: Running as root (not required for this script)${NC}"
fi

# Check CPU virtualization support
echo -e "${GREEN}[1] Checking CPU Virtualization Support${NC}"
if grep -qE 'vmx|svm' /proc/cpuinfo; then
    echo -e "  ${GREEN}✓${NC} CPU supports virtualization"
    if grep -q vmx /proc/cpuinfo; then
        echo "    Type: Intel VT-x"
    else
        echo "    Type: AMD-V"
    fi
else
    echo -e "  ${RED}✗${NC} CPU does not support virtualization or it's disabled in BIOS"
    echo "    Please enable VT-x (Intel) or AMD-V (AMD) in BIOS/UEFI"
    exit 1
fi
echo ""

# Check IOMMU status in kernel
echo -e "${GREEN}[2] Checking IOMMU Status${NC}"
if dmesg | grep -qi "iommu.*enabled"; then
    echo -e "  ${GREEN}✓${NC} IOMMU is enabled"
    
    # Show IOMMU type
    if dmesg | grep -qi "intel.*iommu"; then
        echo "    Type: Intel VT-d"
    elif dmesg | grep -qi "amd.*iommu"; then
        echo "    Type: AMD-Vi"
    fi
    
    # Show relevant dmesg lines
    echo ""
    echo "  Relevant kernel messages:"
    dmesg | grep -i iommu | head -5 | sed 's/^/    /'
else
    echo -e "  ${RED}✗${NC} IOMMU is not enabled"
    echo ""
    echo "  To enable IOMMU:"
    echo "    1. Enable VT-d/AMD-Vi in BIOS/UEFI"
    echo "    2. Edit /etc/default/grub and add to GRUB_CMDLINE_LINUX_DEFAULT:"
    echo "       Intel: intel_iommu=on iommu=pt"
    echo "       AMD:   amd_iommu=on iommu=pt"
    echo "    3. Update GRUB: sudo update-grub (or grub-mkconfig)"
    echo "    4. Reboot"
    exit 1
fi
echo ""

# Check VFIO modules
echo -e "${GREEN}[3] Checking VFIO Kernel Modules${NC}"
if lsmod | grep -q vfio; then
    echo -e "  ${GREEN}✓${NC} VFIO modules are loaded"
    lsmod | grep vfio | sed 's/^/    /'
else
    echo -e "  ${YELLOW}!${NC} VFIO modules are not loaded (will be loaded when needed)"
fi
echo ""

# Check for IOMMU groups
echo -e "${GREEN}[4] Listing IOMMU Groups${NC}"
if [ ! -d /sys/kernel/iommu_groups ]; then
    echo -e "  ${RED}✗${NC} No IOMMU groups found"
    exit 1
fi

shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo -e "  ${BLUE}IOMMU Group ${g##*/}${NC}"
    for d in $g/devices/*; do
        device_info=$(lspci -nns ${d##*/} 2>/dev/null)
        if [ -n "$device_info" ]; then
            # Check if using vfio-pci driver
            driver=$(lspci -ks ${d##*/} 2>/dev/null | grep "Kernel driver in use:" | awk '{print $5}')
            if [ "$driver" = "vfio-pci" ]; then
                echo -e "    ${GREEN}[VFIO]${NC} $device_info"
            else
                echo "    $device_info"
            fi
            if [ -n "$driver" ]; then
                echo "           Driver: $driver"
            fi
        fi
    done
    echo ""
done

# Highlight NVIDIA devices
echo -e "${GREEN}[5] NVIDIA Devices Found${NC}"
nvidia_devices=$(lspci -nn | grep -i nvidia || true)
if [ -n "$nvidia_devices" ]; then
    echo "$nvidia_devices" | while read line; do
        pci_id=$(echo "$line" | awk '{print $1}')
        # Get vendor:device IDs
        ids=$(echo "$line" | grep -oP '\[.*?\]' | tail -1 | tr -d '[]')
        driver=$(lspci -ks $pci_id 2>/dev/null | grep "Kernel driver in use:" | awk '{print $5}')
        
        if [ "$driver" = "vfio-pci" ]; then
            echo -e "  ${GREEN}[VFIO]${NC} $line"
        elif [ "$driver" = "nvidia" ] || [ "$driver" = "nouveau" ]; then
            echo -e "  ${YELLOW}[HOST]${NC} $line"
        else
            echo -e "  $line"
        fi
        echo "         PCI ID: $pci_id, Vendor:Device: $ids"
        [ -n "$driver" ] && echo "         Driver: $driver"
    done
else
    echo "  No NVIDIA devices found"
fi
echo ""

# Highlight USB controllers
echo -e "${GREEN}[6] USB Controllers Found${NC}"
usb_controllers=$(lspci -nn | grep -i "usb controller" || true)
if [ -n "$usb_controllers" ]; then
    echo "$usb_controllers" | while read line; do
        pci_id=$(echo "$line" | awk '{print $1}')
        ids=$(echo "$line" | grep -oP '\[.*?\]' | tail -1 | tr -d '[]')
        driver=$(lspci -ks $pci_id 2>/dev/null | grep "Kernel driver in use:" | awk '{print $5}')
        
        if [ "$driver" = "vfio-pci" ]; then
            echo -e "  ${GREEN}[VFIO]${NC} $line"
        else
            echo -e "  $line"
        fi
        echo "         PCI ID: $pci_id, Vendor:Device: $ids"
        [ -n "$driver" ] && echo "         Driver: $driver"
    done
else
    echo "  No USB controllers found"
fi
echo ""

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Check complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Note the PCI IDs of devices you want to pass through"
echo "  2. Check that devices are in separate IOMMU groups (or entire group can be passed)"
echo "  3. Use bind-vfio.sh to bind devices to VFIO driver"
echo "  4. Configure your VM with the device PCI addresses"
echo -e "${BLUE}======================================${NC}"
