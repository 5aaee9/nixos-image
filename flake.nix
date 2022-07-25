{
  description = "A very basic flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
  in
  {
    vmImage = import "${toString nixpkgs}/nixos/lib/eval-config.nix" {
      system = "x86_64-linux";

      modules = [
        "${toString nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ./iso.nix
      ];
    };

    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = with pkgs; [
        just
        packer
      ];
    };
  };
}
