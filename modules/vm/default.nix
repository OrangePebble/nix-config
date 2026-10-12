{
  pkgs,
  vars,
  ...
}:
let
  vmName = "win11";
  radeonPciAddress = "0000:03:00.0";
  # This service, rather than `virsh start`, performs the experimental live
  # Radeon handoff. It runs outside the graphical user session that it stops.
  startVm = pkgs.writeShellScript "${vmName}-start" ''
    set -eu

    if ${pkgs.libvirt}/bin/virsh -c qemu:///system domstate ${vmName} 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx running; then
      echo "${vmName} is already running" >&2
      exit 1
    fi

    # Stopping greetd alone does not stop the already-logged-in niri user
    # service. Stop both the display manager and niri/DMS through its user bus.
    # Do not replace the DRM-node wait below with a fixed sleep: no process may
    # hold the Radeon when libvirt replaces amdgpu with vfio-pci.
    ${pkgs.systemd}/bin/systemctl stop display-manager.service
    tmp_uid="$(${pkgs.coreutils}/bin/id -u ${vars.username})"
    ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
      XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
      ${pkgs.systemd}/bin/systemctl --user stop dms.service app-easyeffects.script@autostart.service || true
    ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
      XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
      ${pkgs.systemd}/bin/systemctl --user stop niri.service

    shopt -s nullglob
    tmp_drm_nodes=()
    for tmp_node in /sys/bus/pci/devices/${radeonPciAddress}/drm/card*/dev /sys/bus/pci/devices/${radeonPciAddress}/drm/renderD*/dev; do
      tmp_drm_nodes+=("/dev/dri/$(basename "$(dirname "$tmp_node")")")
    done

    if [ "''${#tmp_drm_nodes[@]}" -eq 0 ]; then
      echo "could not find Radeon DRM nodes" >&2
      ${restoreDisplay}
      exit 1
    fi

    # Some autostarted user applications, such as EasyEffects, use only the
    # Radeon render node and outlive niri. Kill any remaining DRM users after
    # the graceful service shutdown above; the host session is being replaced
    # by Windows at this point, so these processes must not survive.
    ${pkgs.psmisc}/bin/fuser -k -TERM "''${tmp_drm_nodes[@]}" || true
    ${pkgs.coreutils}/bin/sleep 1
    # Some Electron clients ignore SIGTERM while their wrapper keeps the render
    # node open. A forced kill is required before a device-driver handoff.
    ${pkgs.psmisc}/bin/fuser -k -KILL "''${tmp_drm_nodes[@]}" || true

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

    if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system start ${vmName}; then
      ${restoreDisplay}
      exit 1
    fi

  '';

  restoreDisplay = pkgs.writeShellScript "${vmName}-restore-display" ''
    set -eu

    # When called as a libvirt hook, restore only for win11's release:end
    # event. This script is also called directly when win11-start aborts.
    if [ "$#" -ne 0 ] && { [ "$1" != "${vmName}" ] || [ "$2:$3" != "release:end" ]; }; then
      exit 0
    fi

    ${pkgs.systemd}/bin/systemctl start display-manager.service

    # The user manager survives the handoff, so DMS remains explicitly stopped
    # after niri starts again. Start it only after niri owns a Wayland socket.
    tmp_uid="$(${pkgs.coreutils}/bin/id -u ${vars.username})"
    tmp_attempt=0
    while ! { [ -S "/run/user/$tmp_uid/wayland-1" ] && ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
      XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
      ${pkgs.systemd}/bin/systemctl --user is-active --quiet niri.service; }; do
      tmp_attempt=$((tmp_attempt + 1))
      [ "$tmp_attempt" -lt 300 ] || exit 0
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    # DMS/Quickshell must connect after niri has bound its Wayland socket.
    ${pkgs.coreutils}/bin/sleep 1

    ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
      XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
      ${pkgs.systemd}/bin/systemctl --user reset-failed dms.service
    ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
      XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
      ${pkgs.systemd}/bin/systemctl --user start dms.service
  '';
in
{
  # The Radeon normally belongs to NixOS. AMD-Vi and VFIO modules are available
  # so libvirt can dynamically bind it only while win11 is running.
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
  ];
  boot.initrd.kernelModules = [
    "vfio"
    "vfio_pci"
    "vfio_iommu_type1"
  ];

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

  # USB policy passes only controllers 12:00.3 and 12:00.4. Group 27 cannot
  # be passed through: it includes upstream bridge 06:0c.0, which libvirt
  # rejects as a non-endpoint PCI hostdev. Do not add automatic USB forwarding
  # for the 10:00.0 chipset controller.
  systemd.services."${vmName}-start" = {
    description = "Safely hand the Radeon to ${vmName}";
    serviceConfig.Type = "oneshot";
    script = "exec ${startVm}";
  };

  users = {
    users.${vars.username}.extraGroups = [ "libvirtd" ];
    # NixOS's libvirtd module places the swtpm binaries on libvirtd's PATH but
    # does not create the local-CA state directory or its owning account.
    users.tss = {
      isSystemUser = true;
      group = "tss";
      home = "/var/lib/swtpm-localca";
      createHome = false;
    };
    groups.tss = { };
  };
  systemd.tmpfiles.rules = [
    # `Z` recursively repairs ownership of keys created by a failed swtpm
    # setup attempt before the tss account existed.
    "Z /var/lib/swtpm-localca 0750 tss root -"
  ];

  networking.firewall.trustedInterfaces = [ "virbr0" ];

  environment.systemPackages = with pkgs; [
    dnsmasq # DHCP and DNS for libvirt's default NAT network.
    pciutils # `lspci -nnk` and `lspci -nnv` for validating VFIO and IOMMU groups.
  ];

  # Experimental live-switch usage:
  # 1. Start Windows only with `sudo systemctl start win11-start`.
  # 2. Do not run `virsh start win11`: it bypasses the DRM-user safety check.
  # 3. Shut Windows down normally. The libvirt release hook restarts niri and
  #    DMS after amdgpu has reclaimed the Radeon; see README.md for recovery.
}
