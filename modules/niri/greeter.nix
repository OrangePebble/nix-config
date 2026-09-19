{
  lib,
  config,
  vars,
  ...
}:
{
  config = lib.mkIf config.opts.niri {
    services = {
      displayManager.dms-greeter = {
        enable = true;
        configHome = config.users.users.${vars.username}.home;
        compositor = {
          name = "niri";
          customConfig = ''
            // Taken from ./config/dms/outputs.kdl
            output "DP-2" {
                mode "2560x1440@165.002"
                scale 1
                position x=0 y=0
                variable-refresh-rate on-demand=true
                focus-at-startup
            }
            output "HDMI-A-1" {
                off
                mode "1920x1080@144.001"
                scale 1
                position x=2560 y=180
                variable-refresh-rate on-demand=true
            }
            // Taken from https://danklinux.com/docs/dankgreeter/configuration#niri
            hotkey-overlay {
                skip-at-startup
            }
            environment {
                DMS_RUN_GREETER "1"
            }
            gestures {
              hot-corners {
                off
              }
            }
          '';
        };
      };
    };
    # Sync greeter with DMS.
    users.users.${vars.username} = {
      extraGroups = [
        "greeter"
      ];
    };
  };
}
