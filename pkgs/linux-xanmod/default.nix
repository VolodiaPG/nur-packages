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
  _rc = "8";

  major = "${_major}.${_minor}";
  minor = _rc;
  version = "${major}.${minor}";
  release = "1";
  
  bore_version = "1.6.34.0";

  patches-src = fetchFromGitHub {
    owner = "firelzrd";
    repo = "bore-scheduler";
    rev = "e097de64f6cece82a9b80edf6e8dc2803383807a";
    sha256 = "sha256-NBe87JpPZZmqtKgGsCRTZrQiwvr3wJXGky+fHnYeTYo=";
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
in
buildLinux {
  inherit lib version;

  stdenv = if lto then stdenvLLVM else stdenv;
  extraMakeFlags = lib.optionals lto [ "LLVM=1" "LLVM_IAS=1" ];

  src = fetchFromGitHub {
    owner = "xanmod";
    repo = "linux";
    rev = "${version}-xanmod${release}";
    sha256 = "sha256-1ZHJ6Qu/MDcSwQjfQws3v/ZFECkUOGhIN8Z8J+nCIYc=";
  };
  modDirVersion = "${version}-volodiapg-bore-xanmod${release}";

  structuredExtraConfig =
    let
      cfg = import ./config.nix args;
    in
    if lto then
      ((builtins.removeAttrs cfg [ "GCC_PLUGINS" "FORTIFY_SOURCE" ]) // (with lib.kernel; {
        LTO_NONE = no;
        LTO_CLANG_FULL = yes;
      })) else cfg;

  kernelPatches = (builtins.map
    (name: {
      inherit name;
      patch = name;
    })
    [
      "${patches-src}/bore/0001-linux6.0.y-bore${bore_version}.patch"
    ]);

  extraMeta.broken = !stdenv.hostPlatform.isx86_64;
}
