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

      solaar.enable = true;
    };
  hardware.logitech.wireless.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.sauce-code-pro
    nerd-fonts.fira-code
    monocraft # Minecraft themed font. Another good blocky is Scientifica.
    overpass # A good font for CAD/3D printing. A nerd-fonts variant also exists.
  ];

  environment.systemPackages = with pkgs; [
    blender
    chromium
    discord
    easyeffects
    ferdium
    firefox
    gimp-with-plugins
    gnome-logs # App to see system logs.
    gparted
    hieroglyphic # Find LaTeX symbols by sketching them.
    inkscape-with-extensions
    kdePackages.kate
    kdePackages.partitionmanager
    keepassxc
    libreoffice-qt-stable
    mission-center # Task manager like the one on windows. Looks nice.
    obs-studio
    obsidian
    p7zip
    qbittorrent
    qdirstat # Disk usage analyzer with the tree/block view. Alternative to WinDirStat and KDirStat.
    speedcrunch
    stirling-pdf-desktop # PDF editor. `pdf4qt` is a good alternative.
    supersonic # Subsonic/Navidrome client.
    unrar

    # Run unpatched binaries. Good for running "short-term" binaries where you
    #  don't want to add the required libraries to nix-ld.
    inputs.nix-alien.packages.${pkgs.stdenv.hostPlatform.system}.nix-alien

    # blanket # App to play background noise like rain and wind.
    # graphite # inkscape alternative, slows the rebuild too much
    # nocturne # Subsonic/Navidrome client.
    # planify # Task manager with CalDAV support.
  ];

  hm = {
    imports = [
      inputs.nix-flatpak.homeManagerModules.nix-flatpak
    ];

    services.flatpak = {
      # This will update flatpaks on rebuild, which will make rebuild not
      #  idempotent, oh well.
      update.onActivation = true;

      remotes = [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
        {
          name = "flathub-beta";
          location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
        }
      ];

      # `~/home/downloads` is an out-of-store symlink into /nix/store and OrcaSlicer can't access the symlink target.
      # When reading an .stl file, it reports this as a model with no geometry instead of a permissions error.
      overrides.settings."com.orcaslicer.OrcaSlicer".Context.filesystems = [
        "/nix/store:ro"
      ];

      packages = [
        "com.orcaslicer.OrcaSlicer"
        "io.github.phastmike.tags" # App to read files and add highlight lines based on tags.
        "me.iepure.devtoolbox"
        "re.sonny.OhMySVG" # App to make SVGs smaller.

        # Installing this as a flatpak so I can just use it casually without going through Nix.
        # To go through Nix see: https://wiki.nixos.org/wiki/Visual_Studio_Code
        "com.vscodium.codium"

        # rec {
        #   appId = "com.orcaslicer.OrcaSlicer";
        #   sha256 = "sha256-Q9N16m7ANyaJExDxQB2vcdy/nzfHQETugsxiBVeGYkc=";
        #   bundle = "${pkgs.fetchurl {
        #     url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/nightly-builds/OrcaSlicer-Linux-flatpak_nightly_x86_64.flatpak";
        #     inherit sha256;
        #   }}";
        # }

        # "camp.nook.nookdesktop" # App to play background music/noises from Animal Crossing.
      ];
    };
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
