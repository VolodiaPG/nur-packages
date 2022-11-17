{ pkgs
, stdenv
, lib
, fetchFromGitHub
, buildLinux
, lto ? true
, ...
} @ args:

# https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/kernel/linux-xanmod.nix
let
  _major = "6";
  _minor = "0";
  _rc = "9";

  major = "${_major}.${_minor}";
  minor = _rc;
  version = "${major}.${minor}";
  release = "1";

  patches-src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "kernel-patches";
    rev = "36110278e7995a632cc94b80175acfc3417f1a6b";
    sha256 = "sha256-CNhj1T/EOJIm+PJh0j6c1rlk6z0zhmNJfVO0kyWhK4A=";
  };

  config-src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "linux-cachyos";
    rev = "d93c94a";
    sha256 = "sha256-qBEnzJQZ498hsrzxTae8HWMdAV1i5OqAGslczBCcApQ=";
  };

  # https://github.com/NixOS/nixpkgs/pull/129806
  stdenvLLVM =
    let
      llvmPin = pkgs.llvmPackages_latest.override {
        bootBintools = null;
        bootBintoolsNoLibc = null;
      };

      stdenv' = pkgs.overrideCC llvmPin.stdenv llvmPin.clangUseLLVM;
    in
    stdenv'.override {
      extraNativeBuildInputs = [ llvmPin.lld pkgs.patchelf ];
    };

  configfile = builtins.storePath (builtins.toFile "config" (lib.concatStringsSep "\n"
    (map (builtins.getAttr "configLine") "${config-src}/linux-cachyos/config"))
  );
in
buildLinux {
  inherit lib version;

  allowImportFromDerivation = true;
  defconfig = "${config-src}/linux-cachyos/config";

  stdenv = if lto then stdenvLLVM else stdenv;
  extraMakeFlags = lib.optionals lto [ "LLVM=1" "LLVM_IAS=1" ];

  src = fetchTarball {
    url = "https://cdn.kernel.org/pub/linux/kernel/v${_major}.x/linux-${version}.tar.xz";
    sha256 = "sha256:1bmqvrbj8dz9qgsi1y1bs6zfkvnfm5nxmd56h83ldqdd1b9xb1k1";
  };

  modDirVersion = "${version}-cachyos-bore";

  structuredExtraConfig =
    let
      cfg = import ./config.nix args;
    in
    if lto then
      ((builtins.removeAttrs cfg [ "GCC_PLUGINS" "FORTIFY_SOURCE" ]) // (with lib.kernel; {
        LTO_NONE = no;
        LTO_CLANG_FULL = yes;
      })) else cfg;

  config = {
    # needed to get the vm test working. whatever.
    isEnabled = f: true;
    isYes = f: true;
  };

  kernelPatches = (builtins.map
    (name: {
      inherit name;
      patch = name;
    })
    [
      "${patches-src}/${major}/all/0001-cachyos-base-all.patch"
      "${patches-src}/${major}/misc/0001-Add-latency-priority-for-CFS-class.patch"
      "${patches-src}/${major}/sched/0001-bore-cachy.patch"
    ]);

  extraMeta.broken = !stdenv.hostPlatform.isx86_64;
}
