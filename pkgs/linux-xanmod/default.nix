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
  _rc = "7";

  major = "${_major}.${_minor}";
  minor = _rc;
  version = "${major}.${minor}";
  release = "1";

  patches-src = fetchFromGitHub {
    owner = "firelzrd";
    repo = "bore-scheduler";
    rev = "18146e79ec617d48c5ebccf9da6976758c5cf26a";
    sha256 = "sha256-cMDZjA64QofcNRdxh2FNcF8yeNPiYiWZYDB5xgz2f9c=";
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
    sha256 = "sha256-qeM2oswuop42rvyBGlrH6VvODScLCpAOjTc4KR5a2Ec=";
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


  # kernelPatches = [ ];

  kernelPatches = (builtins.map
    (name: {
      inherit name;
      patch = name;
    })
    (lib.filesystem.listFilesRecursive "${patches-src}/bore"));
    # [
    #   # Block patches. Set BFQ as default
    #   # "${patches-src}/${major}/block/0001-block-Kconfig.iosched-set-default-value-of-IOSCHED_B.patch"
    #   # "${patches-src}/${major}/block/0002-block-Fix-depends-for-BLK_DEV_ZONED.patch"
    #   # "${patches-src}/${major}/block/0002-LL-elevator-set-default-scheduler-to-bfq-for-blk-mq.patch"
    #   # "${patches-src}/${major}/block/0003-LL-elevator-always-use-bfq-unless-overridden-by-flag.patch"

    #   # "${patches-src}/${major}/intel/xanmod/0001-intel_rapl-Silence-rapl-trace-debug.patch"
    #   # "${patches-src}/${major}/intel/xanmod/0002-firmware-Enable-stateless-firmware-loading.patch "
    #   # "${patches-src}/${major}/intel/xanmod/0003-locking-rwsem-spin-faster.patch"
    #   # "${patches-src}/${major}/intel/xanmod/0004-drivers-initialize-ata-before-graphics.patch"
    #   # "${patches-src}/${major}/intel/xanmod/0005-init-wait-for-partition-and-retry-scan.patch"

    #   "${patches-src}/${major}/misc/0001-Add-latency-priority-for-CFS-class.patch"
    #   "${patches-src}/${major}/sched/0001-bore-cachy.patch"
    # ]);



  extraMeta.broken = !stdenv.hostPlatform.isx86_64;
}
