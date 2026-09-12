# juliaup-nix

Nix flake packaging [juliaup](https://github.com/JuliaLang/juliaup) — the official Julia version manager.

Juliaup is not in nixpkgs. This flake builds juliaup from source using `rustPlatform.buildRustPackage`, and provides pinned Julia binaries in the Nix store for fully reproducible deployments.

## What this provides

| Package | Binary | Description |
|---------|--------|-------------|
| `juliaup` (default) | `juliaup` | Julia version manager CLI, built from source |
| `julia` | `julia` | Latest stable (1.13.0) — pinned in the Nix store |
| `julia-lts` | `julia` | LTS (1.10.9) — pinned in the Nix store |
| `julia-1_13_0` | — | Raw Julia 1.13.0 binary (no wrapper) |
| `julia-1_10_9` | — | Raw Julia 1.10.9 binary (no wrapper) |

`julia` and `julia-lts` both expose `/bin/julia` — install only one at a time in `home.packages`.

> **Why a separate `julia` wrapper?** juliaup uses `current_exe()` (resolves symlinks via `/proc/self/exe` on Linux) to decide whether to launch Julia or show its own CLI. A plain `julia → juliaup` symlink always resolves to the store path, so juliaup sees itself as `juliaup` and shows its own help. The wrappers simply `exec` the pinned binary from the Nix store — no runtime dispatch, no `~/.julia/juliaup/` dependency.

> **Why not `environment.systemPackages`?** The `julia` package must go in `home.packages` (user-level), not `environment.systemPackages`, to avoid binary conflicts with `julia-bin` pulled transitively by tools such as quarto.

## Quick start

```bash
# Try juliaup without installing
nix run github:s-celles/juliaup-nix -- add release

# Run pinned Julia directly
nix run github:s-celles/juliaup-nix#julia      # latest stable (1.13.0)
nix run github:s-celles/juliaup-nix#julia-lts  # LTS (1.10.9)
```

## NixOS / Home Manager

Add the input to your `flake.nix`:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  juliaup-nix = {
    url = "github:s-celles/juliaup-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Install `juliaup` as a system package and the `julia` wrapper as a user package:

```nix
# NixOS module — system-level (juliaup CLI only)
environment.systemPackages = [
  inputs.juliaup-nix.packages.${pkgs.stdenv.hostPlatform.system}.juliaup
];

# Home Manager — user-level: choose one julia wrapper
home.packages = [
  inputs.juliaup-nix.packages.${pkgs.stdenv.hostPlatform.system}.julia      # latest stable
  # inputs.juliaup-nix.packages.${pkgs.stdenv.hostPlatform.system}.julia-lts  # or LTS
];
```

After rebuild:

```bash
julia --version  # no download required — served from the Nix store
juliaup add 1.9 && juliaup default 1.9  # juliaup still manages other versions
```

## Reproducibility

- **No runtime download**: `julia` works immediately after `nixos-rebuild switch`.
- **Pinned binary**: Julia version is fixed by the flake hash — bump the flake revision to upgrade.
- **juliaup still useful**: for accessing other Julia versions on demand (`juliaup add 1.9`, etc.).

## Updating Julia version

Update the relevant `mkJuliaBin` call in `flake.nix` with the new version's URLs and hashes, then bump the flake in your configuration:

```bash
nix flake update juliaup-nix
```

## About `flake.lock`

The `flake.lock` pins `nixpkgs` and `flake-utils` versions for reproducible builds. Commit it alongside `flake.nix`.
