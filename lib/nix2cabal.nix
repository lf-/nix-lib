{ pkgs }:
let inherit (pkgs) lib;
in
rec {
  toConstraint = p: "${p.pname} ==${p.version}";
  toConstraints = ps: "constraints:\n  " +
    (builtins.concatStringsSep ",\n  " (builtins.map toConstraint ps));

  # Gets the subpath from a haskellSrc2nix invocation. Horrible. We should
  # really fix this in nixpkgs to passthru it instead of doing something this
  # evil, but whatever.
  getSubpathOfCabal2nix = drv:
    let match = builtins.match ".*--subpath=([^[:space:]]*)[[:space:]].*" drv.cabal2nixDeriver.buildCommand;
    in if match != null then builtins.elemAt match 0 else null;

  gitToSourceRepositoryPackage = drv:
    let subpath = getSubpathOfCabal2nix drv;
    in
    ''
      source-repository-package
        type: git
        location: ${drv.src.gitRepoUrl}
        tag: ${drv.src.rev}
        ${lib.optionalString (subpath != null) "subdir: ${subpath}"}
    '';

  gitDepsToSourceRepositoryPackage = drvs:
    builtins.concatStringsSep "\n\n"
      (builtins.map gitToSourceRepositoryPackage drvs);

  partitionDeps =
    let
      # we don't use builtins.partition in case there are more categories
      oneDep = acc: d:
        if d == null then
          acc
        # hackage, fetchurl
        else if lib.hasPrefix "mirror://hackage" d.src.url then
          acc // { hackageDeps = [ d ] ++ acc.hackageDeps; }
        else if d.src.gitRepoUrl != null then
          acc // { gitDeps = [ d ] ++ acc.gitDeps; }
        else
          acc // { unknownDeps = [ d ] ++ acc.unknownDeps; };
    in
    builtins.foldl' oneDep
      { hackageDeps = [ ]; gitDeps = [ ]; unknownDeps = [ ]; };

  # Takes a derivation from `callCabal2nix` and turns it into a set:
  #
  # nix2cabalProject :: NixDerivation -> Text
  #
  # Unfortunately this can't do anything to the shell derivations as produced
  # by mkShell, since they don't make the "combined deps" derivation available.
  # You can reimplement the code in there to achieve that though.
  nix2cabalProject = drv:
    let deps = partitionDeps drv.buildInputs;
    in
    ''
      ${gitDepsToSourceRepositoryPackage deps.gitDeps}

      ${toConstraints deps.hackageDeps}
    '';

  # Takes a derivation from `callCabal2nix` and turns it into a file:
  #
  # nix2cabalProjectFile :: NixDerivation -> Derivation
  nix2cabalProjectFile = drv: pkgs.writeText "cabal.project" (nix2cabalProject drv);
}
