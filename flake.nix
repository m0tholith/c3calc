{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    c3c = {
      flake = true;
      url = "github:c3lang/c3c";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      c3c,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      c3c-package = (c3c.outputs.packages.${system}.default);
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          c3c-package
        ];
      };
      packages.${system}.default = pkgs.callPackage ./default.nix { c3c = c3c-package; };
    };
}
