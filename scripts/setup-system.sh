#!/bin/bash

# setup-system.sh
# Interactive script to prepare system for VFIO GPU/USB passthrough

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  VFIO Passthrough System Setup${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "This script will help you prepare your system for"
echo "GPU and USB passthrough using VFIO."
echo ""

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo -e "${RED}Cannot detect distribution${NC}"
    exit 1
fi

echo -e "${GREEN}Detected distribution: $PRETTY_NAME${NC}"
echo ""

# Step 1: Check virtualization support
echo -e "${BLUE}[Step 1/6] Checking virtualization support${NC}"
if grep -qE 'vmx|svm' /proc/cpuinfo; then
    if grep -q vmx /proc/cpuinfo; then
        CPU_TYPE="intel"
        echo -e "${GREEN}✓ Intel VT-x detected${NC}"
    else
        CPU_TYPE="amd"
        echo -e "${GREEN}✓ AMD-V detected${NC}"
    fi
else
    echo -e "${RED}✗ CPU virtualization not supported or disabled${NC}"
    echo "Please enable VT-x (Intel) or AMD-V (AMD) in BIOS"
    exit 1
fi
echo ""

# Step 2: Check IOMMU status
echo -e "${BLUE}[Step 2/6] Checking IOMMU status${NC}"
IOMMU_ENABLED=0
if dmesg | grep -qi "iommu.*enabled"; then
    echo -e "${GREEN}✓ IOMMU is enabled${NC}"
    IOMMU_ENABLED=1
else
    echo -e "${YELLOW}! IOMMU is not enabled${NC}"
fi
echo ""

# Step 3: Install required packages
echo -e "${BLUE}[Step 3/6] Installing required packages${NC}"
read -p "Install virtualization packages? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
                bridge-utils virt-manager ovmf
            ;;
        fedora|rhel|centos)
            dnf install -y @virtualization ovmf
            ;;
        arch|manjaro)
            pacman -S --noconfirm qemu libvirt edk2-ovmf virt-manager
            ;;
        *)
            echo -e "${YELLOW}Unknown distribution, skipping package installation${NC}"
            ;;
    esac
    echo -e "${GREEN}✓ Packages installed${NC}"
else
    echo "Skipping package installation"
fi
echo ""

# Step 4: Configure GRUB for IOMMU
echo -e "${BLUE}[Step 4/6] Configuring GRUB${NC}"
if [ $IOMMU_ENABLED -eq 0 ]; then
    read -p "Enable IOMMU in GRUB? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        GRUB_FILE="/etc/default/grub"
        
        # Backup GRUB config
        cp "$GRUB_FILE" "$GRUB_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Determine IOMMU parameters
        if [ "$CPU_TYPE" = "intel" ]; then
            IOMMU_PARAMS="intel_iommu=on iommu=pt"
        else
            IOMMU_PARAMS="amd_iommu=on iommu=pt"
        fi
        
        # Check if already configured
        if grep -q "$IOMMU_PARAMS" "$GRUB_FILE"; then
            echo -e "${GREEN}✓ GRUB already configured for IOMMU${NC}"
        else
            # Add IOMMU parameters
            sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$IOMMU_PARAMS /" "$GRUB_FILE"
            echo -e "${GREEN}✓ Added IOMMU parameters to GRUB${NC}"
            
            # Update GRUB
            echo "Updating GRUB..."
            if [ -f /etc/debian_version ]; then
                update-grub
            elif [ -f /etc/redhat-release ]; then
                grub2-mkconfig -o /boot/grub2/grub.cfg
            else
                grub-mkconfig -o /boot/grub/grub.cfg
            fi
            echo -e "${GREEN}✓ GRUB updated${NC}"
            echo -e "${YELLOW}! Reboot required for IOMMU to take effect${NC}"
        fi
    fi
else
    echo "IOMMU already enabled"
fi
echo ""

# Step 5: Configure VFIO modules
echo -e "${BLUE}[Step 5/6] Configuring VFIO modules${NC}"
read -p "Configure VFIO modules to load at boot? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    VFIO_CONF="/etc/modules-load.d/vfio.conf"
    
    if [ -f "$VFIO_CONF" ]; then
        echo -e "${GREEN}✓ VFIO modules already configured${NC}"
    else
        cat > "$VFIO_CONF" << EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
        echo -e "${GREEN}✓ Created $VFIO_CONF${NC}"
    fi
else
    echo "Skipping VFIO module configuration"
fi
echo ""

# Step 6: Identify devices for passthrough
echo -e "${BLUE}[Step 6/6] Identifying devices${NC}"
echo ""
echo -e "${CYAN}NVIDIA GPUs:${NC}"
lspci -nn | grep -i nvidia || echo "  No NVIDIA devices found"
echo ""
echo -e "${CYAN}USB Controllers:${NC}"
lspci -nn | grep -i "usb controller" || echo "  No USB controllers found"
echo ""

read -p "Configure specific devices for VFIO? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter PCI vendor:device IDs to bind to VFIO at boot"
    echo "Format: 10de:1c03,10de:10f1 (comma-separated, no spaces)"
    echo "Press Enter to skip"
    read -p "Device IDs: " DEVICE_IDS
    
    if [ -n "$DEVICE_IDS" ]; then
        VFIO_PCI_CONF="/etc/modprobe.d/vfio.conf"
        
        # Backup if exists
        [ -f "$VFIO_PCI_CONF" ] && cp "$VFIO_PCI_CONF" "$VFIO_PCI_CONF.backup.$(date +%Y%m%d_%H%M%S)"
        
        cat > "$VFIO_PCI_CONF" << EOF
options vfio-pci ids=$DEVICE_IDS
softdep nvidia pre: vfio-pci
softdep nouveau pre: vfio-pci
EOF
        echo -e "${GREEN}✓ Created $VFIO_PCI_CONF${NC}"
        
        # Update initramfs
        echo "Updating initramfs..."
        if [ -f /etc/debian_version ]; then
            update-initramfs -u
        elif [ -f /etc/redhat-release ]; then
            dracut -f
        elif [ -f /etc/arch-release ]; then
            mkinitcpio -P
        fi
        echo -e "${GREEN}✓ Initramfs updated${NC}"
        echo -e "${YELLOW}! Reboot required for device binding to take effect${NC}"
    fi
fi
echo ""

# Summary
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot your system if GRUB or device bindings were changed"
echo "  2. Run: ./check-iommu.sh to verify configuration"
echo "  3. Create your VM configuration"
echo "  4. See examples/ directory for sample configs"
echo ""
echo "Additional tools:"
echo "  - check-iommu.sh: Check IOMMU groups and device status"
echo "  - bind-vfio.sh: Dynamically bind/unbind devices"
echo ""
echo -e "${CYAN}============================================${NC}"
