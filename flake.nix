{
  description = "Hub for harness-agnostic AI agent skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.callPackage ./nix/package.nix { };
      });

      overlays.default = final: _prev: {
        agent-skills = final.callPackage ./nix/package.nix { };
      };

      homeManagerModules = {
        skills = ./nix/hm-module.nix;
        default = self.homeManagerModules.skills;
      };

      homeModules = self.homeManagerModules;

      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;

        # Eval-only smoke test for the home manager module: exercises every
        # harness option. `nix flake check --no-build` catches regressions.
        hm-skills =
          (home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              self.homeManagerModules.skills
              {
                home = {
                  username = "vibes";
                  homeDirectory = "/home/vibes";
                  stateVersion = "25.11";
                };
                programs.agent-skills = {
                  package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
                  claude-code.enable = true;
                  codex = {
                    enable = true;
                    directory = ".config/codex-test/skills";
                  };
                  opencode.enable = true;
                };
              }
            ];
          }).activationPackage;
      });
    };
}
