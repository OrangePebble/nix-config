{ pkgs, funcs, ... }:
{
  programs = {
    tmux.enable = true;
  };

  hm = {
    home.file = {
      ".config/tmux/tmux.conf".source = funcs.mkMutableConfigSymlink ./tmux.conf;
      ".config/tmux/plugins/tpm".source = funcs.mkOutOfStoreSymlink (
        pkgs.fetchFromGitHub {
          owner = "tmux-plugins";
          repo = "tpm";
          rev = "master";
          hash = "sha256-hW8mfwB8F9ZkTQ72WQp/1fy8KL1IIYMZBtZYIwZdMQc=";
        }
      );
      ".config/tmux/plugins/tmux-which-key/config.yaml".source =
        funcs.mkMutableConfigSymlink ./which-key.yaml;
      ".config/tmux/scripts".source = funcs.mkMutableConfigSymlink ./scripts;

      # Taken from the "foot" desktop file.
      # Maybe use pkgs.makeDesktopItem next time.
      ".local/share/applications/tmux.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Exec=foot tmux new -A
        Icon=foot
        Terminal=false
        Categories=System;TerminalEmulator;
        Keywords=shell;prompt;command;commandline;

        Name=tmux
        Comment=A terminal multiplexer (launched with foot)
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    # Library for notifications.
    libnotify
  ];
}
