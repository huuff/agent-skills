---
name: new-project
description: Scaffold a new project with a standalone devenv shell, pre-commit hooks (secret scanning, static analysis, Conventional Commits), agent instructions, and a Nix flake only when something consumes the project through nix. Use when the user asks to create, bootstrap, or scaffold a new project.
disable-model-invocation: true
---

# New project scaffold

Creates a project that is:

1. **A devenv shell** — standalone (`devenv.yaml` + `devenv.nix` + `devenv.lock`),
   deliberately **not** via a flake's `devShells`. Rationale: the flake
   integration needs `--impure`, ties devenv to the flake's nixpkgs, and
   restricts devenv features (containers, `devenv up` processes, its own
   per-input lockfile). Keeping them apart also keeps any flake minimal
   for consumers — dev tooling never leaks into the export.
2. **Guarded by git hooks** — secrets scanning, static analysis, and
   Conventional Commits enforcement, all managed declaratively through
   devenv's `git-hooks` module (installed automatically on shell entry).
3. **Agent-ready** — an `AGENTS.md` (symlinked as `CLAUDE.md`) with concise
   project instructions.
4. **Secrets via sops** — if the application needs secrets at runtime, they
   are provided with [sops](https://github.com/getsops/sops) (age-encrypted,
   committed to the repo), never as plaintext files or env vars in the shell
   config. See "Runtime secrets" below.
5. **A flake, only for nix consumers** — `flake.nix` exists only when step 1
   finds something that installs or imports the project *through nix*. Most
   projects have no such consumer and get no flake at all.

## Workflow

### 1. Gather parameters

Needed before writing anything:

- **Directory / project name** (kebab-case; used as `pname`).
- **One-line description**.
- **Language(s)** — infer from the user's request; if genuinely unknown, ask.
- **Nix consumer** — the one observable question that decides whether a
  `flake.nix` exists: *name the thing that will fetch this project through
  nix.* Pick the first row that matches:

  | Who consumes the project | Flake? | What it exports |
  |---|---|---|
  | The language's own package manager (crates.io, npm, PyPI, Go modules, Maven, Hex, …) — i.e. a **library**, SDK or framework | **No** | — |
  | Only humans running it from a checkout (scripts, prototypes, experiments, course work) | **No** | — |
  | Another tool reads the files (Terraform/OpenTofu, Ansible, k8s manifests, docs, dotfiles) | **No** | — |
  | A NixOS / Home Manager config or another flake installs the **binary or app** | Yes | `packages.default` + `overlays.default` |
  | Other nix code imports it (NixOS/HM modules, `lib`) | Yes | `nixosModules` / `homeManagerModules` / `lib`, no package |

  "It's buildable" is not a consumer. A Rust/Go/Python/JS **library** is
  consumed by its ecosystem's package manager; a nix derivation of it is
  dead weight that no one will ever `nix build`. Same for a CLI that will
  only ever be installed via `cargo install` / `pipx` / `npm -g`.

  Write the answer down ("nix consumer: none" or "nix consumer: the user's
  NixOS config") — the rest of the workflow branches on it. If the user's
  request leaves it genuinely open, ask them; default to **No** when they
  don't care.

### 2. Copy templates

All templates live in `templates/` next to this file. Copy and rename:

| Template | Destination | When |
|---|---|---|
| `templates/devenv.yaml` | `devenv.yaml` | always |
| `templates/devenv.nix` | `devenv.nix` | always |
| `templates/envrc` | `.envrc` | always |
| `templates/gitignore` | `.gitignore` | always |
| `templates/flake.nix` | `flake.nix` | nix consumer = Yes |
| `templates/nix/package.nix` | `nix/package.nix` | nix consumer = Yes, package row |

Then replace every `CHANGEME_PNAME` / `CHANGEME_DESCRIPTION` placeholder and
resolve the remaining `# CHANGEME` comments (language blocks, license).

**No flake:** in `devenv.nix`, replace the `enterTest` body (`nix flake check
--no-build`) with the language's own check (`cargo check`, `go vet ./...`,
`npm test`, `uv run pytest`, …), and keep the `.gitignore` as is.

### 3. Adapt to the language

In `devenv.nix`, enable `languages.<lang>` and the matching hooks:

