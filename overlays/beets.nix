# https://nixcademy.com/posts/mastering-nixpkgs-overlays-techniques-and-best-practice/
inputs: final: prev: {
  # https://nixos.org/manual/nixpkgs/unstable/#how-to-override-a-python-package-for-all-python-versions-using-extensions
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/beetcamp/default.nix
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/beets-audible/default.nix
  # https://github.com/NixOS/nixpkgs/pull/471166
  # https://github.com/9999years/nixpkgs/blob/185e8e16f746a975245c3aa904002d63c944f584/pkgs/development/python-modules/beets/default.nix#L481-L496
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # To overwrite instead of creating a new package:
      # fee = python-prev.foo.overridePythonAttrs (oldAttrs: rec {
      beets-xtractor = python-prev.buildPythonPackage {
        pname = "beets-xtractor";
        version = "v0.4.2";
        pyproject = true;

        src = inputs.beets-xtractor;

        build-system = with python-prev; [
          setuptools
          poetry-core
        ];

        nativeBuildInputs = with python-prev; [
          beets
        ];

        passthru = {
          updateScript = python-prev.nix-update-script { };
        };
      };
      beets-yearfixer = python-prev.buildPythonPackage {
        pname = "beets-yearfixer";
        version = "v0.0.5";
        pyproject = true;

        src = inputs.beets-yearfixer;

        build-system = with python-prev; [
          setuptools
          poetry-core
        ];

        nativeBuildInputs = with python-prev; [
          beets
        ];

        passthru = {
          updateScript = python-prev.nix-update-script { };
        };
      };
      beets-maptag = python-prev.buildPythonPackage {
        pname = "beets-maptag";
        version = "master";
        pyproject = true;

        src = inputs.beets-maptag;

        build-system = with python-prev; [
          setuptools
        ];

        nativeBuildInputs = with python-prev; [
          beets
        ];

        passthru = {
          updateScript = python-prev.nix-update-script { };
        };
      };
    })
    (python-final: python-prev: {
      beets = python-prev.beets.override {
        pluginOverrides = {
          xtractor = {
            enable = true;
            propagatedBuildInputs = [ python-prev.beets-xtractor ];
          };
          yearfixer = {
            enable = true;
            propagatedBuildInputs = [ python-prev.beets-yearfixer ];
          };
          maptag = {
            enable = true;
            propagatedBuildInputs = [ python-prev.beets-maptag ];
          };
        };
      };
    })
  ];
}
