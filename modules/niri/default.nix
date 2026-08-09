{
  lib,
  config,
  pkgs,
  inputs,
  vars,
  funcs,
  ...
}:
{
  imports = [
    ./calendar.nix
    ./greeter.nix
    ./theme.nix # includes fonts
    ./plugins.nix
  ];

  config = lib.mkIf config.opts.niri {
    environment.systemPackages = with pkgs; [
      inputs.dms.packages.${vars.hostPlatform}.default
      xwayland-satellite
      kdePackages.dolphin
      kdePackages.kde-cli-tools # Contains tool used by dolphin to edit default file apps
      kdePackages.ark
      nomacs # Image viewer
      flameshot
      grim # Dependency for Flameshot in wayland
    ];
    programs = {
      niri = {
        enable = true;
        useNautilus = false;
      };
      dms-shell = {
        enable = true;
        # Use latest dms and quickshell.
        package = inputs.dms.packages.${vars.hostPlatform}.default;
        quickshell.package = inputs.quickshell.packages.${vars.hostPlatform}.quickshell;
      };
      dsearch.enable = true;
    };
    services = {
      # Backend of udiskie which manages removable media.
      udisks2.enable = true;
    };
    environment.sessionVariables = {
      GTK_USE_PORTAL = "1";
      XDG_MENU_PREFIX = "plasma-";
    };
    xdg.portal = {
      xdgOpenUsePortal = true;
      # Set values in '/etc/xdg/xdg-desktop-portal/niri-portals.conf'
      config.niri = {
        # Make Dolphin the file picker.
        # Overwritting https://github.com/NixOS/nixpkgs/blob/62dc67aa6a52b4364dd75994ec00b51fbf474e50/nixos/modules/programs/wayland/niri.nix#L53
        "org.freedesktop.impl.portal.FileChooser" = lib.mkForce "kde";
      };
    };
    users.users.${vars.username} = {
      extraGroups = [
        "i2c" # Required to change monitor brightness
      ];
    };
    hm = {
      xdg.configFile = {
        "niri" = {
          source = funcs.mkMutableConfigSymlink ./config;
          force = true;
        };
        "mimeapps.list" = {
          source = funcs.mkMutableConfigSymlink ./mimeapps.list;
          force = true;
        };
        "DankMaterialShell/settings.json" = {
          source = funcs.mkMutableConfigSymlink ./dms-settings.json;
          force = true;
        };
        "DankMaterialShell/clsettings.json" = {
          source = funcs.mkMutableConfigSymlink ./dms-clipboard-settings.json;
          force = true;
        };
        "flameshot/flameshot.ini" = {
          source = funcs.mkMutableConfigSymlink ./flameshot.ini;
          force = true;
        };
        "menus/applications.menu" = {
          text = builtins.readFile "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
          force = true;
        };
      };
      # Service to manage removable media.
      # Run 'nwg-look' to check the available GTK themes.
      services.udiskie = {
        enable = true;
        automount = false;
        settings = {
          program_options = {
            file_manager = "${pkgs.kdePackages.dolphin}/bin/dolphin";
          };
        };
      };
      # https://github.com/niri-wm/niri/discussions/1599
      # Runs a script that floats windows not just on launch.
      systemd.user.services.niri-dynamic-float = {
        Unit = {
          After = [ "niri.service" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.python3}/bin/python ${funcs.mkMutableConfigSymlink ./dynamic-float.py}";
        };
        Install = {
          WantedBy = [ "niri.service" ];
        };
      };
    };
  };
}
