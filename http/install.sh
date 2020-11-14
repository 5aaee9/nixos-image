set -x

DISK=/dev/vda

echo "* Partitioning disk"

# Create new disk part with fdisk
#
#   1 /boot 512M
#   2 /     all
fdisk $DISK <<EOF
o
n
p


+512M
n
p



p
w
EOF

mkfs.ext4 $DISK"1"
mkfs.ext4 $DISK"2"

mount $DISK"2" /mnt
mkdir /mnt/boot
mount $DISK"1" /mnt/boot

# Create hardware config

ROOT_UUID=`blkid --output value /dev/vda2 | head -n 1 | tr -d  '[:space:]'`
BOOT_UUID=`blkid --output value /dev/vda1 | head -n 1 | tr -d  '[:space:]'`

cat > /dev/stdout <<EOF
{ config, lib, pkgs, modulesPath, ... }:

{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
    ];

    boot.initrd.availableKernelModules = [
        "ata_plix" "virtio_pci" "floppy" "sr_mod" "virtio_blk"
    ];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    fileSystem = {
        "/" = {
            device = "/dev/disk/by-uuid/$ROOT_UUID";
            fsType = "ext4";
        }
        "/boot" = {
            device = "/dev/disk/by-uuid/$BOOT_UUID";
            fsType = "ext4";
        }
    }
}

EOF