{
  description = "Hub for harness-agnostic AI agent skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- third-party skills / Claude Code plugins (wired in nix/extras.nix) ---
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };
    playwright-cli = {
      url = "github:microsoft/playwright-cli";
      flake = false;
    };
    sentry-cli = {
      url = "github:getsentry/cli";
      flake = false;
    };
    i-have-adhd = {
      url = "github:ayghri/i-have-adhd";
      flake = false;
    };
    claude-plugins = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
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
        extras = import ./nix/extras.nix {
          sources = {
            inherit (inputs)
              superpowers
              ponytail
              playwright-cli
              sentry-cli
              i-have-adhd
              claude-plugins
              ;
          };
        };
        default.imports = [
          self.homeManagerModules.skills
          self.homeManagerModules.extras
        ];
      };

      homeModules = self.homeManagerModules;

      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;

        # Eval-only smoke test for the home manager modules: exercises every
        # harness option and every extra. `nix flake check --no-build`
        # catches regressions.
        hm-skills =
          (home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              self.homeManagerModules.default
              {
                home = {
                  username = "vibes";
                  homeDirectory = "/home/vibes";
                  stateVersion = "25.11";
                };
                # real package is unfree; any package satisfies the eval-only check
                programs.claude-code = {
                  enable = true;
                  package = pkgs.hello;
                };
                programs.agent-skills = {
                  package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
                  claude-code.enable = true;
                  codex = {
                    enable = true;
                    directory = ".config/codex-test/skills";
                  };
                  opencode.enable = true;
                  extras = {
                    playwright-cli.enable = true;
                    sentry-cli.enable = true;
                    i-have-adhd.enable = true;
                    claude-plugins.skills = [ "frontend-design" ];
                    superpowers.enable = true;
                    ponytail.enable = true;
                  };
                };
              }
            ];
          }).activationPackage;
      });
    };
}
