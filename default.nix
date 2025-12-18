{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  inNixShell ? false,
}:
let
  # Should ideally get the source per project
  # Opened an issue about it gh:Koromix/rygel#93
  fullSrc =
    with lib.fileset;
    let
      root = gitTracked ./.;
      nixFiles = fileFilter (file: file.hasExt "nix") ./.;
    in
    toSource {
      root = ./.;
      fileset = difference root nixFiles;
    };
  felix = pkgs.callPackage (
    {
      lib,
      stdenv,
      fetchFromGitHub,
      installShellFiles,
    }:
    stdenv.mkDerivation (finalAttrs: {
      pname = "felix";
      version = "1.21-dev";
      src = fullSrc;
      nativeBuildInputs = [ installShellFiles ];
      buildPhase = ''
        runHook preBuild
        ./bootstrap.sh
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        installBin bin/Fast/felix
        runHook postInstall
      '';
      meta.mainProgram = "felix";
    })
  ) { };
in
pkgs.callPackage (
  {
    lib,
    fetchFromGitHub,
    versionCheckHook,
    installShellFiles,

    stdenv,
    clangStdenv,
    llvmPackages,
    nixosTests,

    # https://goupile.org/en/build recommends a Paranoid build
    # which is not bit by bit reproducible, whereas others are
    profile ? "Fast", # Debug/Fast
  }:
  let
    stdenv' = if (profile == "Paranoid") then clangStdenv else stdenv;
  in
  stdenv'.mkDerivation (finalAttrs: {
    pname = "goupile";
    version = "3.11.1-dev";
    src = fullSrc;

    nativeBuildInputs = [
      installShellFiles
      llvmPackages.bintools
      felix
    ];

    # pipe2() is only exposed with _GNU_SOURCE
    NIX_CFLAGS_COMPILE = [ "-D_GNU_SOURCE" ];

    # https://goupile.org/en/build recommends a Paranoid build
    buildPhase = ''
      runHook preBuild

      felixBin=''${felixBin:-"felix"}

      echo "goupile = ${finalAttrs.version}" >FelixVersions.ini
      cat FelixVersions.ini

      $felixBin -s -p${profile} goupile 2>/dev/null || \
        mkdir -p "$(\
          find bin/${profile} -maxdepth 1 \
          -type d ! -path 'bin/${profile}' -print\
        )/Misc"
      $felixBin -s -p${profile} goupile

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      installBin bin/${profile}/goupile
      runHook postInstall
    '';

    doInstallCheck = true;
    versionCheckProgramArg = "--version";
    nativeInstallCheckInputs = [ versionCheckHook ];

    # TODO important
    # A derivation should ideally not concern itself with development setup
    # if at all any such thing must be done, it should be for minor qol improvements
    # eg. felixBin=${felixBin:-felix}
    /*
      # do any nix shell setups via outside helpers
      # eg. symlink source, export dontunpack, also below
      if [ -n "$IN_NIX_SHELL" ]; then
        ./bootstrap.sh
        felixBin=./bin/Fast/felix
      fi
      # along with overrideAttrs to remove felix from buildDeps I guess
    */

    meta.mainProgram = "goupile";

    passthru.deps = { inherit felix; };
  })
) { }
