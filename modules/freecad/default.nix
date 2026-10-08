{
  funcs,
  config,
  vars,
  ...
}:
{
  hm = {
    home.file.".config/FreeCAD/user.cfg".source = funcs.mkMutableConfigSymlink ./user.cfg.xml;

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
