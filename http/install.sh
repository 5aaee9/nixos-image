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

echo "git clone https://github.com/Indexyz/dotfiles.git /mnt/etc/dotfiles" | nix-shell -p git --run bash
ln -sr /mnt/etc/dotfiles/nixos/ /mnt/etc/nixos

cat > /mnt/etc/nixos/hardware-configuration.nix <<EOF
{ config, lib, pkgs, modulesPath, ... }:

{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        ./profile/vm.nix
    ];

    boot.initrd.availableKernelModules = [
        "ata_plix" "virtio_pci" "floppy" "sr_mod" "virtio_blk"
    ];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    boot.loader.grub = {
        "enable" = true;
        "version" = 2;
        "device" = "/dev/vda";
    };

    fileSystems = {
        "/" = {
            device = "/dev/disk/by-uuid/$ROOT_UUID";
            fsType = "ext4";
        };
        "/boot" = {
            device = "/dev/disk/by-uuid/$BOOT_UUID";
            fsType = "ext4";
        };
    };
}
EOF

passwd root <<EOF
packer
packer
EOF
