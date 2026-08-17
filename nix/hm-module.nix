{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.agent-skills;
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../skills)
  );

  mkHarnessOption =
    name: defaultDirectory:
    lib.mkOption {
      default = { };
      description = "Skill installation for ${name}.";
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "installing skills for ${name}";

          directory = lib.mkOption {
            type = lib.types.str;
            default = defaultDirectory;
            description = "Skill directory relative to the home directory.";
          };
        };
      };
    };

  enabledHarnesses = lib.filterAttrs (_: harness: harness.enable) {
    inherit (cfg) claude-code codex opencode;
  };
in
{
  options.programs.agent-skills = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "agent-skills' skills package";
      description = "Package containing the skills to install.";
    };

    claude-code = mkHarnessOption "Claude Code" ".claude/skills";
    codex = mkHarnessOption "Codex" ".agents/skills";
    opencode = mkHarnessOption "OpenCode" ".config/opencode/skills";

    extraSkills = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.path;
              description = "Directory containing the skill.";
            };

            harnesses = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "claude-code"
                  "codex"
                  "opencode"
                ]
              );
              default = [
                "claude-code"
                "codex"
                "opencode"
              ];
              description = "Harnesses the skill installs into (intersected with the enabled ones).";
            };
          };
        }
      );
      default = { };
      description = "Extra skills installed into the same harness directories.";
    };
  };

  config.home.file = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        harnessName: harness:
        map (name: {
          name = "${harness.directory}/${name}";
          value.source = "${cfg.package}/share/skills/${name}";
        }) skillNames
        ++ lib.mapAttrsToList (name: extra: {
          name = "${harness.directory}/${name}";
          value.source = extra.source;
        }) (lib.filterAttrs (_: extra: lib.elem harnessName extra.harnesses) cfg.extraSkills)
      ) enabledHarnesses
    )
  );
}
