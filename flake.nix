{
  description = "Nix flake for juliaup — Julia version manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem
      [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
      (system:
        let
          pkgs = import nixpkgs { inherit system; };

          version = "1.22.3";

          srcs = {
            "x86_64-linux" = pkgs.fetchurl {
              url = "https://github.com/JuliaLang/juliaup/releases/download/v${version}/juliaup-${version}-x86_64-unknown-linux-musl-portable.tar.gz";
              sha256 = "0h02agk6xz1d98wjjb8njr8z0dnqmaiczwhf1yq58w5rsin7ppay";
            };
            "aarch64-linux" = pkgs.fetchurl {
              url = "https://github.com/JuliaLang/juliaup/releases/download/v${version}/juliaup-${version}-aarch64-unknown-linux-musl-portable.tar.gz";
              sha256 = "14n2w9bjjv6h4n1ril300a8paw2wqzvdc8mqbj9c4w8w4z0gifq6";
            };
            "aarch64-darwin" = pkgs.fetchurl {
              url = "https://github.com/JuliaLang/juliaup/releases/download/v${version}/juliaup-${version}-aarch64-apple-darwin-portable.tar.gz";
              sha256 = "0841023byypkdf0yj45sfbm42q4sy6ibdvl931iwkg4n5h5qyj96";
            };
            "x86_64-darwin" = pkgs.fetchurl {
              url = "https://github.com/JuliaLang/juliaup/releases/download/v${version}/juliaup-${version}-x86_64-apple-darwin-portable.tar.gz";
              sha256 = "1aa7xd487dpnh8r6whq4wwdqzrqwvsb1z8dvyp35wszdd8rrfxhv";
            };
          };

          juliaup = pkgs.stdenv.mkDerivation {
            pname = "juliaup";
            inherit version;
            src = srcs.${system};

            # Binaire musl statique — pas besoin de patchelf ni de bibliothèques.
            # On n'installe QUE `juliaup` (le gestionnaire), pas le shim `julia`
            # de l'archive : juliaup utilise current_exe() (résout les symlinks via
            # /proc/self/exe) pour son dispatch ; le shim de l'archive est un hardlink
            # au binaire juliaup lui-même, ce qui ne fonctionne pas cross-device (store
            # nix → home). Voir le package `julia` ci-dessous pour le wrapper correct.
            unpackPhase = "tar xzf $src";

            installPhase = ''
              mkdir -p $out/bin
              install -m755 juliaup $out/bin/
            '';

            meta = with pkgs.lib; {
              description = "Julia version manager — installs and manages Julia versions";
              homepage = "https://github.com/JuliaLang/juliaup";
              license = licenses.mit;
              platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
              maintainers = [ { name = "Sébastien Celles"; email = "s.celles@gmail.com"; } ];
            };
          };

          # Wrapper `julia` : juliaup dispatche via current_exe() qui résout les
          # symlinks sur Linux (/proc/self/exe → chemin store), donc un simple
          # symlink julia→juliaup ne déclenche pas le mode Julia. Ce script lit
          # ~/.julia/juliaup/juliaup.json avec jq et exec le bon binaire Julia.
          # À inclure dans home.packages (pas environment.systemPackages) pour
          # éviter le conflit binaire avec julia-bin tiré transitivement par quarto.
          julia = pkgs.writeShellScriptBin "julia" ''
            depot="''${JULIAUP_DEPOT_PATH:-$HOME/.julia/juliaup}"
            json="$depot/juliaup.json"
            [ -f "$json" ] || { echo "julia: juliaup not initialized. Run: juliaup add release" >&2; exit 1; }
            default=$(${pkgs.jq}/bin/jq -r '.Default' "$json")
            version=$(${pkgs.jq}/bin/jq -r --arg ch "$default" '.InstalledChannels[$ch].Version' "$json")
            julia_bin="$depot/julia-$version/bin/julia"
            [ "$version" != "null" ] && [ -x "$julia_bin" ] && exec "$julia_bin" "$@"
            echo "julia: no default version set. Run: juliaup add release && juliaup default release" >&2
            exit 1
          '';
        in {
          packages = {
            default = juliaup;
            inherit juliaup julia;
          };

          apps.default = flake-utils.lib.mkApp { drv = juliaup; };
        });
}
