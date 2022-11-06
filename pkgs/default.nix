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
    url = "https://volodiapg-nur-packages.cachix.org";
    publicKey = "volodiapg-nur-packages.cachix.org-1:sV/1k2wQC4ostoLRjsXM932vflOi7A5HzGJMBRxKe0s=";

    readme = pkgs.writeTextFile rec {
      name = "00000-readme";
      text = ''
        This NUR has a binary cache. Use the following settings to access it:

        nix.settings.substituters = [ "${url}" ];
        nix.settings.trusted-public-keys = [ "${publicKey}" ];

        Or, use variables from this repository in case I change them:

        nix.settings.substituters = [ nur.repos.volodiapg-nur-packages._binaryCache.url ];
        nix.settings.trusted-public-keys = [ nur.repos.volodiapg-nur-packages._binaryCache.publicKey ];

        > Or the extra- variants

        Or, if you use NixOS <= 21.11:

        nix.binaryCaches = [ "${url}" ];
        nix.binaryCachePublicKeys = [ "${publicKey}" ];
      '';
      meta = {
        description = text;
        homepage = "https://github.com/xddxdd/nur-packages";
        license = pkgs.lib.licenses.unlicense;
      };
    };
  };

  # My packages
  svpflow = pkg ./svpflow { };
}
