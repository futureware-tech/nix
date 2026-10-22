# AGENTS.md

Shared NixOS / nix-darwin module library ("FutureWare" flake). This repo contains
**no deployable system config** — it exports reusable modules, one shell-script
package, and SSH access/signing identities that _other_ repos (host configs,
dotfiles) import as a flake input.

## Commands

| Task                                   | Command                                                 |
| -------------------------------------- | ------------------------------------------------------- |
| Verify a change (CI does exactly this) | `nix flake check`                                       |
| Enter dev shell (installs git hooks)   | `nix develop`                                           |
| Update pinned inputs                   | `nix flake update` (commit message: `nix flake update`) |
| Build the shipped package              | `nix build .#git-safe-sync`                             |
| Nix lint autofix                       | `statix fix` (inside `nix develop`)                     |
| Check every system (incl. aarch64)     | `nix flake check --all-systems`                         |

`nix flake check` silently omits the non-native systems (`aarch64-linux`,
`aarch64-darwin`, `x86_64-darwin`) unless `--all-systems` is passed — relevant
because several modules branch on `isDarwin`.

There is **no `nix fmt`**: the flake defines no `formatter` output. Formatting is
enforced by git hooks (see below). There are no unit tests. `nix flake check`
evaluates every `nixosModules` output standalone (via `lib.evalModules` with no
host config) plus the package, check, and devShell derivations, so it catches
eval-time breakage in a module but not misbehaviour once combined with a real
host config. Only the host's own systems are checked in their own repos.

CI runs `nix flake check` on `x86_64-linux` only, from two twin workflow files:
`.github/workflows/check.yaml` on GitHub's `ubuntu-latest`, and
`.gitea/workflows/check.yaml` on the self-hosted `nixos-futureware` runner. Each
platform reads only its own directory, so a change to what is checked has to be
made in both. Nothing here is verified against nix-darwin or aarch64 in CI.

### Tooling / formatting

Hooks are defined once in `pre-commit.nix` (nixfmt, statix, deadnix, nil,
flake-checker, prettier, black, clang-format, ripsecrets, plus file hygiene
checks) and consumed by `checks.*.pre-commit-check` and `devShells.default`.

- `.pre-commit-config.yaml` at the repo root is a **generated symlink** into the
  Nix store, produced by the `nix develop` shellHook and gitignored. Never edit
  it; edit `pre-commit.nix`.
- Hooks only get installed when you enter `nix develop` (direnv does this via
  `.envrc`, which also does `watch_file pre-commit.nix`). If you skip the dev
  shell, nothing formats or lints your commit.
- nixfmt is the RFC-style formatter; its output (vertical argument lists,
  trailing commas, `final:`/`_prev:` underscore-prefixed unused args) is the
  house style — match it rather than hand-formatting.
- statix rules come from `assets/statix.toml`, which disables `repeated_keys`
  on purpose (modules are not yet split finely enough). `nil` (the LSP-based
  checker) is what surfaces `builtins.`-prefix warnings.
- ripsecrets runs on every commit. Public SSH keys that trip it need an inline
  `# pragma: allowlist secret` (see `modules/futureware.nix`).

## Layout

```
flake.nix              outputs: nixosModules, packages, checks, devShells, lib.pre-commit
modules/*.nix          one file per exported module, name == flake output key
packages/*.nix         standalone packages (callPackage-compatible)
data/identities.nix    users + access/signing keys, exposed as module arg
pre-commit.nix         hook definitions (also a flake output: lib.pre-commit)
assets/statix.toml     statix config, referenced by path from pre-commit.nix
```

Every file in `modules/` is exported explicitly in `flake.nix` — adding a module
means adding an `import` line there. `data/identities.nix` is exported
differently: as `_module.args.identities`, so consumer modules can list
`identities` in their function arguments.

## Module conventions

**Cross-platform is a hard requirement.** These modules are imported by both
NixOS and nix-darwin hosts, so a module must not assume an option or a domain
exists. Two patterns are used throughout:

- Guard on option existence: `hasGitOption = options ? programs.git;` then
  `lib.optionalAttrs hasGitOption { ... }` / `lib.optionalAttrs (!hasGitOption) { ... }`
  (`futureware.nix`, `tools.nix`, `boot.nix` for `options ? boot.lanzaboote`).
  The `!has...` branch usually installs an equivalent by hand (`/etc/gitconfig`,
  `/etc/htoprc`).
- Guard on platform with `pkgs.stdenv.hostPlatform.isDarwin` / `.isLinux`
  (`nix-gc.nix`, `nix-settings.nix`, `tools.nix`). Use `stdenv.hostPlatform`, not
  the old `stdenv.isDarwin` (migration already applied repo-wide).

**Prefer `lib.mkDefault` for anything a host might want to change** (scheduler
times, `services.openssh.hostKeys`, `boot.zfs.devNodes`). Reserve `mkForce` for
cases where a module must win outright (`nvidia-fabricmanager`, `zpool-trim`).
`modules/sshd.nix` documents the priority reasoning for `hostKeys` — read it
before changing defaults there.

**Custom options live in the `fw.*` namespace**: `fw.tpm.hostPath`,
`fw.hardware.gpus.{enable,devices,pools,resolvedPools,allCudaCapabilities}`.
`flake.nix` carries a TODO to collapse this into a single default module gated
by `mkEnableOption`s under `fw.features` — don't preempt that refactor.

