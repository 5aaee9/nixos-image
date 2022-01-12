set -x

# How to resize btrfs
# parted /dev/vda resizepart 2 100%
# btrfs filesystem resize max /

DISK=/dev/vda

echo "* Partitioning disk"

if [ "$UEFI_BUILD" == "yes" ]; then
gdisk $DISK <<EOF
o
y
n


+512M
ef00
n




p
w
y
EOF
else
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
fi
if [ "$UEFI_BUILD" == "yes" ]; then
mkfs.fat $DISK"1"
else
mkfs.ext4 $DISK"1"
fi

zpool create -o autotrim=on -o autoexpand=on -O compression=zstd -O mountpoint=none tank $DISK"2"
zfs create -o mountpoint=legacy tank/nix

# Journald requires xattr=sa and acltype=posixacl
zfs create -o xattr=sa -o acltype=posixacl -o mountpoint=legacy tank/root

mount.zfs tank/root /mnt
mkdir -p /mnt/boot
mount $DISK"1" /mnt/boot
mkdir -p /mnt/nix
mount.zfs tank/nix /mnt/nix

# Create hardware config

BOOT_UUID=`blkid --output value /dev/vda1 | head -n 1 | tr -d  '[:space:]'`
HOST_NETWORK_ID=`tr -dc 0-9a-f < /dev/urandom | head -c 8`

mkdir -p /mnt/etc/nixos/

cat > /mnt/etc/nixos/configuration.nix <<EOF
{ config, pkgs, modulesPath, ... }:

{
    imports = [
        ./hardware-configuration.nix
        ./bootloader.nix
    ];
    boot = {
        loader.timeout = 0;
        initrd.availableKernelModules = [ "uas" ];
    };
    boot.kernelParams = [ "console=tty0" "random.trust_cpu=on" ];

    services.openssh = {
        enable = true;
        passwordAuthentication = true;
        permitRootLogin = "yes";
    };
    users.users.root.password = "root";
    users.users.root.openssh.authorizedKeys.keys = [
        # CI Deploy Keys
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuNngR3JgkjC7I7g8/v4YQNH8Pu13bZcCl9q7Ho8hYJ"
        # Home NAS
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHDfjdhKhsp76c/c3q9o8HHwFoZ5SjKi6jVEQp6B4Ty root@nixos"
        # Glowstone Laptop
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQChAHl9xXQPu0uF1kEoLLT/mpIdasbaTItnh3kQSk8X2G1Sf9MBnaDQhZ/VcCbehJNZ/tfai+ieUgm/fUtaefLiJwQXm0sx85YB2VroYBr2iSpxc8ia68PQ6+Ii784fAjLWADX4THOHexCYcIzDgVq1pTh/IR/8KVFfKiuhPqEYYUFbZ/oH2VuNKGtIso/leBgoUM/7Tgg+nKzMuv96PMlxzpTsQT9ogX3kTx8xAvKvJ/kyzemmZQoxw5dtcK7ojAOB8kPG0fybCz4EGJmFjyMzB4BtADeShCnUXcHoUcj3NXyp6DhAYfHg/L4s6yfKnZg4TPOdOuDnv5WNHGWzNQlEoCOu2cP9tjQmCtvFasLjQIBwuM1vjtYQY3FsMiMMHskIwGosSwF102ovylpASzIfsTldzWXoqOwUcMDC341SznY4WbejIX4WYKw/qt+CPXNZmQfpCVRuqHFihc2qPMiLqt/q4CrzplUupthWdXkzrP595Qzw/MYrQkCITTZ1Gts= indexyz@Glowstone"
    ];
    networking.useDHCP = false;
    networking.interfaces.eth0.useDHCP = true;
    networking.usePredictableInterfaceNames = false;

    nix = {
        gc = {
            automatic = true;
            options = "--delete-older-than 7d";
        };
        # Enable nix flake support
        package = pkgs.nixUnstable;
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
    };
}
EOF

if [ "$UEFI_BUILD" == "yes" ];then
cat > /mnt/etc/nixos/bootloader.nix <<EOF
{ ... }:
{

    boot.loader.grub = {
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
    };

    fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/$BOOT_UUID";
        fsType = "vfat";
    };
}
EOF
else
cat > /mnt/etc/nixos/bootloader.nix <<EOF
{ ... }:
{
    boot.loader.grub = {
        "enable" = true;
        "version" = 2;
        "device" = "/dev/vda";
    };

    fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/$BOOT_UUID";
        fsType = "ext4";
    };
}
EOF
fi

cat > /mnt/etc/nixos/hardware-configuration.nix <<EOF
{ config, lib, pkgs, modulesPath, ... }:

{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
    ];

    boot.supportedFilesystems = ["zfs"];
    networking.hostId = "$HOST_NETWORK_ID";
    boot.initrd.supportedFilesystems = [ "zfs" ];

    services.zfs.trim.enable = true;
    services.zfs.autoScrub.enable = true;
    services.zfs.autoScrub.pools = [ "tank" ];

    services.qemuGuest.enable = true;
    boot.initrd.availableKernelModules = [
        "ata_piix" "virtio_pci" "floppy" "sr_mod" "virtio_blk"
    ];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    fileSystems = {
        "/" = {
            device = "tank/root";
            fsType = "zfs";
        };
        "/nix" = {
            device = "tank/nix";
            fsType = "zfs";
        };
    };
}
EOF

passwd root <<EOF
packer
packer
EOF

