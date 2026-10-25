{
  inputs,
  lib,
  config,
  pkgs,
  funcs,
  vars,
  ...
}:
{
  imports = [
    inputs.dms-plugin-registry.nixosModules.default
  ];

  config = lib.mkIf config.opts.niri {
    # Hover over the install button in the DMS plugin website to get the names.
    programs.dux-shell.plugins = {
      # Launcher plugins
      calculator.enable = true;
      dankGifSearch.enable = true;
      emojiLauncher.enable = true;
      dankObsidian.enable = true;
      dankStickerSearch.enable = true;
      dankLauncherKeys.enable = true;
      bongoCat.enable = true;

      amdGpuMonitorFork = {
        enable = true;
        src = pkgs.fetchFromGitHub {
          owner = "OrangePebble";
          repo = "dms-amd-gpu-monitor";
          rev = "main";
          hash = "sha256-i27ApSb1kCbkiW2Avv16OAPY5zLQg/9qHAxdY38SJLs=";
        };
      };
      focusedAppRemake = {
        enable = true;
        src = pkgs.fetchFromGitHub {
          owner = "OrangePebble";
          repo = "dms-focusedapp-widget-remake";
          rev = "master";
          hash = "sha256-Sjh3EacrJC9rusjAeigXtcycdVvyOaNqKHAoNv7Wtko=";
        };
      };
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
      # bongoCat
      libinput
    ];
    # bongoCat
    users.users.${vars.username}.extraGroups = [ "input" ];

    hm.xdg.configFile = {
      "DankMaterialShell/plugin_settings.json" = {
        source = funcs.mkMutableConfigSymlink ./dms-plugin-settings.json;
        force = true;
      };
    };
  };
}
