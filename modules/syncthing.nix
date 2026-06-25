{
  pkgs,
  lib,
  vars,
  ...
}:
{
  opts.autostartScripts.syncthingtray = ''
    ${lib.getExe pkgs.syncthingtray} --wait
  '';
  environment.systemPackages = with pkgs; [
    syncthingtray
  ];

  # Non-"home manager" syncthing fails to create this directory.
  systemd.tmpfiles.rules = [
    "d /var/lib/syncthing - ${vars.username} users - -"
  ];
  services.syncthing = {
    # WARNING: If something is wrong, syncthing will just not have any
    #  devices or folders.
    # INFO: Versioning cleanup interval uses a different method which
    #  nixpkgs doesn't seem to support.
    enable = true;
    user = vars.username;
    group = "users";
    openDefaultPorts = true;
    settings = {
      devices = {
        "phone".id = "R2RNYGN-BZPUWLZ-6OEOT77-ALGBSJP-MD2JPBY-AOY2T72-UX25SEB-H47LVAO";
        "tablet".id = "XR6AZSI-APGKKIB-LWMMCKW-6E63TBX-KFBSLVG-7JYURKQ-TZNGESZ-IVNNDQ5";
        "server".id = "GKSBJ6T-LGUK2JM-MDLC75Z-ALXOMTZ-DNYFZMM-IINFFXM-O7VCING-TIYQBAA";
      };
      folders = {
        "default" = {
          id = "default";
          path = "~/home/sync/default";
          devices = [
            "phone"
            "tablet"
            "server"
          ];
          versioning = {
            type = "staggered";
            params = {
              # cleanupIntervalS = "604800"; # clean once per week
              # params.maxAge = "31536000"; # 1 year
              maxAge = "0"; # 1 year
            };
          };
        };
        "obsidian-vaults" = {
          id = "obsidian-vaults";
          path = "~/home/obsidian-vaults";
          devices = [
            "phone"
            "tablet"
            "server"
          ];
          versioning = {
            type = "staggered";
            params.maxAge = "0"; # forever
          };
        };
        "music" = {
          id = "music";
          path = "~/home/audio/music";
          devices = [
            "server"
          ];
          versioning = {
            type = "staggered";
            params.maxAge = "0"; # forever
          };
        };
        "tachiyomi-backup" = {
          id = "tachiyomi-backup";
          path = "~/home/sync/tachiyomi-backup";
          devices = [
            "phone"
            "tablet"
            "server"
          ];
        };
        "WIT" = {
          id = "wit";
          path = "~/home/sync/WIT";
          devices = [
            "phone"
            "server"
          ];
        };
        "passwords" = {
          id = "passwords";
          path = "~/home/sync/passwords";
          devices = [
            "phone"
          ];
          versioning = {
            type = "staggered";
            params.maxAge = "0"; # forever
          };
        };
      };
    };
  };
}
