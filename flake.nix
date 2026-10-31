{
  description = "nimTodo — a small, fast CLI todo organizer written in Nim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in
    {
      packages.${system} = {
        nimTodo = pkgs.callPackage ./package.nix { };

        default = self.packages.${system}.nimTodo;
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [ nim nimble gcc ];
          shellAliases = {
            tt = "nimTodo";
          };
        };
      };
    };
}
