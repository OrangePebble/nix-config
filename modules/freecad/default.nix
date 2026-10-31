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

      ".config/FreeCAD/Mod/CurvesWB".source = pkgs.fetchFromGitHub {
        owner = "tomate44";
        repo = "CurvesWB";
        rev = "c08e21ba16b8d6c6846cee3c9a6b1ea950987f36"; # main
        hash = "sha256-r2fULNvf+durt7+YV7CmOlln59NaT9j1sNAnTRUGwcA=";
      };

      # CurvesWB requires scipy.
      ".config/FreeCAD/Mod/00-PythonPackages/Init.py".text = ''
        import sys
        sys.path.append("${pkgs.python313.withPackages (ps: [ ps.scipy ])}/${pkgs.python313.sitePackages}")
      '';
    };

    services.flatpak = {
      overrides.settings."org.freecad.FreeCAD" = {
        Context.filesystems = [ "/nix/store:ro" ];
        Environment.FREECAD_USER_HOME = "${config.users.users.${vars.username}.home}/.config/FreeCAD";
      };

      packages = [
        {
          appId = "org.freecad.FreeCAD";
          origin = "flathub-beta";
        }
        {
          # Pin KDE Platform 6.11 to the last commit known to work with
          # FreeCAD's bundled PySide until Flathub publishes a compatible build.
          appId = "org.kde.Platform//6.11";
          origin = "flathub";
          commit = "76fa01ac42ecf45d2c5020ef80de1c474c0c2ae86a51a79e8fec44c48f9dc473";
        }
      ];
    };
  };
}
