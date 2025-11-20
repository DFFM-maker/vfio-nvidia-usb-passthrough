#!/bin/bash

# bind-vfio.sh
# Script to dynamically bind/unbind PCI devices to/from VFIO driver

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Usage information
usage() {
    cat << EOF
Usage: $0 <bind|unbind> <PCI_ADDRESS> [PCI_ADDRESS...]

Bind or unbind PCI devices to/from the VFIO driver.

Commands:
  bind      Bind device(s) to vfio-pci driver
  unbind    Unbind device(s) from vfio-pci driver (return to original driver)

Examples:
  $0 bind 01:00.0 01:00.1
  $0 unbind 01:00.0 01:00.1

PCI Address Format: BB:DD.F (Bus:Device.Function)
  - Find your device addresses with: lspci
  - Use format like: 01:00.0

EOF
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

ACTION=$1
shift

# Validate action
if [ "$ACTION" != "bind" ] && [ "$ACTION" != "unbind" ]; then
    echo -e "${RED}Error: Invalid action '$ACTION'${NC}"
    usage
fi

# Load VFIO modules if binding
if [ "$ACTION" = "bind" ]; then
    echo -e "${BLUE}Loading VFIO modules...${NC}"
    modprobe vfio 2>/dev/null || true
    modprobe vfio_iommu_type1 2>/dev/null || true
    modprobe vfio_pci 2>/dev/null || true
    echo -e "${GREEN}✓ VFIO modules loaded${NC}"
fi

# Process each device
for PCI_ADDR in "$@"; do
    echo ""
    echo -e "${BLUE}Processing device: $PCI_ADDR${NC}"
    
    # Validate PCI address format
    if ! [[ $PCI_ADDR =~ ^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
        echo -e "${RED}Error: Invalid PCI address format: $PCI_ADDR${NC}"
        echo "Expected format: BB:DD.F (e.g., 01:00.0)"
        continue
    fi
    
    # Normalize address to 0000:BB:DD.F format
    FULL_ADDR="0000:$PCI_ADDR"
    DEVICE_PATH="/sys/bus/pci/devices/$FULL_ADDR"
    
    # Check if device exists
    if [ ! -d "$DEVICE_PATH" ]; then
        echo -e "${RED}Error: Device $PCI_ADDR not found${NC}"
        continue
    fi
    
    # Get device info
    DEVICE_INFO=$(lspci -nns $PCI_ADDR)
    echo "  Device: $DEVICE_INFO"
    
    # Get current driver
    CURRENT_DRIVER=""
    if [ -e "$DEVICE_PATH/driver" ]; then
        CURRENT_DRIVER=$(basename $(readlink "$DEVICE_PATH/driver"))
        echo "  Current driver: $CURRENT_DRIVER"
    else
        echo "  Current driver: none"
    fi
    
    if [ "$ACTION" = "bind" ]; then
        # Bind to VFIO
        if [ "$CURRENT_DRIVER" = "vfio-pci" ]; then
            echo -e "  ${YELLOW}Already bound to vfio-pci${NC}"
            continue
        fi
        
        # Get vendor and device IDs
        VENDOR_ID=$(cat "$DEVICE_PATH/vendor" | sed 's/0x//')
        DEVICE_ID=$(cat "$DEVICE_PATH/device" | sed 's/0x//')
        
        # Unbind from current driver if any
        if [ -n "$CURRENT_DRIVER" ]; then
            echo "  Unbinding from $CURRENT_DRIVER..."
            echo "$FULL_ADDR" > "$DEVICE_PATH/driver/unbind" || {
                echo -e "${RED}  Failed to unbind from $CURRENT_DRIVER${NC}"
                continue
            }
        fi
        
        # Add device ID to VFIO driver
        echo "  Adding device ID to vfio-pci..."
        echo "$VENDOR_ID $DEVICE_ID" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
        
        # Bind to vfio-pci
        echo "  Binding to vfio-pci..."
        echo "$FULL_ADDR" > /sys/bus/pci/drivers/vfio-pci/bind || {
            echo -e "${RED}  Failed to bind to vfio-pci${NC}"
            continue
        }
        
        echo -e "  ${GREEN}✓ Successfully bound to vfio-pci${NC}"
        
    else
        # Unbind from VFIO
        if [ "$CURRENT_DRIVER" != "vfio-pci" ]; then
            echo -e "  ${YELLOW}Not bound to vfio-pci (currently: ${CURRENT_DRIVER:-none})${NC}"
            continue
        fi
        
        echo "  Unbinding from vfio-pci..."
        echo "$FULL_ADDR" > "$DEVICE_PATH/driver/unbind" || {
            echo -e "${RED}  Failed to unbind from vfio-pci${NC}"
            continue
        }
        
        # Trigger rescan to let kernel bind appropriate driver
        echo "  Rescanning PCI bus..."
        echo 1 > /sys/bus/pci/rescan
        
        sleep 1
        
        # Check new driver
        if [ -e "$DEVICE_PATH/driver" ]; then
            NEW_DRIVER=$(basename $(readlink "$DEVICE_PATH/driver"))
            echo -e "  ${GREEN}✓ Successfully unbound, now using: $NEW_DRIVER${NC}"
        else
            echo -e "  ${YELLOW}✓ Successfully unbound (no driver bound)${NC}"
        fi
    fi
done

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Operation complete!${NC}"
echo ""
echo "Verify with: lspci -nnk -d <vendor:device>"
echo -e "${BLUE}======================================${NC}"
