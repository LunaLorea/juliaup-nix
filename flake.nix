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

          version = "1.22.3";

          juliaup = pkgs.rustPlatform.buildRustPackage {
            pname = "juliaup";
            inherit version;

            src = pkgs.fetchFromGitHub {
              owner = "JuliaLang";
              repo = "juliaup";
              rev = "v${version}";
              hash = "sha256-oWg5mGQpWDR9nU8b0S1XDa0CyssPfHCjZJeacvdO4RM=";
            };

            cargoHash = "sha256-AP+HG3GPHiT0prjXQT+OI4xOa4sOFi3uT3GN3lsqzz8=";

            # Les tests d'installation/désinstallation écrivent dans $HOME → échouent
            # en sandbox Nix. Désactivé complètement ; les tests unitaires passent.
            doCheck = false;

            meta = with pkgs.lib; {
              description = "Julia version manager — installs and manages Julia versions";
              homepage = "https://github.com/JuliaLang/juliaup";
              license = licenses.mit;
              mainProgram = "juliaup";
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
