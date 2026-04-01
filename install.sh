#!/usr/bin/env bash

# Exit on any error
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

is_pinned_disko_ref() {
    local ref="$1"

    # Accept commit-pinned form: github:nix-community/disko/<40-hex-commit>
    if [[ "$ref" =~ ^github:nix-community/disko/[0-9a-fA-F]{40}$ ]]; then
        return 0
    fi

    # Accept explicit rev pin in query parameters.
    if [[ "$ref" =~ ^github:nix-community/disko\?.*rev=[0-9a-fA-F]{40} ]]; then
        return 0
    fi

    return 1
}

echo "------------------------------------------------------------"
echo "  NixOS Professional Installer: ilyamiro/nixos-config       "
echo "------------------------------------------------------------"

# 0. Preflight checks
for cmd in nix lsblk sed find cp nixos-generate-config nixos-install; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "CRITICAL ERROR: Required command '$cmd' is not available."
        exit 1
    fi
done

if ! command -v lspci >/dev/null 2>&1; then
    echo "WARNING: 'lspci' not found; NVIDIA auto-detection will be skipped."
fi

if [ ! -f "./disko-config.nix" ]; then
    echo "CRITICAL ERROR: ./disko-config.nix was not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "./configuration.nix" ]; then
    echo "CRITICAL ERROR: ./configuration.nix is missing; required for non-flake nixos-install"
    exit 1
fi

DISKO_FLAKE_REF="${DISKO_FLAKE_REF:-github:nix-community/disko}"
if ! is_pinned_disko_ref "$DISKO_FLAKE_REF"; then
    echo "CRITICAL ERROR: DISKO_FLAKE_REF is not pinned to a commit."
    echo "Set DISKO_FLAKE_REF like one of:"
    echo "  github:nix-community/disko/<40-hex-commit>"
    echo "  github:nix-community/disko?rev=<40-hex-commit>"
    exit 1
fi

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL ERROR: This script must be run as root (sudo)." 
   exit 1
fi

# 2. Hardware Detection (NVIDIA)
if command -v lspci >/dev/null 2>&1 && lspci | grep -qi "NVIDIA"; then
    echo "NVIDIA GPU detected."
fi

# 3. Disk Selection & Sanitization
echo ""
lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$4 == "disk" { print $1, $2, $3 }'
read -p "Enter the disk name to WIPE (e.g., nvme0n1 or sda): " DISK_NAME

# Ensure we have a full path (handle 'sda' vs '/dev/sda')
[[ $DISK_NAME != /dev/* ]] && DISK_PATH="/dev/$DISK_NAME" || DISK_PATH="$DISK_NAME"

if [ ! -b "$DISK_PATH" ]; then
    echo "ERROR: $DISK_PATH is not a valid block device."
    exit 1
fi

DISK_TYPE="$(lsblk -ndo TYPE "$DISK_PATH" 2>/dev/null | head -n1 || true)"
if [ "$DISK_TYPE" != "disk" ]; then
    echo "ERROR: $DISK_PATH is not a whole disk (detected type: ${DISK_TYPE:-unknown})."
    echo "Select a full disk like /dev/sda or /dev/nvme0n1, not a partition."
    exit 1
fi

if lsblk -rno MOUNTPOINT "$DISK_PATH" | grep -qE '^/'; then
    echo "ERROR: $DISK_PATH has mounted filesystems. Refusing to continue."
    lsblk -o NAME,TYPE,MOUNTPOINT "$DISK_PATH"
    exit 1
fi

# 4. Personalization
read -p "Enter your desired username: " NEW_USER

if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
    echo "ERROR: Invalid Linux username '$NEW_USER'."
    exit 1
fi
echo ""

# 5. The "Point of No Return" Safety Valve
echo "!!! WARNING: ALL DATA ON $DISK_PATH WILL BE PERMANENTLY ERASED !!!"
echo "This will create a 512MB Boot partition and a Root partition."
read -p "Type 'CONFIRM' to proceed: " confirm
if [ "$confirm" != "CONFIRM" ]; then
    echo "Aborting installation. No changes were made."
    exit 1
fi

read -p "Final check: type the exact disk path ($DISK_PATH) to continue: " final_disk
if [ "$final_disk" != "$DISK_PATH" ]; then
    echo "Aborting installation. Disk confirmation did not match."
    exit 1
fi

# Retry-safe cleanup if a previous run left stale mounts under /mnt.
if findmnt -R /mnt >/dev/null 2>&1; then
    echo "Detected existing mounts under /mnt from a previous run. Attempting cleanup..."
    umount -R /mnt || {
        echo "ERROR: Could not unmount /mnt recursively. Please unmount manually and retry."
        exit 1
    }
fi

# 6. Partitioning with Disko
echo "--- Step 1/4: Partitioning and Formatting ---"
nix --experimental-features "nix-command flakes" run "$DISKO_FLAKE_REF" -- \
    --mode disko \
    --argstr device "$DISK_PATH" \
    ./disko-config.nix

# 7. Patching the Configuration (Username replacement)
echo "--- Step 2/4: Patching Files for $NEW_USER ---"
ESCAPED_NEW_USER="$(printf '%s' "$NEW_USER" | sed 's/[\\/&]/\\\\&/g')"
mapfile -t TARGET_NIX_FILES < <(grep -rl --include="*.nix" "ilyamiro" . || true)
if [ "${#TARGET_NIX_FILES[@]}" -gt 0 ]; then
    for nix_file in "${TARGET_NIX_FILES[@]}"; do
        sed -i "s/ilyamiro/$ESCAPED_NEW_USER/g" "$nix_file"
    done
else
    echo "No .nix files containing 'ilyamiro' were found. Skipping replacement."
fi

# 8. Hardware Generation & Sync
echo "--- Step 3/4: Generating and Syncing NixOS Configuration ---"
nixos-generate-config --root /mnt

# Stage repository configuration into /mnt for non-flake install.
mkdir -p /mnt/etc/nixos
cp ./configuration.nix /mnt/etc/nixos/configuration.nix

if [ -f "./home.nix" ]; then
    cp ./home.nix /mnt/etc/nixos/home.nix
fi

if [ -d "./config" ]; then
    cp -a ./config /mnt/etc/nixos/
fi

# Keep a local copy of detected hardware config in repo root.
cp /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix

# 9. Final Installation
echo "--- Step 4/4: Starting nixos-install ---"
nixos-install --no-root-passwd

echo "------------------------------------------------------------"
echo "  SUCCESS: Installation Complete! Please reboot.            "
echo "------------------------------------------------------------"