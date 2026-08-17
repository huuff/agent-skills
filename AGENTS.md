# agent-skills

Hub for harness-agnostic AI agent skills. Each `skills/<name>/` directory is
one skill (a `SKILL.md` plus optional support files). The flake bundles them
into a package and ships a home manager module (`programs.agent-skills`) that
symlinks every skill into the configured harnesses' skill directories
(Claude Code, Codex, OpenCode).

- Add a skill: create `skills/<name>/SKILL.md`. No flake edits needed — the
  package and module pick up directories automatically.
- Third-party skills and Claude Code plugins (superpowers, ponytail, ...) are
  non-flake inputs wired in `nix/extras.nix` and enabled via
  `programs.agent-skills.extras.*`. Update with `nix flake update <input>`.
- Skills must stay harness-agnostic: no Claude/Codex-specific instructions.
- Verify: `nix flake check --no-build` (also runs as `devenv test`).
- Dev shell: `devenv shell` (or `direnv allow`); git hooks install on entry.
  Commits follow Conventional Commits.
