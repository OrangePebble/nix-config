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

      ".config/FreeCAD/Mod/HistoryWorkbench".source = pkgs.fetchFromGitHub {
        owner = "eblanshey";
        repo = "HistoryWorkbench";
        rev = "ed8af4d7dcfd19eb1c9176c5d07578de0ae3ee97"; # master
        hash = "sha256-XPfVqYzoHJjtuNs8hm9oRdwOVsMQJwP8GOP5e4+3MRQ=";
      };

      ".config/FreeCAD/Mod/ToolSeek".source = pkgs.fetchFromGitHub {
        owner = "robdevtech";
        repo = "ToolSeek";
        rev = "3fcce7edf12277fb9f9c7159a37c1fabc998b491"; # main
        hash = "sha256-hYFHSZ0q+tbfjX1fiafzY39Y15/TJDDRV2tUWJqxpT0=";
      };

      # Register Tango's standard action icons for all FreeCAD commands.
      ".config/FreeCAD/Mod/00-IconTheme/Init.py".text = "";
      ".config/FreeCAD/Mod/00-IconTheme/InitGui.py".text = ''
        import FreeCADGui as Gui
        Gui.addIconPath("${pkgs.tango-icon-theme}/share/icons/Tango/scalable/actions")
      '';

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
