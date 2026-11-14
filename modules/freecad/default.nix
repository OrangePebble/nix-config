{
  pkgs,
  inputs,
  funcs,
  config,
  vars,
  ...
}:
{
  hm = {
    home.file = {
      ".config/FreeCAD/user.cfg".source = funcs.mkMutableConfigSymlink ./user.cfg.xml;

      ".config/FreeCAD/Mod/OpenTheme".source = inputs.freecad-open-theme;

      ".config/FreeCAD/Mod/HistoryWorkbench".source = inputs.freecad-history-workbench;

      ".config/FreeCAD/Mod/ToolSeek".source = inputs.freecad-tool-seek;

      # Register Tango's standard action icons for all FreeCAD commands.
      ".config/FreeCAD/Mod/00-IconTheme/Init.py".text = "";
      ".config/FreeCAD/Mod/00-IconTheme/InitGui.py".text = ''
        import FreeCADGui as Gui
        Gui.addIconPath("${pkgs.tango-icon-theme}/share/icons/Tango/scalable/actions")
      '';

      ".config/FreeCAD/Mod/CurvesWB".source = inputs.freecad-curves-wb;

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
