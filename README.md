# juliaup-nix

Nix flake packaging [juliaup](https://github.com/JuliaLang/juliaup) — the official Julia version manager.

Juliaup is not in nixpkgs. This flake builds juliaup from source using `rustPlatform.buildRustPackage`, making it available on any platform supported by Rust + nixpkgs.

## What this provides

| Package | Binary | Description |
|---------|--------|-------------|
| `juliaup` (default) | `juliaup` | Julia version manager CLI |
| `julia` | `julia` | Wrapper that dispatches to the default Julia version |

> **Why a separate `julia` wrapper?** juliaup dispatches to Julia based on `current_exe()`, which on Linux resolves symlinks via `/proc/self/exe`. A plain symlink `julia → juliaup` always resolves to the juliaup store path, so juliaup sees itself as `juliaup` (not `julia`) and shows its own help instead of launching Julia. This wrapper reads `~/.julia/juliaup/juliaup.json` with `jq` and execs the correct Julia binary directly.

> **Why not `environment.systemPackages`?** The `julia` package must go in `home.packages` (user-level), not `environment.systemPackages`, to avoid binary conflicts with `julia-bin` pulled transitively by tools such as quarto.

## Quick start

```bash
# Try without installing
nix run github:s-celles/juliaup-nix -- add release
nix run github:s-celles/juliaup-nix -- default release
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
# NixOS module — system-level (juliaup only)
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
juliaup add release       # dynamic channel → always latest stable Julia
juliaup default release
julia --version           # dispatched by the wrapper to ~/.julia/juliaup/julia-X.Y.Z/bin/julia

# To pin a specific version instead:
# juliaup add 1.13 && juliaup default 1.13
```

## Updating

```bash
nix flake update
```

## About `flake.lock`

The `flake.lock` pins `nixpkgs` and `flake-utils` versions for reproducible builds. Commit it alongside `flake.nix`.
