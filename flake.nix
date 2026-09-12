{
  description = "Nix flake for juliaup — Julia version manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs { inherit system; };

          # ── juliaup ─────────────────────────────────────────────────────────
          juliaup = pkgs.rustPlatform.buildRustPackage {
            pname = "juliaup";
            version = "1.22.3";

            src = pkgs.fetchFromGitHub {
              owner = "JuliaLang";
              repo = "juliaup";
              rev = "v1.22.3";
              hash = "sha256-oWg5mGQpWDR9nU8b0S1XDa0CyssPfHCjZJeacvdO4RM=";
            };

            cargoHash = "sha256-AP+HG3GPHiT0prjXQT+OI4xOa4sOFi3uT3GN3lsqzz8=";

            # Les tests d'installation/désinstallation écrivent dans $HOME → échouent
            # en sandbox Nix.
            doCheck = false;

            meta = with pkgs.lib; {
              description = "Julia version manager — installs and manages Julia versions";
              homepage = "https://github.com/JuliaLang/juliaup";
              license = licenses.mit;
              mainProgram = "juliaup";
              maintainers = [ { name = "Sébastien Celles"; email = "s.celles@gmail.com"; } ];
            };
          };

          # ── julia 1.13.0 (binaire officiel, épinglé dans le store Nix) ──────
          # Reproduit l'approche de nixpkgs generic-bin.nix :
          # autoPatchelf sur bin/lib/libexec, dontStrip (évite de casser les
          # backtraces), dontAutoPatchelf (on exclut share/ qui contient des
          # images de packages Julia que patchelf casserait).
          julia-1_13_0 = pkgs.stdenv.mkDerivation {
            pname = "julia-bin";
            version = "1.13.0";

            src = {
              "x86_64-linux" = pkgs.fetchurl {
                url = "https://julialang-s3.julialang.org/bin/linux/x64/1.13/julia-1.13.0-linux-x86_64.tar.gz";
                hash = "sha256-iXXaYcEopeXe0+cZ6GjajIeB3reteRPTf7mb4CqBkEs=";
              };
              "aarch64-linux" = pkgs.fetchurl {
                url = "https://julialang-s3.julialang.org/bin/linux/aarch64/1.13/julia-1.13.0-linux-aarch64.tar.gz";
                hash = "sha256-bNSj5Lqi3F9VY4wo6YNfwpT0HHitpKdA3ECENneKuLQ=";
              };
              "x86_64-darwin" = pkgs.fetchurl {
                url = "https://julialang-s3.julialang.org/bin/mac/x64/1.13/julia-1.13.0-mac64.tar.gz";
                hash = "sha256-QJ+2u/NNEGihKSpsH/qi4/JjVqmzGHzC7sLFZppVoTg=";
              };
              "aarch64-darwin" = pkgs.fetchurl {
                url = "https://julialang-s3.julialang.org/bin/mac/aarch64/1.13/julia-1.13.0-macaarch64.tar.gz";
                hash = "sha256-yFRq053p357ddLgQQGb7I74OzmCJC7Lb//rdJOc7osI=";
              };
            }.${system} or (throw "julia 1.13.0 : plateforme non supportée : ${system}");

            nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.autoPatchelfHook
              pkgs.stdenv.cc.cc
            ];

            installPhase = ''
              runHook preInstall
              cp -r . $out
            '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              autoPatchelf "$out/bin" "$out/lib" "$out/libexec"
            '' + ''
              runHook postInstall
            '';

            dontStrip = true;
            dontAutoPatchelf = true;
            doCheck = false;

            meta = with pkgs.lib; {
              description = "Julia 1.13.0 — high-performance dynamic language for technical computing";
              homepage = "https://julialang.org";
              license = licenses.mit;
              mainProgram = "julia";
              maintainers = [ { name = "Sébastien Celles"; email = "s.celles@gmail.com"; } ];
            };
          };

          # ── wrapper julia ────────────────────────────────────────────────────
          # Pointe directement sur le binaire Julia du store Nix (reproductible,
          # pas de dépendance runtime à juliaup ni à ~/.julia/juliaup/).
          # À inclure dans home.packages (pas environment.systemPackages) pour
          # éviter le conflit binaire avec julia-bin tiré transitivement par quarto.
          julia = pkgs.writeShellScriptBin "julia" ''
            exec ${julia-1_13_0}/bin/julia "$@"
          '';

        in {
          packages = {
            default = juliaup;
            inherit juliaup julia-1_13_0 julia;
          };

          apps.default = flake-utils.lib.mkApp { drv = juliaup; };
        });
}
