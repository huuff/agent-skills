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

  enabledDirectories = map (harness: harness.directory) (
    lib.filter (harness: harness.enable) [
      cfg.claude-code
      cfg.codex
      cfg.opencode
    ]
  );
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
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Extra skills (name → source directory) installed into the same harness directories.";
    };
  };

  config.home.file = lib.listToAttrs (
    lib.concatMap (
      directory:
      map (name: {
        name = "${directory}/${name}";
        value.source = "${cfg.package}/share/skills/${name}";
      }) skillNames
      ++ lib.mapAttrsToList (name: source: {
        name = "${directory}/${name}";
        value.source = source;
      }) cfg.extraSkills
    ) enabledDirectories
  );
}