**Modules must compose independently, never assume ordering or co-import.**
When one module wants to react to another, read it defensively:
`config.fw.hardware.gpus.enable or false`, `config.services.telegraf.enable or false`,
`config.boot.lanzaboote.enable or false`. `telegraf.nix` and `nvidia.nix` are
the canonical pair: telegraf adds the `nvidia_smi` input only if the GPU option
is on, and nvidia adds its telegraf tweaks only if telegraf is enabled.

**Schedules are UTC.** Timer values (`nix.gc` `00:15`, `nix.optimise` `00:45`,
ZFS scrub/trim, SMART test windows) are written assuming UTC; keep that
assumption when adding timers.

**`identities.nix` is an API, not just data.** `getAccessKeys { user; }` returns
`"<key> <name>"` lines for `authorized_keys`; `getSigningEntries { user; }`
returns signed-key entries (omit `user` for everyone). Key names become the
trailing comment on the key, so they are user-visible.

**Packages**: `packages/git-safe-sync.nix` is a `writeShellApplication` script,
exported twice — as `packages.<system>.git-safe-sync` and via a `nixpkgs.overlays`
entry in `modules/git-safe-sync.nix` (module files that only inject an overlay
take `_:` as their argument). The script requires signed commits
(`git verify-commit` / `merge --ff-only --verify-signatures`).

## Non-obvious context

- `modules/futureware.nix` is intended for internal LAN servers only. It hardcodes
  private infrastructure: `nix-cache.home.arpa` substituters, `git.home.arpa`
  known hosts, and `git insteadOf` rewrites that mirror GitHub repos onto the
  private Gitea. It therefore also sets `connect-timeout`/`fallback` defaults so
  an unreachable cache doesn't hang builds.
- The repo's own remote is `git.home.arpa:futureware-tech/nix.git` (private Gitea
  mirror of the GitHub project); `futureware.nix` encodes that mirror relationship.
- `modules/tpm.nix` implements a deliberate two-stage secret scheme: agenix +
  TPM2 unlocks the SSH host key, sops-nix then decrypts everything else with it
  (decrypting many secrets via TPM is too slow). It also reorders
  `system.activationScripts.setupSecrets*` with `deps = lib.mkAfter [ "agenixInstall" ]`
  — sops needs the key agenix installs, and cannot depend on the `agenix` script
  itself because that runs after user setup. It expects a specific on-disk layout
  under `fw.tpm.hostPath` (`tpm.id`, `secrets/ssh_host_ed25519_key.age`) and a
  sibling `../common/secrets/root-password.bin`.
- `modules/nvidia.nix` imports a **second, separate nixpkgs instance**
  (`cudaPkgs`) with `cudaSupport = true` so CUDA rebuilds stay scoped to
  `gpu-burn` instead of recompiling everything. Its pool model: declare
  `devices` (uuid/model/cudaCapability/powerLimit/compute) and `pools` (names →
  device names); `resolvedPools` derives `CUDA_VISIBLE_DEVICES`/`NVIDIA_VISIBLE_DEVICES`
  from sorted UUIDs and exposes `applyCudaArches` to rebuild a package for a
  pool's architectures only when `needsRebuild`. Only `compute = true` GPUs
  contribute build architectures; `allCudaCapabilities` includes all of them so
  stress testing works. It pins `hardware.nvidia.open = false` (stability on
  Ampere) and needs `hardware.enableRedistributableFirmware` for GSP firmware.
- `modules/boot.nix` takes a module argument `rootDisks ? [ ]` (passed by the
  consumer when importing the module) and mirrors `/boot1` to `/boot2..N` via a
  hourly `efi-mirror` unit, with a sentinel-file check that exits 66 rather than
  mirroring garbage. It relies on `notify-failed@%n` from `modules/systemd.nix`.
- `modules/systemd.nix` provides templated `notify-failed@` / `notify-succeeded@`
  units (system and user) that mail `systemctl status` via `sendmail`. Any unit
  wanting failure mail sets `OnFailure = [ "notify-failed@%n.service" ]`.
- `modules/zfs.nix` opens with a long comment block that is the authoritative
  runbook for creating pools/datasets on this infrastructure (recordsize choice,
  ashift, xattr=sa, autoexpand, reservation, `chattr +i`). Consult it before
  changing ZFS defaults.
- `modules/zfs.nix` also takes a `rootDisks ? [ ]` module argument (same style as
  `boot.nix`) of full paths to whole disks. Only entries starting with
  `/dev/disk/by-path/` are used: the `ID_PATH` is parsed out of each and turned
  into udev rules — in stage 2 and in the initrd — symlinking every partition of
  the matching disk into `/dev/disk/rpool`, numbered `1..N` like `/boot1 /boot2`
  in `boot.nix`. Whole disks are deliberately not linked: UEFI requires a boot
  partition, so the root pool always lives on a partition. When such entries exist
  `boot.zfs.devNodes` points there, so `zpool import -d` can never see a foreign
  pool with the same name.
  `boot.zfs.devNodes` is a _directory_ (passed to `-d`), not a device list, and
  `forceImportRoot` does not resolve duplicate pool names — it only overrides
  in-use/dirty checks. A `rootDisks` entry in another naming scheme (`by-id`,
  `by-uuid`, `/dev/sda`) is silently ignored, and a wrong `by-path` entry makes
  the disk invisible to the import, so the host will not boot.
- `modules/telegraf.nix` intentionally leaves `outputs.prometheus_client`
  without a listen port (secure by default; hosts put it behind a reverse proxy).
  Don't add a port here.
- Temporarily, `nvidia.nix` emits GPU throttle counters through a telegraf `exec`
  CSV hack because upstream `nvidia_smi` lacks those fields; it is marked for
  removal once upstream ships them.
