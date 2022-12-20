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
                  (overlay final prev);
            });
          };
        };
      };

      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.haskell-versions self.overlays.default ];
          };
        in
        {
          packages = rec {
            default = sample;
            sample = pkgs.haskell.packages.${ghcVer}.sample;
          };

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
        haskell-versions = makeHaskellOverlay (final: prev:
          import ../../lib/some-cabal-hashes.nix {
            self = final;

            overrides = {
              hs-opentelemetry-api = "0.0.3.5";

              pipes = final.fetchFromGitHub {
                owner = "gabriella439";
                repo = "haskell-pipes-library";
                # https://github.com/gabriella439/haskell-pipes-library/tree/main
                rev = "3997b02a5e226b5ba2eba347cb34616bdf76b596";
                sha256 = "sha256-9CN59Im0BC3vSVhL85v5eXPYYoPbV3NAuv893tXpr/U=";
              };
            };
          });
        default = makeHaskellOverlay
          (final: prev: hfinal: hprev:
            let hlib = prev.haskell.lib; in
            {
              sample = hfinal.callCabal2nix "sample" ./. { };
            });
      };
    };
}
