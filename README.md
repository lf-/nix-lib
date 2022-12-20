# Jade's Nix libraries

This is a set of Nix libraries I've written which I don't have a real place
for, but want to publish. Please feel free to simply vendor them if you'd like.
My goal is to keep each file self-contained.

## Contents

### `some-cabal-hashes.nix`

Super speedy version of `packageSourceOverrides` which does exactly one
import-from-derivation build, rather than doing one import-from-derivation for
each overridden package, potentially saving minutes if you have lots of
overrides.

For context, import-from-derivation is where you `import` a derivation or do
other things like `builtins.readFile` a derivation ([see the wiki for a full
list][wiki-ifd]). This causes the Nix evaluator to initiate a build for the
missing data *before* continuing any further evaluation: Nix's evaluator is
strictly serial and cannot do multiple things at once. Thus, if you have a lot
of *individual instances* of IFD in your build, it will do them painfully in
serial.

By comparison, this overlay does *one* IFD that depends on all the individual
pieces of the work that needs to be done, thereby doing all the `cabal2nix` and
`tar` extraction in one shot, as parallel as possible.

Another optimization this does is that since it knows everything that it is
extracting from the tarball, it passes all the files to get out to `tar`, which
improves ~10s *per package* to ~10s total (the reason for this follows from
`tar` files being a pile of records concatenated together with no index, so the
previous way was `O(packages * tarball-size)`, and this is `O(tarball-size)`).

[wiki-ifd]: https://nixos.wiki/wiki/Import_From_Derivation

When I put (more or less) this script into use at Mercury, it fixed a
problem where Nix would sit for *several minutes* building
`all-cabal-hashes-component-*` derivations, one at a time, each taking several
seconds. This was taken down to under 15 seconds for *all* the cabal2nix
derivations to complete building.

See [the example](./examples/some-cabal-hashes) for usage.

FIXME(jade): link blog post about this when it's done

### `nix2cabal.nix`

Converts Haskell Nix derivations to cabal project files, including git
dependencies and everything.

It reifies the Nix overlays affecting a certain package.

Example usage (illustrative):

```nix
let
  pkgs = import <nixpkgs> { };
  nix2cabal = import ./lib/nix2cabal.nix { inherit pkgs; };
  myHaskellPackage = pkgs.haskellPackages.callPackage "sample" ./. { };
in
  nix2cabal.nix2cabalProjectFile myHaskellPackage
```

Example result (see [./examples/nix2cabal](./examples/nix2cabal))

```ShellSession
examples/nix2cabal » nix build .#cabalProject.x86_64-linux
examples/nix2cabal » cat result
source-repository-package
  type: git
  location: https://github.com/gabriella439/haskell-pipes-library.git
  tag: 3997b02a5e226b5ba2eba347cb34616bdf76b596



constraints:
  vector ==0.12.3.1
```

This is an experiment with the opposite strategy as haskell.nix which uses
cabal.project as a source of truth: use Nix as a source of truth and generate
the non-nix artifacts from Nix.
