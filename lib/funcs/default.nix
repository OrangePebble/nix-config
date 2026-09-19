# For functions that depend on modules like nixos and home-manager.
# For more "pure"/standard functions check ../lib
{
  config,
  lib,
  funcs,
  vars,
  pkgs,
  ...
}:
with lib;
{
  # Using this options instead of '_module.args' directly because I can't set
  #  'funcs' im multiple places at once without an error otherwise (it wants
  #  arguments to be set only once. NixOS options merge all the different
  #  values set before acting on them.
  options.opts.funcs = mkOption {
    default = { };
    type = with types; attrsOf anything;
  };
  config = {
    # https://mynixos.com/nixpkgs/option/_module.args
    # Additional arguments passed to each module.
    # Default arguments like 'lib' and 'config' cannot be modified.
    _module.args.funcs = config.opts.funcs;

    opts.funcs = {
      mkOutOfStoreSymlink = path: config.hm.lib.file.mkOutOfStoreSymlink path;

      # When this is called 'path' is inside the nix store, so we need to replace
      #  the nix store path with the path to our config.
      # To do this, we need to replace the store prefix, and because this file is 2
      #  folders deep in the config `(toString ./../..)' is equivalent to the store
      #  directory.
      relativeToAbsoluteConfigPath =
        path:
        (
          "${config.users.users.${vars.username}.home}/home/nix-config"
          + removePrefix (toString ./../..) (toString path)
        );

      # Creates symlinks to these config files that can be changed without rebuilding.
      mkMutableConfigSymlink = path: funcs.mkOutOfStoreSymlink (funcs.relativeToAbsoluteConfigPath path);

      # https://www.reddit.com/r/NixOS/comments/scf0ui/comment/j3dfk27/
      # Replaces contents of the '.desktop' file of a package. Use like:
      # environment.systemPackages = with pkgs; [
      #   thunderbird
      #   (funcs.patchDesktop thunderbird "thunderbird"
      #     [ "Exec=thunderbird --name thunderbird %U" ]
      #     [ "env -U GDK_BACKEND=x11 thunderbird --name thunderbird %U" ]
      #   )
      # ];
      # With the arguments being:
      # - the package
      # - the '.desktop' basename (without the extension)
      # - a list of strings to replace
      # - a list of string that replace the previous list
      # It's better than using overlays as it doesn't affect the package derivation and therefore
      #  doesn't require recompiling the package (if it was required in the first place).
      patchDesktop =
        pkg: appName: from: to:
        with pkgs;
        let
          zipped = lib.zipLists from to;
          # Multiple operations to be performed by sed are specified with -e
          sed-args = builtins.map ({ fst, snd }: "-e 's#${fst}#${snd}#g'") zipped;
          concat-args = builtins.concatStringsSep " " sed-args;
        in
        lib.hiPrio (
          pkgs.runCommand "$patched-desktop-entry-for-${appName}" { } ''
            ${coreutils}/bin/mkdir -p $out/share/applications
            ${gnused}/bin/sed ${concat-args} \
             ${pkg}/share/applications/${appName}.desktop \
             > $out/share/applications/${appName}.desktop
          ''
        );
    };
  };
}
