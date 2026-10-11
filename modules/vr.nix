# https://vronlinux.org/docs/distros/nixos
# https://wiki.nixos.org/wiki/VR
# https://github.com/MaySeikatsu/monado-rift-wayland
# To start VR run "systemd --user start monado".
# And to stop run "systemd --user stop monado".
{
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.monado-rift-wayland.nixosModules.default
  ];

  hardware.oculus-rift-cv1 = {
    enable = true;
    # Current upstream Monado contains the registered CV1/Rift Sensor builder;
    # nixpkgs' 25.1.0 package predates that integration.
    package = pkgs.monado.overrideAttrs (old: {
      version = "0-unstable-2026-10-10";
      # The nixpkgs 25.1 shader patch targets the older release only.
      patches = [ ];
      src = pkgs.fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "monado";
        repo = "monado";
        rev = "13b5c134b16c86ff3e3be52e8fa6dc720a8247e0";
        hash = "sha256-ql0SOTRuJiJa3XiA+3qoQJSvPLfWWRtfR0KDbqguv8k=";
      };
      buildInputs = old.buildInputs ++ [ pkgs.ceres-solver ];
      postPatch = (old.postPatch or "") + ''
        # Keep upstream's HMD/Touch driver and compositor. Only vendor the
        # fork's OpenHMD UVC/constellation core; the patch bridges its pose
        # output into the upstream devices.
        chmod -R u+w src
        legacy_tracker=src/xrt/drivers/rift/legacy_tracker
        mkdir -p "$legacy_tracker"
        cp -r ${inputs.monado-rift-wayland}/src/rift/ohmd "$legacy_tracker/ohmd"
        chmod -R u+w "$legacy_tracker"
        # These legacy startup messages used stdout, which systemd block-buffers
        # until the service exits. Send them to stderr so readiness is visible.
        substituteInPlace "$legacy_tracker/ohmd/drv_oculus_rift/rift-tracker.c" \
          --replace-fail 'printf("device %d online. Now tracking.\n", device_id);' \
                         'fprintf(stderr, "device %d online. Now tracking.\n", device_id);'
        substituteInPlace "$legacy_tracker/ohmd/drv_oculus_rift/rift-sensor-usb.c" \
          --replace-fail 'printf ("Opened Rift Sensor' 'fprintf (stderr, "Opened Rift Sensor'
        patch -p1 < ${./../patches/monado-rift-legacy-tracker-bridge.patch}
        patch -p1 < ${./../patches/monado-rift-legacy-tracker-disable-upstream-sensor.patch}
      '';
      cmakeFlags = old.cmakeFlags ++ [
        "-DXRT_HAVE_BIGCERES=ON"
        "-DXRT_MODULE_CONSTELLATION_TRACKING=ON"
        "-DXRT_BUILD_DRIVER_RIFT=ON"
        "-DXRT_BUILD_DRIVER_RIFT_SENSOR=ON"
      ];
    });
  };

  services.monado = {
    enable = true;
    defaultRuntime = true; # Register as default OpenXR runtime
    highPriority = true;
    package = config.hardware.oculus-rift-cv1.package;
  };
  systemd.user.services.monado.environment = {
    XRT_LOG = "error";
    XRT_COMPOSITOR_LOG = "info";
    XRT_COMPOSITOR_COMPUTE = "1";
    XRT_COMPOSITOR_FORCE_WAYLAND_DIRECT = "1";
    XRT_COMPOSITOR_SCALE_PERCENTAGE = "100";
    RIFT_LOG = "warn";
    RIFT_EYE_HEIGHT = "1.82";
    # Keep the upstream Rift builder, HID/radio devices and display path.
    # Its native constellation path is disabled so only the narrow legacy
    # UVC/OpenHMD pose bridge publishes camera tracking.
    RIFT_PROBER_ENABLE = "1";
    RIFT_PROBER_CONSTELLATION_TRACKING = "0";
    RIFT_LEGACY_CV1_TRACKER_BRIDGE = "1";
  };

  programs.steam = {
    package = pkgs.steam.override {
      extraProfile = ''
        # Fixes timezones in VRChat.
        unset TZ
      '';
    };
  };

  hm = {
    imports = [
      inputs.monado-rift-wayland.homeManagerModules.default
    ];

    programs.monado-rift = {
      enable = true;
      package = config.hardware.oculus-rift-cv1.package;
      defaultRuntime = true;
      service.enable = false;
      service.autoStart = false;

      openvr.enable = true;
      steamWrapper.enable = true;
      wayvr.enable = false;
    };
  };
}
