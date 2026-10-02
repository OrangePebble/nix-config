{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    prismlauncher
    heroic
    cartridges
    itch

    osu-lazer-bin
  ];

  hm = {
    services.flatpak.packages = [
      "net.veloren.airshipper"
      "app.drey.MultiplicationPuzzle"
      "com.agateau.PixelWheels"
      "net.hhoney.tinycrate"
    ];
  };
}
