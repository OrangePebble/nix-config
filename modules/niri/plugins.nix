{
  inputs,
  lib,
  config,
  pkgs,
  funcs,
  ...
}:
{
  imports = [
    inputs.dms-plugin-registry.nixosModules.default
  ];

  config = lib.mkIf config.opts.niri {
    # Hover over the install button in the DMS plugin website to get the names.
    programs.dms-shell.plugins = {
      # Launcher plugins
      calculator.enable = true;
      dankGifSearch.enable = true;
      emojiLauncher.enable = true;
      dankObsidian.enable = true;
      dankStickerSearch.enable = true;
      dankBitwarden.enable = true;
      dankLauncherKeys.enable = true;

      # Bar plugins
      # dankActions.enable = true;
      # easyEffects.enable = true;
      # musicLyrics.enable = true;

      # WARN: The following 2 aren't updating properly, so I'll just symlink to a repo "for now".
      #
      # amdGpuMonitorFork = {
      #   enable = true;
      #   src = pkgs.fetchFromGitHub {
      #     owner = "p-laranjinha";
      #     repo = "dms-amd-gpu-monitor";
      #     rev = "18e0610ebfc5cfe3a0c1d94374c935997efac0f6"; # 'alt-syles' branch
      #     hash = "sha256-i27ApSb1kCbkiW2Avv16OAPY5zLQg/9qHAxdY38SJLs=";
      #   };
      # };
      # focusedAppRemake = {
      #   enable = true;
      #   src = pkgs.fetchFromGitHub {
      #     owner = "p-laranjinha";
      #     repo = "dms-focusedapp-widget-remake";
      #     rev = "master";
      #     hash = "sha256-Sjh3EacrJC9rusjAeigXtcycdVvyOaNqKHAoNv7Wtko=";
      #   };
      # };
    };

    # Dependencies
    environment.systemPackages = with pkgs; [
      # calculator
      libqalculate
      # dankGifSearch
      curl
      kdePackages.qtimageformats
      # amdGpuMonitor
      amdgpu_top
    ];
    hm.programs = {
      # dankBitwarden
      # To finish configuring this, you'll have to:
      #  - Get the api key from the vault at 'Settings > Security > View API Key'.
      #  - 'rbw register'
      rbw = {
        enable = true;
        settings = {
          email = "plcasimiro2000@gmail.com";
          pinentry = pkgs.pinentry-qt; # GUI, looks good enough, and I can unhide the text.
        };
      };
    };

    hm.xdg.configFile = {
      "DankMaterialShell/plugin_settings.json" = {
        source = funcs.mkMutableConfigSymlink ./dms-plugin-settings.json;
        force = true;
      };
    };
  };
}
