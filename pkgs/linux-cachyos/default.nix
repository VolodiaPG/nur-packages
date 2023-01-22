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
  _minor = "1";
  _rc = "7";

  major = "${_major}.${_minor}";
  minor = _rc;
  version = "${major}.${minor}";
  release = "1";

  patches-src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "kernel-patches";
    rev = "8544d51e0557c59f438453ce1a4ac22764d244b2";
    sha256 = "093509fmlir6q1pw7di4pl2fizswgfyx8rz85kb5s8nj86jvcvqc";
  };

  config-src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "linux-cachyos";
    rev = "8d695c6ad213f7f5b9cf35bdcf7031084c113a22";
    sha256 = "0x4a48m4fki5g728laqd7ah8dm135dpxzc1mkr8sapbizabi6wvj";
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
    sha256 = "14pynxvjgqijzgk8c99cdnakszxf0wlqf3q9pbwa06xjdla9shdv";
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
