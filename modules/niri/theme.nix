# Theme (and fonts)
{
  lib,
  config,
  pkgs,
  vars,
  ...
}:
{
  config = lib.mkIf config.opts.niri {
    systemd.tmpfiles.rules = [
      # Remove these backups that break things when I switch from plasma to niri.
      "r ${config.users.users.${vars.username}.home}/.config/gtk-3.0/settings.ini.backup - - - - -"
      "r ${config.users.users.${vars.username}.home}/.config/gtk-4.0/gtk.css.backup - - - - -"
      "r ${config.users.users.${vars.username}.home}/.config/gtk-4.0/settings.ini.backup - - - - -"
      "r ${config.users.users.${vars.username}.home}/.gtkrc-2.0.backup - - - - -"
    ];
    environment.sessionVariables = {
      QT_QPA_PLATFORM = "wayland";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      DMS_DISABLE_MATUGEN = "true"; # Disable theme generation
      # https://danklinux.com/docs/dankmaterialshell/application-themes#qt-applications
      QT_QPA_PLATFORMTHEME = "kde";
      QT_QPA_PLATFORMTHEME_QT6 = "kde";
    };
    hm = {
      home.pointerCursor = {
        enable = true;
        name = "phinger-cursors-dark";
        package = pkgs.phinger-cursors;
        # Size doesn't seem to work with niri, set it in the config file.
        # size = 32;
      };
      # https://danklinux.com/docs/dankmaterialshell/application-themes#gtk-applications
      gtk = {
        enable = true;
        colorScheme = "dark";
        theme = {
          name = "Breeze-Dark";
          package = pkgs.kdePackages.breeze-gtk;
        };
        gtk4.theme = {
          name = "Breeze-Dark";
          package = pkgs.kdePackages.breeze-gtk;
        };

        iconTheme = {
          name = "breeze-dark";
          package = pkgs.kdePackages.breeze-icons;
        };
      };
      # https://discourse.nixos.org/t/guide-to-installing-qt-theme/35523
      # https://danklinux.com/docs/dankmaterialshell/application-themes#qt-applications
      qt = {
        enable = true;
        style = {
          name = "breeze-dark";
        };
        platformTheme.name = "kde";
      };
      # Use 'dconf-editor' or 'gnome-tweaks' to find options you can change with this.
      dconf.settings = {
        "org/gnome/desktop/interface" = {
          # Fonts used by flakpak (and other things).
          document-font-name = "DejaVu Sans";
          font-name = "DejaVu Sans";
          monospace-font-name = "SauceCodePro Nerd Font";
        };
      };
    };
  };
}
