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
mkfs.fat $DISK"1" -n ESP
else
mkfs.ext4 $DISK"1" -L ESP
fi

mkfs.ext4 $DISK"2" -L nixos

mount $DISK"2" /mnt
mkdir -p /mnt/boot
mount $DISK"1" /mnt/boot

# Create hardware config
mkdir -p /mnt/etc/nixos/

cat > /mnt/etc/nixos/configuration.nix <<EOF
{ config, pkgs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./bootloader.nix
  ];

  services.openssh = {
    enable = true;
    passwordAuthentication = true;
    permitRootLogin = "yes";
  };

  users.users.root = {
    password = "root";
    openssh.authorizedKeys.keys = [
      # Main keys
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuNngR3JgkjC7I7g8/v4YQNH8Pu13bZcCl9q7Ho8hYJ"
    ];
  };

  nix = {
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
    version = 2;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    splashImage = null;
    extraConfig = ''
      serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
      terminal_input --append serial
      terminal_output --append serial
    '';
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
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
    device = "/dev/disk/by-label/ESP";
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

  networking = {
    useDHCP = false;
    useNetworkd = true;
    usePredictableInterfaceNames = false;
  };

  services.qemuGuest.enable = true;
  systemd.network.networks.eth0 = {
    name = "eth0";
    DHCP = "yes";
  };

  boot = {
    loader.timeout = 0;
    initrd = {
      availableKernelModules = [
        "uas"
        # Disk Drive
        "ata_piix"
        "floppy"

        # CD-ROM
        "sr_mod"

        # LSI 53C895A
        "sym53c8xx"
      ];
      kernelModules = [];
    };
    growPartition = true;
    kernelModules = [];
    extraModulePackages = [];
    kernelParams = [ "console=tty0" "console=ttyS0" "console=tty1" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
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

