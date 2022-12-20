{
  description = "Example for nix2cabal";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig.allow-import-from-derivation = true; # cabal2nix uses IFD

  outputs = { self, nixpkgs, flake-utils }:
    let
      ghcVer = "ghc924";
      makeHaskellOverlay = overlay: final: prev: {
        haskell = prev.haskell // {
          packages = prev.haskell.packages // {
            ${ghcVer} = prev.haskell.packages."${ghcVer}".override (oldArgs: {
              overrides =
                prev.lib.composeExtensions (oldArgs.overrides or (_: _: { }))
                  (overlay prev);
            });
          };
        };
      };

      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };

          nix2cabal = import ../../lib/nix2cabal.nix { inherit pkgs; };
        in
        {
          packages = rec {
            default = sample;
            sample = pkgs.haskell.packages.${ghcVer}.sample;
          };

          cabalProject = nix2cabal.nix2cabalProjectFile self.packages.${system}.sample;

          devShells.default =
            let haskellPackages = pkgs.haskell.packages.${ghcVer};
            in
            haskellPackages.shellFor {
              packages = p: [ self.packages.${system}.sample ];
              withHoogle = false;
              buildInputs = with haskellPackages; [
                cabal-install
              ];
            };
        };
    in
    flake-utils.lib.eachDefaultSystem out // {
      overlays = {
        default = makeHaskellOverlay
          (prev: hfinal: hprev:
            let hlib = prev.haskell.lib; in
            {
              sample = hfinal.callCabal2nix "sample" ./. { };

              # Git dependency
              pipes = hfinal.callCabal2nix "pipes"
                (prev.fetchFromGitHub {
                  owner = "gabriella439";
                  repo = "haskell-pipes-library";
                  # https://github.com/gabriella439/haskell-pipes-library/tree/main
                  rev = "3997b02a5e226b5ba2eba347cb34616bdf76b596";
                  sha256 = "sha256-9CN59Im0BC3vSVhL85v5eXPYYoPbV3NAuv893tXpr/U=";
                })
                { };
            });
      };
    };
}
