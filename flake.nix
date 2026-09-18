{
  description = "Nix flake for juliaup — Julia version manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
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
            maintainers = [
              {
                name = "Sébastien Celles";
                email = "s.celles@gmail.com";
              }
            ];
          };
        };

        # ── helper : binaire Julia officiel épinglé dans le store Nix ───────
        # Reproduit l'approche de nixpkgs generic-bin.nix :
        # autoPatchelf sur bin/lib/libexec, dontStrip (évite de casser les
        # backtraces), dontAutoPatchelf (exclut share/ qui contient des images
        # de packages Julia que patchelf casserait).
        mkJuliaBin =
          { version, hashes }:
          let
            mv = pkgs.lib.versions.majorMinor version;
          in
          pkgs.stdenv.mkDerivation {
            pname = "julia-bin";
            inherit version;

            src =
              {
                "x86_64-linux" = pkgs.fetchurl {
                  url = "https://julialang-s3.julialang.org/bin/linux/x64/${mv}/julia-${version}-linux-x86_64.tar.gz";
                  hash = hashes.x86_64-linux;
                };
                "aarch64-linux" = pkgs.fetchurl {
                  url = "https://julialang-s3.julialang.org/bin/linux/aarch64/${mv}/julia-${version}-linux-aarch64.tar.gz";
                  hash = hashes.aarch64-linux;
                };
                "x86_64-darwin" = pkgs.fetchurl {
                  url = "https://julialang-s3.julialang.org/bin/mac/x64/${mv}/julia-${version}-mac64.tar.gz";
                  hash = hashes.x86_64-darwin;
                };
                "aarch64-darwin" = pkgs.fetchurl {
                  url = "https://julialang-s3.julialang.org/bin/mac/aarch64/${mv}/julia-${version}-macaarch64.tar.gz";
                  hash = hashes.aarch64-darwin;
                };
              }
              .${system} or (throw "julia ${version} : plateforme non supportée : ${system}");

            nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.autoPatchelfHook
              pkgs.stdenv.cc.cc
            ];

            installPhase = ''
              runHook preInstall
              cp -r . $out
            ''
            + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              autoPatchelf "$out/bin" "$out/lib" "$out/libexec"
            ''
            + ''
              runHook postInstall
            '';

            dontStrip = true;
            dontAutoPatchelf = true;
            doCheck = false;

            meta = with pkgs.lib; {
              description = "Julia ${version} — high-performance dynamic language for technical computing";
              homepage = "https://julialang.org";
              license = licenses.mit;
              mainProgram = "julia";
              maintainers = [
                {
                  name = "Sébastien Celles";
                  email = "s.celles@gmail.com";
                }
              ];
            };
          };

        julia-1_12_0 = mkJuliaWrapper (mkJuliaBin {
          version = "1.12.0";
          hashes = {
            x86_64-linux = "sha256-b4e4/PXvanNx6MedlIrt+guijORER8RG19gucPAVjag=";
          };
        });

        # ── wrappers julia ───────────────────────────────────────────────────
        # Exec direct vers le store Nix — pas de dispatch runtime juliaup.
        # À inclure dans home.packages (pas environment.systemPackages) pour
        # éviter le conflit binaire avec julia-bin tiré transitivement par quarto.
        # Les deux wrappers exposent /bin/julia → n'installez qu'un seul à la fois.
        mkJuliaWrapper =
          drv:
          pkgs.writeShellScriptBin "julia" ''
            exec ${drv}/bin/julia "$@"
          '';
      in
      {
        packages = {
          default = juliaup;
          inherit juliaup;
          # binaires bruts (pas de /bin/julia dans PATH)
          inherit julia-1_12_0;
        };

        devShells =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            default = pkgs.callPackage ./shell.nix { inherit juliaup julia-1_12_0 pkgs; };
          };
      }
    );
}
