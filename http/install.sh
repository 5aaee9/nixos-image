set -x

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
mkfs.ext4 $DISK"2"

mount $DISK"2" /mnt
mkdir /mnt/boot
mount $DISK"1" /mnt/boot

# Create hardware config

ROOT_UUID=`blkid --output value /dev/vda2 | head -n 1 | tr -d  '[:space:]'`
BOOT_UUID=`blkid --output value /dev/vda1 | head -n 1 | tr -d  '[:space:]'`

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
        # Hasee Laptop
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQVrXL5KxSULCy659YGA6ep9mMw16aZHCd+08DFbp6B indexyz@Indexyz-Hasee"
        # NixOps
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/mg1k8mFOGphV/8xYgK866wAp84r7/fnoAJaqqAQMu cardno:FFFE004E4D35"
    ];
    networking.useDHCP = false;
    networking.interfaces.eth0.useDHCP = true;
    networking.usePredictableInterfaceNames = false;
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

    services.qemuGuest.enable = true;
    boot.growPartition = true;
    boot.initrd.availableKernelModules = [
        "ata_plix" "virtio_pci" "floppy" "sr_mod" "virtio_blk"
    ];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    fileSystems = {
        "/" = {
            device = "/dev/disk/by-uuid/$ROOT_UUID";
            fsType = "ext4";
            autoResize = true;
        };
    };
}
EOF

passwd root <<EOF
packer
packer
EOF

