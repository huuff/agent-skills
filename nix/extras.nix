# Third-party skills and Claude Code plugins, vendored from flake inputs.
# `sources` is bound by flake.nix; consumers just flip the enables.
{ sources }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.agent-skills.skills;

  plugins =
    lib.optionalAttrs cfg.superpowers.enable { inherit (sources) superpowers; }
    // lib.optionalAttrs cfg.ponytail.enable {
      # hooks invoke bare `node`, which we keep off global PATH
      ponytail = pkgs.runCommand "ponytail-plugin" { } ''
        cp -r ${sources.ponytail} $out
        chmod -R u+w $out
        substituteInPlace $out/hooks/claude-codex-hooks.json \
          --replace-fail 'node \"''${CLAUDE_PLUGIN_ROOT}' '${pkgs.nodejs}/bin/node \"''${CLAUDE_PLUGIN_ROOT}'
      '';
    };
in
{
  options.programs.agent-skills.skills = {
    playwright-cli.enable = lib.mkEnableOption "the playwright-cli skill";
    sentry-cli.enable = lib.mkEnableOption "the sentry-cli skill";
    i-have-adhd.enable = lib.mkEnableOption "the i-have-adhd skill";

    claude-plugins.skills = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "frontend-design" ];
      description = "Skills vendored from anthropics/claude-plugins-official (plugins/<name>/skills/<name>).";
    };

    # full Claude Code plugins (hooks, commands), not plain skills
    superpowers.enable = lib.mkEnableOption "the superpowers Claude Code plugin";
    ponytail.enable = lib.mkEnableOption "the ponytail Claude Code plugin";
  };

  config = {
    programs.agent-skills.extraSkills =
      lib.optionalAttrs cfg.playwright-cli.enable {
        playwright-cli = "${sources.playwright-cli}/skills/playwright-cli";
      }
      // lib.optionalAttrs cfg.sentry-cli.enable {
        sentry-cli = "${sources.sentry-cli}/packages/cli/plugins/sentry-cli/skills/sentry-cli";
      }
      // lib.optionalAttrs cfg.i-have-adhd.enable {
        i-have-adhd = "${sources.i-have-adhd}/skills/i-have-adhd";
      }
      // lib.listToAttrs (
        map (
          name: lib.nameValuePair name "${sources.claude-plugins}/plugins/${name}/skills/${name}"
        ) cfg.claude-plugins.skills
      );

    programs.claude-code.plugins = lib.mkIf (plugins != { }) plugins;
  };
}
