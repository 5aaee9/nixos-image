iso:
    nix build '.#vmImage.config.system.build.isoImage'
    cp result/iso/nixos-*-x86_64-linux.iso nixos.iso
    rm -f result
    chmod 777 nixos.iso

ovmf:
    nix build nixpkgs#OVMF.fd
    cp result-fd/FV/OVMF.fd OVMF.fd
    chmod 777 OVMF.fd
    rm -f result-fd

deps: iso ovmf
