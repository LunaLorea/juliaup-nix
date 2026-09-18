{
  juliaup,
  julia-1_12_0,
  pkgs,
}:
pkgs.mkShellNoCC {
  packages = [
    juliaup
    julia-1_12_0
  ];
  shellHook = ''
    juliaup default 1.12
    juliaup remove custom
    juliaup link custom ${julia-1_12_0}/bin/julia
    juliaup default custom
    zsh
  '';
}
