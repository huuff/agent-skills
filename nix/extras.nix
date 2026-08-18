# Third-party skills and Claude Code/Codex plugins, vendored from flake
# inputs. `sources` is bound by flake.nix; consumers just flip the enables.
{ sources }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.agent-skills.skills;

  allHarnesses = [
    "claude-code"
    "codex"
    "opencode"
  ];

  mkSkillOption = name: {
    enable = lib.mkEnableOption "the ${name} skill";

    harnesses = lib.mkOption {
      type = lib.types.listOf (lib.types.enum allHarnesses);
      default = allHarnesses;
      description = "Harnesses the skill installs into (intersected with the enabled ones).";
    };
  };

  # Full plugins (hooks, commands), not plain skills. Each harness registers
  # the source through its native plugin mechanism.
  mkPluginOption = name: {
    enable = lib.mkEnableOption "the ${name} plugin";

    harnesses = lib.mkOption {
      type = lib.types.listOf (lib.types.enum allHarnesses);
      default = allHarnesses;
      description = "Harnesses the plugin is registered with.";
    };
  };

  mkExtraSkill =
    name: source:
    lib.optionalAttrs cfg.${name}.enable {
      ${name} = {
        inherit source;
        inherit (cfg.${name}) harnesses;
      };
    };

  pluginFor =
    harness:
    lib.optionalAttrs (cfg.superpowers.enable && lib.elem harness cfg.superpowers.harnesses) {
      inherit (sources) superpowers;
    }
    // lib.optionalAttrs (cfg.ponytail.enable && lib.elem harness cfg.ponytail.harnesses) {
      # hooks invoke bare `node`, which we keep off global PATH
      # the drv name is user-visible: codex derives the plugin id from it
      ponytail = pkgs.runCommand "ponytail" { } ''
        cp -r ${sources.ponytail} $out
        chmod -R u+w $out
        substituteInPlace $out/hooks/claude-codex-hooks.json \
          --replace-fail 'node \"''${CLAUDE_PLUGIN_ROOT}' '${pkgs.nodejs}/bin/node \"''${CLAUDE_PLUGIN_ROOT}'
      '';
    };

  claudePlugins = pluginFor "claude-code";
  codexPlugins = pluginFor "codex";
  opencodePlugins = lib.attrValues (pluginFor "opencode");
in
{
  options.programs.agent-skills.skills = {
    playwright-cli = mkSkillOption "playwright-cli";
    sentry-cli = mkSkillOption "sentry-cli";
    i-have-adhd = mkSkillOption "i-have-adhd";

    claude-plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "frontend-design" ];
      description = "Skills vendored from anthropics/claude-plugins-official (plugins/<name>/skills/<name>).";
    };

    superpowers = mkPluginOption "superpowers";
    ponytail = mkPluginOption "ponytail";
  };

  config.programs = {
    agent-skills.extraSkills =
      mkExtraSkill "playwright-cli" "${sources.playwright-cli}/skills/playwright-cli"
      // mkExtraSkill "sentry-cli" "${sources.sentry-cli}/packages/cli/plugins/sentry-cli/skills/sentry-cli"
      // mkExtraSkill "i-have-adhd" "${sources.i-have-adhd}/skills/i-have-adhd"
      // lib.listToAttrs (
        map (
          name:
          lib.nameValuePair name {
            source = "${sources.claude-plugins}/plugins/${name}/skills/${name}";
          }
        ) cfg.claude-plugins
      );

    claude-code.plugins = lib.mkIf (claudePlugins != { }) claudePlugins;
    codex.plugins = lib.mkIf (codexPlugins != { }) (lib.attrValues codexPlugins);
    opencode.settings.plugin = lib.mkIf (opencodePlugins != [ ]) opencodePlugins;
  };
}
