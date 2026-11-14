{
  description = "flake";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # Nix User Repository
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      # url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    direnv-instant = {
      url = "github:Mic92/direnv-instant";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pi = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tmux-tpm = {
      url = "github:tmux-plugins/tpm/master";
      flake = false;
    };

    dms-amd-gpu-monitor = {
      url = "github:OrangePebble/dms-amd-gpu-monitor/main";
      flake = false;
    };
    dms-focusedapp-widget-remake = {
      url = "github:OrangePebble/dms-focusedapp-widget-remake/master";
      flake = false;
    };

    beets-xtractor = {
      url = "github:adamjakab/BeetsPluginXtractor/v0.4.2";
      flake = false;
    };
    beets-yearfixer = {
      url = "github:adamjakab/BeetsPluginYearFixer/v0.0.5";
      flake = false;
    };
    beets-maptag = {
      url = "github:p-laranjinha/beets-maptag/master";
      flake = false;
    };
    essentia-models = {
      url = "https://essentia.upf.edu/svm_models/essentia-extractor-svm_models-v2.1_beta5.tar.gz";
      flake = false;
    };

    freecad-open-theme = {
      url = "github:obelisk79/OpenTheme/main";
      flake = false;
    };
    freecad-history-workbench = {
      url = "github:eblanshey/HistoryWorkbench/master";
      flake = false;
    };
    freecad-tool-seek = {
      url = "github:robdevtech/ToolSeek/main";
      flake = false;
    };
    freecad-curves-wb = {
      url = "github:tomate44/CurvesWB/main";
      flake = false;
    };

    orca-slicer-flatpak = {
      url = "file+https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v2.5.0-rc/OrcaSlicer-Linux-flatpak_V2.5.0-rc_x86_64.flatpak";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # Common information about the system that may be used in multiple locations.
      # Using camelCase because that is the standard for options. kebab-case is for packages and files.
      vars = import ./lib/vars inputs;
      system = "x86_64-linux";
      lib = (nixpkgs.lib.extend (_: _: home-manager.lib)).extend (import ./lib/lib);

      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
        allowUnfreePredicate = _: true;
        overlays = [ (import ./overlays/beets.nix inputs) ];
      };
    in
    {
      inherit lib;
      nixosConfigurations.${vars.hostname} = nixpkgs.lib.nixosSystem {
        inherit lib system;
        modules = (lib.attrValues (lib.modulesIn ./modules)) ++ [
          ./lib/funcs
          ./lib/opts
        ];
        specialArgs = {
          inherit inputs;
          inherit vars;
          inherit pkgs-stable;
        };
      };
    };
}
