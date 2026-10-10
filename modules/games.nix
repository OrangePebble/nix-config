{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    # Make GE-Proton available in Steam's Compatibility-tool selector.
    extraCompatPackages = [ pkgs.proton-ge-bin ];
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
