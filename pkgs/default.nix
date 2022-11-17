# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { }
, inputs ? null
, ci ? false
, ...
}:

let
  sources = pkgs.callPackage ../_sources/generated.nix { };
  pkg = path: args: pkgs.callPackage path ({
    inherit sources;
  } // args);
  ifNotCI = p: if ci then null else p;
  ifFlakes = p: if inputs != null then p else null;
in
rec {
  # Binary cache information
  _binaryCache = pkgs.recurseIntoAttrs rec {
    url = "https://volodiapg.cachix.org";
    publicKey = "volodiapg.cachix.org-1:XcJQeUW+7kWbHEqwzFbwIJ/fLix3mddEYa/kw8XXoRI=";

    readme = pkgs.writeTextFile rec {
      name = "00000-readme";
      text = ''
        This NUR has a binary cache. Use the following settings to access it:

        nix.settings.extra-substituters = [ "${url}" ];
        nix.settings.extra-trusted-public-keys = [ "${publicKey}" ];

        Or, use variables from this repository in case I change them:

        nix.settings.substituters = [ nur.repos.volodiapg._binaryCache.url ];
        nix.settings.trusted-public-keys = [ nur.repos.volodiapg._binaryCache.publicKey ];

        Or, if you use NixOS <= 21.11:

        nix.binaryCaches = [ "${url}" ];
        nix.binaryCachePublicKeys = [ "${publicKey}" ];
      '';
      meta = {
        description = text;
        homepage = "https://github.com/volodiapg/nur-packages";
        license = pkgs.lib.licenses.unlicense;
      };
    };
  };

  # My packages
  svpflow = pkg ./svpflow { };

  linux-cachyos = pkg ./linux-cachyos { };
  linux-xanmod-volodiapg = pkg ./linux-xanmod { };

  # To use:
  # final: prev: {
  #   gnome = prev.nur.repos.volodiapg-nur-packages.gnome-smooth;
  # }
  gnome-smooth =  pkgs.gnome.overrideScope' (gself: gsuper: {
    mutter = gsuper.mutter.overrideAttrs (oldAttrs: {
      src = pkgs.fetchurl {
        url = "mirror://gnome/sources/mutter/${pkgs.lib.versions.major oldAttrs.version}/${oldAttrs.pname}-${oldAttrs.version}.tar.xz";
        sha256 = "8vCLJSeDlIpezILwDp6TWmHrv4VkhEvdkniKtEqngmQ=";
      };

      patches = [
        # Fix build with separate sysprof.
        # https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/2572
        (pkgs.fetchpatch {
          url = "https://gitlab.gnome.org/GNOME/mutter/-/commit/285a5a4d54ca83b136b787ce5ebf1d774f9499d5.patch";
          sha256 = "/npUE3idMSTVlFptsDpZmGWjZ/d2gqruVlJKq4eF4xU=";
        })
        # https://salsa.debian.org/gnome-team/mutter/-/blob/ubuntu/master/debian/patches/x11-Add-support-for-fractional-scaling-using-Randr.patch
        ./1441-main.patch
      ];
    });
  });
}
