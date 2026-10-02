{
  pkgs,
  vars,
  config,
  ...
}:
{
  networking.interfaces.enp14s0.wakeOnLan.enable = true;

  # Accept all traffic from Tailscale unconditionally.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services = {
    # You'll need to run `tailscale login` manually the first time you enable this.
    tailscale.enable = true;

    xrdp = {
      # Use xrdp if sunshine is not enabled.
      enable = !config.opts.sunshine;
      defaultWindowManager = "startplasma-x11";
      openFirewall = !config.opts.sunshine;
    };

    # Key creation is done manually because it really only needs to be done once per system.
    # To create a key run (and don't forget to use a phassphrase):
    #  `ssh-keygen -f ~/.ssh/<filename>`
    openssh = {
      enable = true;
      ports = [ 22 ];
      settings = {
        # Require public key authentication for better security;
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
        TCPKeepAlive = "yes";
        AllowUsers = [ vars.username ]; # Allows all users by default. Can be [ "user1" "user2" ]
        X11Forwarding = false;
      };
    };
    fail2ban.enable = true;
  };

  programs.ssh = {
    # Remembers your ssh key passphrases so you don't have to write them everytime.
    # Run 'ssh-add ~/.ssh/<key>' to add a key to the agent.
    # Has to be disabled when niri is enabled because it includes the Gnome ssh-agent.
    startAgent = !config.opts.niri;
    # Allows KDE to remember SSH key passphrases across sessions.
    enableAskPassword = true;
  };
  environment.variables.SSH_ASKPASS_REQUIRE = "prefer";

  #
  # Sunshine
  #

  services.sunshine = {
    enable = config.opts.sunshine;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      output_name = 0;
    };
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin";
      };
      apps = [
        {
          name = "Desktop 1080p 60fps";
          image-path = "desktop.png";
          prep-cmd = [
            {
              do = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.mode.1920x1080@60";
              undo = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.mode.2560x1440@165";
            }
          ];
        }
        {
          name = "Steam Big Picture 1080p 60fps";
          image-path = "steam.png";
          detached = [
            "setsid steam steam://open/bigpicture"
          ];
          prep-cmd = [
            {
              do = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.mode.1920x1080@60";
              undo = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-1.mode.2560x1440@165";
            }
          ];
        }
        {
          name = "Desktop";
          image-path = "desktop.png";
        }
        {
          name = "Steam Big Picture";
          image-path = "steam.png";
          detached = [
            "setsid steam steam://open/bigpicture"
          ];
        }
      ];
    };
  };
  services.displayManager.autoLogin = {
    enable = config.opts.sunshine;
    user = "pebble";
  };
  # Automatically locks the system on startup if the system was started with autologin.
  # Made for use with Sunshine where I can access the system remotely but
  #  still have a password.
  opts.autostartScripts.lock-if-autologin = ''
    #! /usr/bin/env nix-shell
    #! nix-shell -i bash -p procps
    SDDM_TEST=`pgrep -xa sddm-helper`
    [[ $SDDM_TEST == *"--autologin"* ]] && loginctl lock-session
  '';
}
