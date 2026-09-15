{
  config,
  inputs,
  lib,
  pkgs,
  vars,
  funcs,
  ...
}:
{
  hm = {
    imports = [
      inputs.pi.homeModules.default
    ];

    programs.pi.coding-agent = {
      enable = true;
      environment.PI_CODING_AGENT_DIR.value = "${config.hm.xdg.configHome}/pi";
    };

    home.file = {
      ".config/pi/extensions/pi-permission-system/config.json".source =
        funcs.mkMutableConfigSymlink ./permission-system-conf.json;
      ".config/pi/settings.json".source = funcs.mkMutableConfigSymlink ./settings.json;
    };

    # Slop that installs packages and uninstalls any package that isn't in "packages".
    home.activation.installPiPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        packages = [
          "npm:@gotgenes/pi-permission-system@31.1.3"
          "npm:@dietrichgebert/ponytail@4.9.0"
          "npm:donsetch@4.1.0"
        ];
      in
      #bash
      ''
        pi() {
          # Added dependencies to the path because it was required to install donsetch
          PATH=${
            lib.makeBinPath [
              pkgs.gnutar
              pkgs.gzip
            ]
          }:"$PATH" \
            PI_CODING_AGENT_DIR=${lib.escapeShellArg "${config.hm.xdg.configHome}/pi"} \
            ${config.hm.programs.pi.coding-agent.package}/bin/pi "$@"
        }

        desired_packages=(
        ${lib.concatMapStringsSep "\n" (package: "  ${lib.escapeShellArg package}") packages}
        )

        for package in "''${desired_packages[@]}"; do
          $DRY_RUN_CMD pi install "$package"
        done

        if [ -z "$DRY_RUN_CMD" ]; then
          pi list | while IFS= read -r line; do
            case "$line" in
              "User packages:")
                user_packages=true
                ;;
              "Project packages:"*)
                break
                ;;
              "  npm:"* | "  git:"* | "  http:"* | "  https:"* | "  ssh:"*)
                if [ "''${user_packages:-false}" = true ]; then
                  package="''${line#  }"
                  desired=false
                  for wanted in "''${desired_packages[@]}"; do
                    if [ "$package" = "$wanted" ]; then
                      desired=true
                      break
                    fi
                  done
                  if [ "$desired" = false ]; then
                    pi remove "$package"
                  fi
                fi
                ;;
            esac
          done
        fi
      ''
    );
  };
}
