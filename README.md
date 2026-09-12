# juliaup-nix

Nix flake packaging [juliaup](https://github.com/JuliaLang/juliaup) — the official Julia version manager.

Juliaup is not in nixpkgs. This flake builds juliaup from source using `rustPlatform.buildRustPackage`, and also provides a pinned Julia binary directly in the Nix store for fully reproducible deployments.

## What this provides

| Package | Binary | Description |
|---------|--------|-------------|
| `juliaup` (default) | `juliaup` | Julia version manager CLI, built from source |
| `julia-1_13_0` | `julia` | Julia 1.13.0 binary, pinned in the Nix store |
| `julia` | `julia` | Thin wrapper that execs `julia-1_13_0` |

> **Why a separate `julia` wrapper?** juliaup uses `current_exe()` (resolves symlinks via `/proc/self/exe` on Linux) to decide whether to launch Julia or show its own CLI. A plain `julia → juliaup` symlink always resolves to the store path, so juliaup sees itself as `juliaup` and shows its own help. The `julia` wrapper simply `exec`s the pinned binary from the Nix store — no runtime dispatch, no `~/.julia/juliaup/` dependency.

> **Why not `environment.systemPackages`?** The `julia` package must go in `home.packages` (user-level), not `environment.systemPackages`, to avoid binary conflicts with `julia-bin` pulled transitively by tools such as quarto.

## Quick start

```bash
# Try juliaup without installing
nix run github:s-celles/juliaup-nix -- add release
nix run github:s-celles/juliaup-nix -- default release

# Run the pinned Julia directly
nix run github:s-celles/juliaup-nix#julia
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

# Home Manager — user-level (julia wrapper, avoids conflict with julia-bin)
home.packages = [
  inputs.juliaup-nix.packages.${pkgs.stdenv.hostPlatform.system}.julia
];
```

After rebuild:

```bash
julia --version  # Julia 1.13.0 — from the Nix store, no download required
juliaup add 1.10 && juliaup default 1.10  # juliaup still manages other versions
```

## Reproducibility

The `julia` wrapper points directly to `julia-1_13_0` in the Nix store:
- **No runtime download**: `julia` works immediately after `nixos-rebuild switch`, without running `juliaup add`.
- **Pinned binary**: the Julia version is fixed by the flake hash — switching flake revisions is the upgrade mechanism.
- **juliaup still useful**: for accessing other Julia versions on demand (`juliaup add 1.10`, etc.).

## Updating Julia version

Update the `julia-1_13_0` derivation in `flake.nix` with the new version's download URLs and hashes, then bump the flake in your configuration:

```bash
nix flake update juliaup-nix
```

## About `flake.lock`

The `flake.lock` pins `nixpkgs` and `flake-utils` versions for reproducible builds. Commit it alongside `flake.nix`.
