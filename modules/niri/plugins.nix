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
        src = inputs.dms-amd-gpu-monitor;
      };
      focusedAppRemake = {
        enable = true;
        src = inputs.dms-focusedapp-widget-remake;
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
