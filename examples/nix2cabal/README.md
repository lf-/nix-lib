# nix2cabal sample

## Usage

```
examples/nix2cabal » nix build .#cabalProject.x86_64-linux
examples/nix2cabal » cat result
source-repository-package
  type: git
  location: https://github.com/gabriella439/haskell-pipes-library.git
  tag: 3997b02a5e226b5ba2eba347cb34616bdf76b596



constraints:
  vector ==0.12.3.1
```
