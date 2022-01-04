{ config, pkgs, lib, ... }:

{
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

  boot.supportedFilesystems = ["zfs"];
  networking.hostId = "9a18f601";
  boot.initrd.supportedFilesystems = [ "zfs" ];

  services.openssh = {
    enable = true;
    passwordAuthentication = true;
  };

  users.users.root.initialPassword = lib.mkDefault "toor";

  networking.usePredictableInterfaceNames = false;
}
