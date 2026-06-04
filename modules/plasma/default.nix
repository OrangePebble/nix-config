{
  pkgs,
  inputs,
  lib,
  config,
  vars,
  ...
}:
{
  imports = [
    ./displays.nix
  ];

  config = lib.mkIf config.opts.plasma {

    # Enable the KDE Plasma Desktop Environment.
    services = {
      displayManager.sddm.enable = true;
      displayManager.sddm.wayland.enable = true;
      desktopManager.plasma6.enable = true;
    };

    environment = {
      plasma6.excludePackages = with pkgs.kdePackages; [
        plasma-browser-integration
      ];
      systemPackages = with pkgs; [
        # kquitapp6
        kdePackages.kdbusaddons

        # MouseTiler KWin Plugin
        # Based on https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/po/polonium/package.nix
        # (stdenv.mkDerivation {
        #   pname = "mousetiler";
        #   version = "v5.2.0";
        #
        #   src = fetchurl {
        #     url = "https://github.com/rxappdev/MouseTiler/releases/download/v5.2.0/mousetiler.kwinscript";
        #     hash = "sha256-WF/7z8AXg/nR/Sh+0DWbWVi+emPihQMOdqNi6Y36Ep0=";
        #   };
        #
        #   nativeBuildInputs = with libsForQt5; [ plasma-framework ];
        #
        #   dontUnpack = true;
        #   dontWrapQtApps = true;
        #
        #   installPhase = ''
        #     runHook preInstall
        #
        #     plasmapkg2 --install $src --packageroot $out/share/kwin/scripts
        #
        #     runHook postInstall
        #   '';
        # })
      ];
    };

    hm = {
      imports = [
        inputs.plasma-manager.homeModules.plasma-manager
      ];

      programs.plasma = {
        enable = true;
        overrideConfig = true;
        workspace = {
          lookAndFeel = "org.kde.breezedark.desktop";
          enableMiddleClickPaste = false;
        };

        # Set dynamic Mountain workspace (changes depending on if it is day or night). Based on
        #  https://github.com/nix-community/plasma-manager/blob/44b928068359b7d2310a34de39555c63c93a2c90/modules/workspace.nix#L532-L588
        # This edits '~/.config/plasma-org.kde.plasma.desktop-appletsrc'.
        workspace.wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Mountain/#day-night";
        startup.desktopScript."dynamic_wallpaper" = {
          text = ''
            let allDesktops = desktops();
            for (const desktop of allDesktops) {
              desktop.wallpaperPlugin = "org.kde.image";
              desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
              desktop.writeConfig("DynamicMode", 1)
            }
          '';
          priority = 3;
        };
        # https://github.com/nix-community/plasma-manager/issues/577#issuecomment-3971533980
        # TODO: remove this after the bug (plasma 6.6 crashes when multiple panels are set which
        #  makes panels overlap and look wrong) is fixed
        startup.desktopScript."panels".preCommands = lib.mkForce ''
          sleep 3
          [ -f ${vars.homeDirectory}/.config/plasma-org.kde.plasma.desktop-appletsrc ] && rm ${vars.homeDirectory}/.config/plasma-org.kde.plasma.desktop-appletsrc
        '';

        # Enable and configure MouseTiler
        configFile."kwinrc" = {
          Plugins.mousetilerEnabled = true;
          Script-mousetiler = {
            hintCenterInTile = false;
            hintChangeMode = false;
            hintInputType = false;
            hintMoveOnDrop = false;
            autoTilerMode1 = 9;
            autoTilerMode2 = 1;
            autoTilerMode3 = 7;
            popupLayout = ''
              SPECIAL_AUTO_TILER_1
              SPECIAL_AUTO_TILER_2
              SPECIAL_AUTO_TILER_3
              2x2
              SPECIAL_MAXIMIZE
              0,0,75,100+25,0,75,100+25,0,50,100
              2x1
              0,0,25,100+75,0,25,100+25,20,50,60
              0,0,1/3,100+1/3,0,2/3,100
              SPECIAL_SPLIT_HORIZONTAL
              SPECIAL_FILL
              SPECIAL_SPLIT_VERTICAL
              SPECIAL_KEEP_ABOVE
              SPECIAL_KEEP_BELOW
              SPECIAL_FULLSCREEN
            '';
          };
        };

        # Use the command "plasma-interactiveconsole" and the following website
        #  to find some hard to get config values:
        #  https://develop.kde.org/docs/plasma/scripting/examples/#iterate-all-widgets-and-print-their-config-values
        # I've also included an example script to run with the command to get
        #  config values as ./interactiveconsolesave.js
        panels = [
          {
            location = "bottom";
            height = 44;
            screen = 0;
            lengthMode = "fit";
            alignment = "left";
            # Not using the included systemMonitor option because it sucks.
            widgets =
              let
                blue = "61,174,233";
                orange = "246,116,0";
                black = "0,0,0";
                # Taken from the systemMonitor option source code.
                toEscapedList =
                  ids: if ids != null then "[${lib.concatMapStringsSep ", " (x: ''\"${x}\"'') ids}]" else null;
              in
              [
                {
                  name = "org.kde.plasma.systemmonitor";
                  config = {
                    Appearance = {
                      title = "CPU Usage";
                      chartFace = "org.kde.ksysguard.linechart";
                      updateRateLimit = "1000";
                    };
                    SensorLabels = {
                      "cpu/all/usage" = "Usage";
                      "cpu/all/averageFrequency" = "Average Frequency";
                    };
                    SensorColors = {
                      "cpu/all/usage" = blue;
                    };
                    Sensors = {
                      highPrioritySensorIds = ''["cpu/all/usage"]'';
                      lowPrioritySensorIds = ''["cpu/all/averageFrequency"]'';
                    };
                  };
                }
                {
                  name = "org.kde.plasma.systemmonitor";
                  config = {
                    Appearance = {
                      title = "CPU Temperature";
                      chartFace = "org.kde.ksysguard.linechart";
                      updateRateLimit = "1000";
                    };
                    SensorLabels = {
                      "cpu/all/maximumTemperature" = "Maximum Temperature";
                      "cpu/all/averageTemperature" = "Average Temperature";
                    };
                    SensorColors = {
                      "cpu/all/maximumTemperature" = orange;
                    };
                    Sensors = {
                      highPrioritySensorIds = ''["cpu/all/maximumTemperature"]'';
                      lowPrioritySensorIds = ''["cpu/all/averageTemperature"]'';
                    };
                    "org.kde.ksysguard.linechart/General" = {
                      rangeAutoY = false;
                      rangeFromY = 40;
                      rangeToY = 95;
                    };
                  };
                }
                {
                  name = "org.kde.plasma.systemmonitor";
                  config = {
                    Appearance = {
                      title = "GPU Usage";
                      chartFace = "org.kde.ksysguard.linechart";
                      updateRateLimit = "1000";
                    };
                    SensorLabels = {
                      "gpu/gpu1/usage" = "Usage";
                      "gpu/gpu1/coreFrequency" = "Frequency";
                    };
                    SensorColors = {
                      "gpu/gpu1/usage" = blue;
                    };
                    Sensors = {
                      highPrioritySensorIds = ''["gpu/gpu1/usage"]'';
                      lowPrioritySensorIds = ''["gpu/gpu1/coreFrequency"]'';
                    };
                  };
                }
                {
                  name = "org.kde.plasma.systemmonitor";
                  config = {
                    Appearance = {
                      title = "GPU Temperature";
                      chartFace = "org.kde.ksysguard.linechart";
                      updateRateLimit = "1000";
                    };
                    SensorLabels = {
                      "gpu/gpu1/temp2" = "Junction Temperature"; # Hotspot
                      "gpu/gpu1/temperature" = "Temperature";
                    };
                    SensorColors = {
                      "gpu/gpu1/temp2" = orange;
                    };
                    Sensors = {
                      highPrioritySensorIds = ''["gpu/gpu1/temp2"]'';
                      lowPrioritySensorIds = ''["gpu/gpu1/temperature"]'';
                    };
                    "org.kde.ksysguard.linechart/General" = {
                      rangeAutoY = false;
                      rangeFromY = 40;
                      rangeToY = 110;
                    };
                  };
                }
                {
                  name = "org.kde.plasma.systemmonitor";
                  config = {
                    Appearance = {
                      title = "Memory Usage";
                      chartFace = "org.kde.ksysguard.linechart";
                      updateRateLimit = "1000";
                    };
                    SensorLabels = {
                      "memory/physical/used" = "Used Physical";
                      "memory/swap/used" = "Used Swap";
                    };
                    SensorColors = {
                      "memory/physical/used" = blue;
                      "memory/swap/used" = orange;
                    };
                    Sensors = {
                      highPrioritySensorIds = ''["memory/physical/used", "memory/swap/used"]'';
                    };
                  };
                }
                {
                  name = "org.kde.plasma.systemmonitor";
                  config = {
                    Appearance = {
                      title = "Network Speed";
                      chartFace = "org.kde.ksysguard.linechart";
                      updateRateLimit = "1000";
                    };
                    SensorLabels = {
                      "network/all/download" = "Download Rate";
                      "network/all/upload" = "Upload Rate";
                    };
                    SensorColors = {
                      "network/all/download" = blue;
                      "network/all/upload" = orange;
                    };
                    Sensors = {
                      highPrioritySensorIds = ''["network/all/download", "network/all/upload"]'';
                    };
                  };
                }
              ];
          }
          {
            location = "bottom";
            height = 44;
            screen = 0;
            lengthMode = "fit";
            alignment = "right";
            widgets = [
              "org.kde.plasma.marginsseparator"
              {
                systemTray.items = {
                  showAll = false;
                  shown = [
                    "org.kde.plasma.bluetooth"
                    "org.kde.plasma.networkmanagement"
                    "org.kde.plasma.volume"
                  ];
                  # Shown when relevant
                  # Broke when I just added 'syncthing'. I assume it's because if
                  #  I set 'shown', 'extra', and 'hidden', plasmoids not included
                  #  are disabled and it disabled something important.
                  extra = [
                    "org.kde.plasma.cameraindicator"
                    "org.kde.plasma.manage-inputmethod"
                    "org.kde.plasma.bluetooth"
                    "org.kde.plasma.keyboardlayout"
                    "org.kde.plasma.devicenotifier"
                    "org.kde.plasma.mediacontroller"
                    "org.kde.plasma.notifications"
                    "org.kde.kscreen"
                    "org.kde.plasma.brightness"
                    "org.kde.plasma.keyboardindicator"
                    "org.kde.plasma.networkmanagement"
                    "org.kde.plasma.printmanager"
                    "org.kde.plasma.volume"
                    "martchus.syncthingplasmoid"
                  ];
                  hidden = [
                    "org.kde.plasma.clipboard"
                    "Syncthing Tray"
                  ];
                };
              }
              {
                name = "org.kde.plasma.notes";
                config = {
                  General = {
                    color = "translucent";
                  };
                };
              }
              {
                digitalClock = {
                  calendar.firstDayOfWeek = "sunday";
                  time = {
                    format = "24h";
                    showSeconds = "always";
                  };
                  date.format.custom = "ddd dd/M";
                };
              }
            ];
          }
          # Put the middle panel last so it is on top if I restart plasmashell
          #  after I change values here, so it gets messed up.
          {
            location = "bottom";
            height = 44;
            screen = 0;
            minLength = 800;
            maxLength = 800;
            alignment = "center";
            widgets = [
              {
                kickoff = {
                  sortAlphabetically = true;
                  icon = "nix-snowflake-white";
                  sidebarPosition = "right";
                  showActionButtonCaptions = false;
                  showButtonsFor = "powerAndSession";
                  popupWidth = 791;
                };
              }
              {
                iconTasks = {
                  launchers = [
                    # "applications:org.kde.dolphin.desktop"
                    # "applications:org.kde.konsole.desktop"
                  ];
                  behavior = {
                    grouping.method = "none";
                    middleClickAction = "close";
                  };
                  appearance = {
                    highlightWindows = true;
                    rows = {
                      multirowView = "lowSpace";
                      maximum = 2;
                    };
                  };
                };
              }
            ];
          }
        ];

        input.mice = [
          {
            name = "Logitech USB Receiver";
            vendorId = "046d";
            productId = "c547";
            enable = true;
            acceleration = 0;
            accelerationProfile = "none";
          }
          {
            name = "Logitech G502 X LIGHTSPEED";
            vendorId = "046d";
            productId = "c098";
            enable = true;
            acceleration = 0;
            accelerationProfile = "none";
          }
          {
            name = "Keychron Keychron K4 Pro Mouse";
            vendorId = "3434";
            productId = "0240";
            enable = true;
            acceleration = 0;
            accelerationProfile = "none";
          }
        ];
        powerdevil.AC = {
          autoSuspend = {
            action = "nothing";
          };
          dimDisplay = {
            enable = false;
          };
          turnOffDisplay = {
            idleTimeout = "never";
            idleTimeoutWhenLocked = null;
          };
          whenSleepingEnter = "hybridSleep";
          powerProfile = "performance";
        };
        session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

        # Some config values and changed ones can be obtained by running rc2nix (altough a lot are missing):
        #  nix run github:nix-community/plasma-manager
        # Another way to figure out config values is by running fswatch on ~/.config and changing a setting manually.
        configFile = {
          # https://www.reddit.com/r/kde/comments/r5xir0/config_file_location_for_hot_corners/
          # Disable corners and edges that do things.
          # Change settings and look into ~/.config/kwinrc to see what does what.
          kwinrc.ElectricBorders = {
            Bottom = "None";
            BottomLeft = "None";
            BottomRight = "None";
            Left = "None";
            Right = "None";
            Top = "None";
            TopLeft = "None";
            TopRight = "None";
          };
          kwinrc.Effect-overview = {
            BorderActivate = 9;
          };

          # Disable auto lock.
          kscreenlockerrc.Daemon = {
            Autolock = false;
            Timeout = 0;
            #LockGrace = 30;
            LockOnResume = true;
          };

          # Fix bluetooth not being online on startup.
          bluedevilglobalrc.Adapters = {
            "F0:A6:54:4F:22:E0_powered" = true;
          };

          # Make max volume go to 150% and volume step to 2%.
          plasmaparc.General = {
            RaiseMaximumVolume = true;
            VolumeStep = 2;
          };

          # Makes F13 and up work normally and not be the dumb ones like "Tools".
          # The default shortcuts that use the dumb ones stop working, so thats a plus.
          # Found on Keyboard > Keyboard > Key Bindings
          kxkbrc.Layout = {
            ResetOldOptions = true;
            Options = "fkeys:basic_13-24";
          };

          # Limiting the clipboard for safety reasons.
          klipperrc.General = {
            MaxClipItems = 1;
            KeepClipboardContents = false;
            IgnoreImages = false;
          };

          # Make "foot" my default terminal.
          kdeglobals.General = {
            TerminalApplication = "foot";
            TerminalService = "foot.desktop";
          };
        };
        shortcuts = {
          # Some shortcuts and changed ones can be obtained by running rc2nix (altough a lot are missing):
          #  nix run github:nix-community/plasma-manager
          # You can export shortcuts from settings now, so just do that.

          # "<section>"."<key>" = "<shortcut>"
          # "<section>"."<key>" = [ "<shortcut1>" "<shortcut2>" "<others>" ]
          #  in kglobalshortcutssrc turns into
          #   <key>=<shortcut1>\t<shortcut2>\r<others>
          "kwin" = {
            "Window Fullscreen" = "Meta+F11";
          };
        };
      };
    };
  };
}
