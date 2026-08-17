---
name: devenv-scripts
description: Use when writing or editing a devenv script (`scripts.*` in devenv.nix) — picking bash vs nushell, and nushell-inside-nix gotchas.
---

# devenv scripts

devenv `scripts.*` run with bash by default. Keep bash for trivial one-line
exec wrappers. When a script has real logic — filtering lists, parsing
JSON/structured output, or more than a couple of conditionals — write it in
nushell instead; it will usually be clearer.

```nix
scripts.my-script = {
  package = pkgs.nushell; # binary defaults to meta.mainProgram = "nu"
  exec = ''
    http get https://api.example.com/items | where size > 10mb | to md
  '';
};
```

Nushell-specific gotchas:

- A script that receives CLI arguments needs `def --wrapped main [...args]`;
  `--wrapped` stops nu from parsing flags meant for the wrapped command.
  Without it, flags get eaten silently instead of erroring.
- Nu interpolation is `$"(...)"`, which doesn't collide with nix `''...''`
  strings — no `''${}` escaping needed, unlike bash.
