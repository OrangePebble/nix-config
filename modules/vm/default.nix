# This is my configuration to have a Windows 11 VM with GPU and USB passthrough.
# INFO: To start the VM run: `sudo systemctl --no-block start win11-start`
# INFO: To apply changes after rebuilding the nix config, you may also need to run:
#  - `sudo systemctl restart libvirtd.service`
#  - `sudo systemctl restart libvirtd-config.service`
#  - `sudo virsh -c qemu:///system define modules/vm/win11.xml`
# INFO: If the VM has never been run, the disk has to be created using:
#  `sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11.qcow2 200G`
# And to increase the size of the disk later, run the following when the VM is off:
#  `sudo qemu-img resize /var/lib/libvirt/images/win11.qcow2 +100G`
# WARN: Bluetooth does not work very well because both the Host and the VM are the
#  same BT adapter but use different pairing keys, which has weird behaviour on
#  BT devices. Careful when using BT devices and try only pairing them to either
#  just the Host or just the VM.
{
  pkgs,
  vars,
  ...
}:
let
  vmName = "win11";

  restoreDisplay = pkgs.writeShellScript "${vmName}-restore-display" ''
    set -eu

    # When called as a libvirt hook, restore only for win11's release:end
    #  event. This script is also called directly when win11-start aborts.
    if [ "$#" -ne 0 ] && { [ "$1" != "${vmName}" ] || [ "$2:$3" != "release:end" ]; }; then
      exit 0
    fi

    # Restart BlueZ after the controller has returned to xhci_hcd.
    ${pkgs.systemd}/bin/systemctl restart bluetooth.service

    # The user has been logged out before the VM starts. Starting the display
    #  manager is sufficient; it presents the greeter and the next login starts
    #  a fresh niri session with DMS through graphical-session.target.
    ${pkgs.systemd}/bin/systemctl start display-manager.service
  '';
in
{
  programs.virt-manager.enable = true;
  virtualisation = {
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
      };
      hooks.qemu.restore-display = restoreDisplay;
    };
  };

  # The Radeon normally belongs to NixOS. AMD-Vi and VFIO modules are available
  #  so libvirt can dynamically bind it only while win11 is running.
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
  ];
  boot.initrd.kernelModules = [
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
  ];

  # This service, rather than `virsh start`, performs the live Radeon GPU handoff.
  # It runs outside the graphical user session that it stops.
  systemd.services."${vmName}-start" = {
    description = "Safely hand the Radeon to ${vmName}";
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      shopt -s nullglob

      if ${pkgs.libvirt}/bin/virsh -c qemu:///system domstate ${vmName} 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx running; then
        echo "${vmName} is already running" >&2
        exit 1
      fi

      # Stop the greeter before logging out the active graphical session, so it
      #  cannot start a replacement session while the Radeon is being detached.
      ${pkgs.systemd}/bin/systemctl stop display-manager.service

      # The MediaTek adapter is behind 10:00.0. Stop BlueZ before libvirt
      #  removes that controller so it does not retain a disappearing hci device.
      ${pkgs.systemd}/bin/systemctl stop bluetooth.service

      # Stop graphical-session.target first so the next login gets a fresh
      #  session transaction and automatically starts DMS again. Terminating the
      #  graphical session then stops niri and any remaining session processes.
      tmp_uid="$(${pkgs.coreutils}/bin/id -u ${vars.username})"
      ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
        XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
        ${pkgs.systemd}/bin/systemctl --user start niri-shutdown.target

      # Find and terminate only the user's active Wayland session. This logs out
      #  the graphical desktop while preserving SSH and other recovery sessions.
      tmp_session_id=""
      while read -r tmp_id tmp_session_uid tmp_session_user tmp_session_seat tmp_rest; do
        if [ "$tmp_session_user" = "${vars.username}" ] && [ "$(${pkgs.systemd}/bin/loginctl show-session "$tmp_id" -p Type --value 2>/dev/null)" = wayland ]; then
          tmp_session_id="$tmp_id"
          break
        fi
      done < <(${pkgs.systemd}/bin/loginctl list-sessions --no-legend)
      if [ -n "$tmp_session_id" ]; then
        ${pkgs.systemd}/bin/loginctl terminate-session "$tmp_session_id"
      fi

      # Discover the Radeon DRM nodes so the handoff can verify that no process
      #  still has the card or render device open before libvirt replaces amdgpu.
      tmp_drm_nodes=()
      for tmp_node in /sys/bus/pci/devices/0000:03:00.0/drm/card*/dev /sys/bus/pci/devices/0000:03:00.0/drm/renderD*/dev; do
        tmp_drm_nodes+=("/dev/dri/$(basename "$(dirname "$tmp_node")")")
      done
      if [ "''${#tmp_drm_nodes[@]}" -eq 0 ]; then
        echo "could not find Radeon DRM nodes" >&2
        ${restoreDisplay}
        exit 1
      fi
      # Some autostarted user applications, such as EasyEffects, use only the
      #  Radeon render node and outlive niri. Kill any remaining DRM users after
      #  the graceful service shutdown above; the host session is being replaced
      #  by Windows at this point, so these processes must not survive.
      ${pkgs.psmisc}/bin/fuser -k -TERM "''${tmp_drm_nodes[@]}" || true
      # Some Electron clients ignore SIGTERM while their wrapper keeps the render
      #  node open. A forced kill is required before a device-driver handoff.
      ${pkgs.coreutils}/bin/sleep 1
      ${pkgs.psmisc}/bin/fuser -k -KILL "''${tmp_drm_nodes[@]}" || true
      # Wait until no process has any Radeon DRM node open. This confirms that
      #  the driver can be detached without leaving a process using the device.
      tmp_attempt=0
      while ${pkgs.psmisc}/bin/fuser -s "''${tmp_drm_nodes[@]}"; do
        tmp_attempt=$((tmp_attempt + 1))
        if [ "$tmp_attempt" -ge 300 ]; then
          echo "timed out waiting for Radeon DRM users to exit" >&2
          ${restoreDisplay}
          exit 1
        fi
        ${pkgs.coreutils}/bin/sleep 0.1
      done
      ${pkgs.coreutils}/bin/sleep 1

      # A failed start may not emit libvirt's release:end hook, so restore the
      #  graphical session explicitly instead of leaving the host headless.
      if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system start ${vmName}; then
        ${restoreDisplay}
        exit 1
      fi
    '';
  };

  users = {
    users.${vars.username}.extraGroups = [ "libvirtd" ];
    # NixOS's libvirtd module places the swtpm (software TPM emulation) binaries on libvirtd's
    #  PATH but does not create the local-CA state directory or its owning account.
    users.tss = {
      isSystemUser = true;
      group = "tss";
      home = "/var/lib/swtpm-localca";
      createHome = false;
    };
    groups.tss = { };
  };
  systemd.tmpfiles.rules = [
    # `Z` recursively repairs ownership of keys created by a failed swtpm setup attempt before the tss account existed.
    "Z /var/lib/swtpm-localca 0750 tss root -"
  ];

  networking.firewall.trustedInterfaces = [ "virbr0" ];

  environment.systemPackages = with pkgs; [
    dnsmasq # DHCP and DNS for libvirt's default NAT network.
    pciutils # `lspci -nnk` and `lspci -nnv` for validating VFIO and IOMMU groups.
  ];
}
