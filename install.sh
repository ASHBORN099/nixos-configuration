#!/usr/bin/env bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

echo "------------------------------------------------------------"
echo "  NixOS Professional Installer: ilyamiro/nixos-config       "
echo "------------------------------------------------------------"

# 1. Pre-flight Checks
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL ERROR: This script must be run as root (sudo)." 
   exit 1
fi

if [ ! -f "./disko-config.nix" ] || [ ! -f "./flake.nix" ]; then
    echo "CRITICAL ERROR: Required files (disko-config.nix or flake.nix) not found in current directory."
    exit 1
fi

# 2. Hardware Detection (NVIDIA)
HAS_NVIDIA=false
if command -v lspci >/dev/null 2>&1 && lspci | grep -qi "NVIDIA"; then
    HAS_NVIDIA=true
    echo "✔ NVIDIA GPU detected. Wayland/Hyprland optimizations will be applied."
fi

# 3. Disk Selection & Safety Sanitization
echo ""
lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$4 == "disk" { print $1, $2, $3 }'
read -p "Enter the disk name to WIPE (e.g., nvme0n1 or sda): " DISK_NAME

# Handle pathing (sda -> /dev/sda)
[[ $DISK_NAME != /dev/* ]] && DISK_PATH="/dev/$DISK_NAME" || DISK_PATH="$DISK_NAME"

if [ ! -b "$DISK_PATH" ]; then
    echo "ERROR: $DISK_PATH is not a valid block device."
    exit 1
fi

# 4. User Identity
read -p "Enter your desired username: " NEW_USER
if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "ERROR: Invalid Linux username '$NEW_USER'."
    exit 1
fi

# 5. The "Double-Lock" Safety Confirmation
echo ""
echo "!!! WARNING: ALL DATA ON $DISK_PATH WILL BE PERMANENTLY ERASED !!!"
read -p "Type 'CONFIRM' to proceed: " confirm
if [ "$confirm" != "CONFIRM" ]; then
    echo "Aborting. No changes made."
    exit 1
fi

read -p "FINAL CHECK: Type the exact disk path ($DISK_PATH) to start: " final_check
if [ "$final_check" != "$DISK_PATH" ]; then
    echo "Confirmation failed. Aborting."
    exit 1
fi

# Clean up stale mounts if a previous attempt failed
if findmnt -R /mnt >/dev/null 2>&1; then
    echo "Cleaning up stale mounts under /mnt..."
    umount -R /mnt || true
fi

# 6. Step 1: Partitioning with Disko
echo "--- [1/4] Partitioning and Formatting ---"
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --mode disko \
    --argstr device "$DISK_PATH" \
    ./disko-config.nix

# 7. Step 2: Global Username Patching
echo "--- [2/4] Patching configuration for user: $NEW_USER ---"
# Replaces 'ilyamiro' with your name in all .nix files recursively
find . -type f -name "*.nix" -exec sed -i "s/ilyamiro/$NEW_USER/g" {} +

# 8. Step 3: Hardware Generation & Injection
echo "--- [3/4] Detecting Hardware & Generating Config ---"
nixos-generate-config --root /mnt
# Inject the detected hardware into the Flake's host directory
# Note: Adjust path if the repo structure uses a different folder for hosts
cp /mnt/etc/nixos/hardware-configuration.nix ./hosts/default/hardware-configuration.nix

# 9. Step 4: Flake-Based Installation
echo "--- [4/4] Starting NixOS Installation (Flake Mode) ---"
nixos-install --no-root-passwd --flake .#default

echo "------------------------------------------------------------"
echo "  SUCCESS: System installed. Remove USB and reboot.         "
echo "------------------------------------------------------------"
