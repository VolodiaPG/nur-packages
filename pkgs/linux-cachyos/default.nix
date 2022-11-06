{ pkgs
, stdenv
, lib
, fetchFromGitHub
, buildLinux
, lto ? false
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
    owner = "CachyOS";
    repo = "kernel-patches";
    rev = "ff9fb0d3439982f11b53ad2c197fffe46a81b4e1";
    sha256 = "sha256-d8qpPlRvThtelqaDHNLL5D6eV6Dv3pFr3opXg5/eS7Q=";
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

  src = fetchTarball {
    url = "https://cdn.kernel.org/pub/linux/kernel/v${_major}.x/linux-${version}.tar.xz";
    sha256 = "sha256:0s2b2g57bzmcaidpcbn9k9hqb4bmahjk6hkfgva98pr92r5rq2nq";
  };

  modDirVersion = "${version}-cachyos-bore";

  structuredExtraConfig =
    let
      cfg = import ./config.nix args;
    in
    if lto then
      ((builtins.removeAttrs cfg [ "GCC_PLUGINS" "FORTIFY_SOURCE" ]) // (with lib.kernel; {
        LTO = yes;
        LTO_NONE = no;
        HAS_LTO_CLANG = yes;
        LTO_CLANG_FULL = yes;
        LTO_CLANG_THIN = no;
        HAVE_GCC_PLUGINS = yes;
      })) else cfg;


  # kernelPatches = [ ];

  kernelPatches = (builtins.map
    (name: {
      inherit name;
      patch = name;
    })
    # (lib.filesystem.listFilesRecursive "${patches-src}/bore"));
    [
      # Block patches. Set BFQ as default
      # "${patches-src}/${major}/block/0001-block-Kconfig.iosched-set-default-value-of-IOSCHED_B.patch"
      # "${patches-src}/${major}/block/0002-block-Fix-depends-for-BLK_DEV_ZONED.patch"
      # "${patches-src}/${major}/block/0002-LL-elevator-set-default-scheduler-to-bfq-for-blk-mq.patch"
      # "${patches-src}/${major}/block/0003-LL-elevator-always-use-bfq-unless-overridden-by-flag.patch"

      # "${patches-src}/${major}/intel/xanmod/0001-intel_rapl-Silence-rapl-trace-debug.patch"
      # "${patches-src}/${major}/intel/xanmod/0002-firmware-Enable-stateless-firmware-loading.patch "
      # "${patches-src}/${major}/intel/xanmod/0003-locking-rwsem-spin-faster.patch"
      # "${patches-src}/${major}/intel/xanmod/0004-drivers-initialize-ata-before-graphics.patch"
      # "${patches-src}/${major}/intel/xanmod/0005-init-wait-for-partition-and-retry-scan.patch"

      "${patches-src}/${major}/all/0001-cachyos-base-all.patch"
      "${patches-src}/${major}/misc/0001-Add-latency-priority-for-CFS-class.patch"
      "${patches-src}/${major}/sched/0001-bore-cachy.patch"
    ]);



  extraMeta.broken = !stdenv.hostPlatform.isx86_64;
}
