{
  pkgs,
  inputs,
  lib,
  vars,
  config,
  ...
}:
{
  imports = [
    inputs.nur.modules.nixos.default
  ];

  nixpkgs.config = {
    # Allow unfree packages
    allowUnfree = true;
    # Workaround for https://github.com/nix-community/home-manager/issues/2942
    allowUnfreePredicate = _: true;
  };

  # Required to install flatpak
  xdg.portal = {
    enable = true;
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
    extraPortals = with pkgs; [
      # I could use a mix of other portals with niri, but KDE's seems the most feature complete and
      #  seems to work fine.
      kdePackages.xdg-desktop-portal-kde
    ];
  };
  # Install flatpak binary.
  services.flatpak.enable = true;

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  programs =
    let
      # https://nixos.wiki/wiki/Games
      # https://discourse.nixos.org/t/programs-nix-ld-libraries-expects-set-instead-of-list/56009/4
      # https://wiki.nixos.org/wiki/FAQ#I've_downloaded_a_binary%2C_but_I_can't_run_it%2C_what_can_I_do%3F
      # Should make most binaries and appimages run.
      additional_libraries =
        pkgs.steam-run.args.multiPkgs pkgs
        ++ (with pkgs; [
          # Add any missing dynamic libraries for unpackaged binaries/appimages here, NOT in environment.systemPackages
          libusb1 # Wraith Master
          webkitgtk_4_1 # OrcaSlicer
        ]);
    in
    {
      # So that appimages can be run.
      appimage = {
        enable = true;
        binfmt = true;
        package = pkgs.appimage-run.override {
          extraPkgs = pkgs: additional_libraries;
        };
      };

      # So that regular binaries can be run.
      # This doesn't export to LD_LIBRARY_PATH in order to not affect packages that
      #  are correctly defined.
      # Run "export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH" if required.
      # Use "nix-alien" if you don't want to add libraries to this list and rebuild.
      nix-ld = {
        enable = true;
        libraries = additional_libraries;
      };

      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
      };
    };

  fonts.packages = with pkgs; [
    # My old monofont/programming font.
    nerd-fonts.fira-code
    # My default monofont/programming font.
    nerd-fonts.sauce-code-pro
    # A good font for CAD/3D printing.
    # A nerd-fonts variant also exists.
    overpass
  ];

  environment.systemPackages = with pkgs; [
    # Disk and partition managers.
    gparted
    kdePackages.partitionmanager

    # Run unpatched binaries. Good for running "short-term" binaries where you
    #  don't want to add the required libraries to nix-ld.
    inputs.nix-alien.packages.${vars.hostPlatform}.nix-alien

    # Archive tools.
    unrar
    p7zip
    # peazip

    # Document editors.
    kdePackages.kate
    libreoffice-qt6-fresh
    obsidian

    # Find LaTeX symbols by sketching them.
    hieroglyphic

    # Calculator.
    speedcrunch

    # Graphic editors.
    inkscape-with-extensions
    graphite # inkscape alternative
    gimp-with-plugins
    freecad
    blender

    # Downloading apps.
    qbittorrent

    # Media players.
    haruna
    mpv

    # Video recording/streaming.
    obs-studio

    # Messaging.
    discord
    element-desktop
    # App that aggregates websites and runs them in the background. Good for messaging websites.
    ferdium

    # GUI for dealing with git repos integrated with GitHub.
    github-desktop

    # Browsers.
    chromium
    firefox

    # Password manager.
    keepassxc

    # Audio equalizer and other effects.
    easyeffects

    # App to see system logs.
    gnome-logs

    # Task manager like the one on windows. Looks nice.
    mission-center

    # PDF editor.
    pdf4qt
  ];

  hm = {
    imports = [
      inputs.nix-flatpak.homeManagerModules.nix-flatpak
    ];

    # This will update flatpaks on rebuild, which will make rebuild not
    #  idempotent, oh well.
    services.flatpak.update.onActivation = true;
    services.flatpak.packages = [
      # App to make SVGs smaller.
      "re.sonny.OhMySVG"

      # App to read files and add highlight lines based on tags.
      "io.github.phastmike.tags"

      # App with lots of utilities for developers, like a chmod calculator, diff, QR code generator, and regex tester.
      "me.iepure.devtoolbox"

      # VSCode without the telemetry.
      # Installing this as a flatpak so I can just use it casually without going through Nix.
      # To go through Nix see: https://wiki.nixos.org/wiki/Visual_Studio_Code
      "com.vscodium.codium"

      # Slicer for 3D printing.
      rec {
        appId = "com.orcaslicer.OrcaSlicer";
        sha256 = "sha256-7e3nygrKHHpq4+9NOdkdq+kIwIfyiZ4ekO4a+iNf0EQ=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v2.3.2-rc2/OrcaSlicer-Linux-flatpak_V2.3.2-rc2_x86_64.flatpak";
          inherit sha256;
        }}";
      }
    ];
  };

  opts.autostartScripts = {
    discord = ''
      ${if config.opts.niri then "sleep 10" else ""}
      ${lib.getExe pkgs.discord} --start-minimized
    '';
    easyeffects = ''
      ${if config.opts.niri then "sleep 10" else ""}
      ${lib.getExe pkgs.easyeffects} --hide-window
    '';
    keepassxc = ''
      ${if config.opts.niri then "sleep 10" else ""}
      ${lib.getExe pkgs.keepassxc} --minimized
    '';
  };
  # opts.autostartSymlinks.discord = "${pkgs.discord}/share/applications/discord.desktop";
}
