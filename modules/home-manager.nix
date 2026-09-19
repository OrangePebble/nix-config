{
  config,
  inputs,
  lib,
  funcs,
  vars,
  ...
}:
let
  homeDirectory = config.users.users.${vars.username}.home;
in
{
  imports = [
    inputs.home-manager.nixosModules.default
    (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" vars.username ])
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
    backupFileExtension = "backup";
    overwriteBackup = false;
    extraSpecialArgs = { inherit inputs; };
    # For modules shared by all users;
    sharedModules = [ ];
  };

  hm = {
    home = {
      username = vars.username;
      inherit homeDirectory;
      stateVersion = config.system.stateVersion;
    };

    # Nicely reload system units when changing configs.
    systemd.user.startServices = "sd-switch";

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    # Symlinking folders I care about to a sub home folder to have a cleaner home.
    home.file =
      let
        folders = {
          "desktop" = "Desktop";
          "downloads" = "Downloads";
          "audio" = "Music";
          "images" = "Pictures";
          "videos" = "Videos";
          "documents" = "Documents";
          ".dotfiles/config" = ".config";
          ".dotfiles/local" = ".local";
          ".dotfiles/var" = ".var";
          ".dotfiles/cache" = ".cache";
          ".dotfiles/steam" = ".steam";
          ".dotfiles/thunderbird" = ".thunderbird";
          ".dotfiles/ssh" = ".ssh";
          ".dotfiles/zsh_history" = ".zsh_history";
        };
      in
      builtins.listToAttrs (
        builtins.map (target: {
          name = "${lib.removePrefix (homeDirectory + "/") "${homeDirectory}/home"}/${target}";
          value = {
            source = funcs.mkOutOfStoreSymlink "${homeDirectory}/${folders.${target}}";
          };
        }) (builtins.attrNames folders)
      )
      // {
        # Allows for unfree packages to be used by nix-shell
        ".config/nixpkgs/config.nix".text = "{ allowUnfree = true; }";
      };
  };
}