| Language | devenv | extra git-hooks |
|---|---|---|
| Rust | `languages.rust.enable = true;` | `clippy`, `rustfmt` |
| Python | `languages.python.enable = true;` (+ `uv.enable`) | `ruff`, `ruff-format` |
| JS/TS | `languages.javascript = { enable = true; npm.enable = true; };` | `eslint`, `prettier` |
| Go | `languages.go.enable = true;` | `golangci-lint`, `gofmt` |
| Nix-only | `languages.nix.enable = true;` (already on) | already covered |

**Flake with a package** (nix consumer installs a binary/app): replace the
stub in `nix/package.nix` with the right builder:

- Rust: `rustPlatform.buildRustPackage { cargoLock.lockFile = ../Cargo.lock; ... }`
- Go: `buildGoModule { vendorHash = ...; ... }`
- Python: `python3Packages.buildPythonApplication { pyproject = true; ... }`
- Node: `buildNpmPackage { npmDepsHash = ...; ... }`

The stub is intentionally buildable, so the scaffold passes `nix flake check`
before any real code exists.

**Flake with modules/lib** (other nix code imports it): drop
`nix/package.nix`, remove `packages` / `overlays` from `flake.nix`, export
`nixosModules` / `homeManagerModules` / `lib` instead, and point `checks` at
an eval test or leave only formatting checks.

### 4. Runtime secrets with sops (skip if the app needs none)

Secrets the application needs at runtime are managed with sops + age:
encrypted files are committed, the private key never enters the repo.

1. Uncomment `pkgs.sops` / `pkgs.age` in `devenv.nix` `packages`, and the
   `scripts.with-secrets` block.
2. Ensure the user has an age key (`~/.config/sops/age/keys.txt`); if not:
   `mkdir -p ~/.config/sops/age && age-keygen -o ~/.config/sops/age/keys.txt`.
   Never write this key into the project.
3. Create `.sops.yaml` at the repo root with the public recipient
   (from `age-keygen -y ~/.config/sops/age/keys.txt`):

   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age: age1...publickey...
   ```

4. Create the encrypted file: `sops secrets/dev.yaml` (opens $EDITOR; write
   `KEY: value` pairs). The resulting file is encrypted — committing it is
   safe and expected. Do **not** gitignore `secrets/`.
5. Run the app as `with-secrets '<command>'` — it uses `sops exec-env`, so
   decrypted values exist only in that process's environment, never on disk.

For production/NixOS deployment of the same secrets, point the user at
[sops-nix](https://github.com/Mic92/sops-nix) (`sops.secrets.*` module
options); the encrypted files and `.sops.yaml` carry over unchanged.

### 5. Agent instructions (AGENTS.md)

Agent instructions are harness-agnostic: the real file is `AGENTS.md`,
and harness-specific names are symlinks into it:

```bash
ln -s AGENTS.md CLAUDE.md
```

The same rule applies to agent directories: the canonical directory is
`.agents/` (e.g. repo-local skills in `.agents/skills/`), and
harness-specific directories are symlinks to it:

```bash
ln -s .agents .claude
```

Write a short `AGENTS.md` (a few lines, not a manual): what the project
is, how to build/test it, and any conventions an agent must follow.
Don't duplicate what the code or scaffold already makes obvious. Commit
both the file and the symlink.

Include this one line about devenv scripts:

> devenv `scripts.*` with real logic: use nushell (`package = pkgs.nushell`);
> CLI args need `def --wrapped main [...args]`, interpolation is `$"(...)"`.

### 6. Initialize and verify

```bash
git init -b main
devenv shell -- true        # builds the shell, writes devenv.lock, installs git hooks
devenv test                 # runs enterTest
nix flake check --no-build  # only if the project has a flake
git add -A
git commit -m "chore: scaffold project"   # must pass all hooks, incl. commitizen
```

Commit `devenv.lock` (and `flake.lock` if present); `.pre-commit-config.yaml`
and `.devenv/` are generated and gitignored.

If any hook fails on the initial commit, fix the offending file — do not
bypass with `--no-verify`.

### 7. Hand over

Tell the user: enter with `devenv shell` (or `direnv allow` for automatic
activation). If the project has a flake, also give the
`github:<owner>/<repo>` flake ref its nix consumer will use.
