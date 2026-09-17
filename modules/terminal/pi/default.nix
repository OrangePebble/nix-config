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

    home.packages = [
      (pkgs.writeShellScriptBin "donsetch" ''
        exec "${config.hm.xdg.configHome}/pi/npm/node_modules/donsetch/binaries/donsetch" "$@"
      '')
    ];

    home.file = {
      ".config/pi/extensions/pi-permission-system/config.json".source =
        funcs.mkMutableConfigSymlink ./permission-system-conf.jsonc;
      ".config/pi/extensions/custom-footer.ts".source = funcs.mkMutableConfigSymlink ./custom-footer.ts;
      ".config/pi/extensions/custom-editor.ts".source = funcs.mkMutableConfigSymlink ./custom-editor.ts;
      ".config/pi/extensions/donsetch-fixes.ts".source = funcs.mkMutableConfigSymlink ./donsetch-fixes.ts;
      ".config/pi/extensions/socket-server.ts".source = funcs.mkMutableConfigSymlink ./socket-server.ts;
      ".config/pi/settings.json".source = funcs.mkMutableConfigSymlink ./settings.json;
      ".config/pi/APPEND_SYSTEM.md".source = funcs.mkMutableConfigSymlink ./APPEND_SYSTEM.md;
      ".config/donsetch/donsetch.toml".text = ''
        [browser]
        chromium_path = "${pkgs.chromium}/bin/chromium"
      '';
      ".config/rpiv-todo/config.json".text = ''{ "maxWidgetLines": 5 }'';
    };

    # Slop that installs packages and uninstalls any package that isn't in "packages".
    home.activation.installPiPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        packages = [
          "npm:@gotgenes/pi-permission-system@31.1.3"
          "npm:donsetch@4.1.0"
          "npm:@juicesharp/rpiv-ask-user-question@2.10.1"
          "npm:@juicesharp/rpiv-todo@2.10.1"
          "npm:pi-scroll-speed@0.2.0"
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
