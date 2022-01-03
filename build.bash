# Build custom iso image
nix build '.#vmImage.config.system.build.isoImage'
cp result/iso/nixos-*-x86_64-linux.iso nixos.iso
rm -f result

# Build OVMF image
nix build nixpkgs#OVMF.fd
cp result-fd/FV/OVMF.fd OVMF.fd
rm -f result-fd

# Build UEFI Result
packer build --var-file ./uefi.pkr.hcl ./build.pkr.hcl
mv output-nixos/packer-nixos nixos-20.11pre-git-uefi-tty0.raw
gzip nixos-20.11pre-git-uefi-tty0.raw
rm -rf output-nixos

# Build BIOS Result
packer build ./build.pkr.hcl
mv output-nixos/packer-nixos nixos-20.11pre-git-bios-tty0.raw
gzip nixos-20.11pre-git-bios-tty0.raw
rm -rf output-nixos
