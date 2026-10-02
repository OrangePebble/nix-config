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

  hardware.oculus-rift-cv1.enable = true;

  services.monado = {
    enable = true;
    defaultRuntime = true; # Register as default OpenXR runtime
    highPriority = true;
    package = config.hardware.oculus-rift-cv1.package;
  };
  systemd.user.services.monado.environment = {
    XRT_COMPOSITOR_COMPUTE = "1";
    # XRT_COMPOSITOR_FORCE_WAYLAND = "1";
    XRT_COMPOSITOR_FORCE_WAYLAND_DIRECT = "1";
    RIFT_EYE_HEIGHT = "1.7";
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
      defaultRuntime = true;

      # `services.monado` above already owns the socket-activated service.
      service.enable = false;

      openvr.enable = true;
      steamWrapper.enable = true;
      wayvr.enable = true;
    };
  };
}
