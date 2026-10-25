{ pkgs, funcs, ... }:
{
  environment.systemPackages = with pkgs; [
    (mpv.override {
      mpv-unwrapped = mpv-unwrapped.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace player/lua/select.lua --replace-fail 'script-binding select/select-watch-history' 'script-binding SimpleHistory/open-list'
        '';
      });
      scripts = [
        mpvScripts.mpris
        mpvScripts.modernz
        mpvScripts.thumbfast
        mpvScripts.eisa01.simplehistory
        mpvScripts.eisa01.undoredo
        mpvScripts.eisa01.smart-copy-paste-2
      ];
      # Make `Edit config file` or `Online documentation` in the mpv menu work.
      extraMakeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [
          glib
          wl-clipboard
        ])
      ];
    })
  ];

  hm.home.file = {
    ".config/mpv/mpv.conf".source = funcs.mkMutableConfigSymlink ./mpv.conf;
    ".config/mpv/input.conf".source = funcs.mkMutableConfigSymlink ./input.conf;
    ".config/mpv/script-opts/modernz.conf".source = funcs.mkMutableConfigSymlink ./modernz.conf;
    ".config/mpv/script-opts/SmartCopyPaste_II.conf".source =
      funcs.mkMutableConfigSymlink ./SmartCopyPaste_II.conf;
  };
}
