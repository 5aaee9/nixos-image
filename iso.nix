{ config, pkgs, lib, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

  networking.wireless.enable = false;
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

  environment.systemPackages = with pkgs; [
    btrfs-progs
  ];

  services.openssh = {
    enable = true;
    passwordAuthentication = true;
  };

  users.users.root.initialPassword = lib.mkDefault "toor";

  networking.usePredictableInterfaceNames = false;
}
