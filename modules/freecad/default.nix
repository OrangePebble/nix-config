{
  pkgs,
  funcs,
  config,
  vars,
  ...
}:
{
  hm = {
    home.file = {
      ".config/FreeCAD/user.cfg".source = funcs.mkMutableConfigSymlink ./user.cfg.xml;

      ".config/FreeCAD/Mod/OpenTheme".source = pkgs.fetchFromGitHub {
        owner = "obelisk79";
        repo = "OpenTheme";
        rev = "de8a3a86ae6779993f07318557c18e7adf221dde"; # main
        hash = "sha256-z/tXHFIc/LZcesCUaeTR7Lp4DVOpwqIs4yve85l6JLA=";
      };
    };

    services.flatpak = {
      overrides.settings."org.freecad.FreeCAD".Environment.FREECAD_USER_HOME = "${
        config.users.users.${vars.username}.home
      }/.config/FreeCAD";

      packages = [
        {
          appId = "org.freecad.FreeCAD";
          origin = "flathub-beta";
        }
      ];
    };
  };
}
