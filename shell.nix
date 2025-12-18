{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  inNixShell ? false, # https://github.com/NixOS/nix/pull/3168
}:
with pkgs;
mkShell.override ({ stdenv = clangStdenv; }) {
  shellHook =
    #bash
    ''
      inLegacyShell="${builtins.toString inNixShell}"
      inNix3Shell=
      if [ -n "$IN_NIX_SHELL" -a -z "$inLegacyShell" ]; then
        inNix3Shell=1
      fi
      echo "new:$inNix3Shell, old:$inLegacyShell"

      ln -s . source 2>/dev/null || true
      if [ "$inLegacyShell" ]; then
        export out="$(realpath -m "$PWD/outputs/out")"
      fi
    '';
  packages = [
    jq
    llvmPackages.bintools
    udev
  ];
}
