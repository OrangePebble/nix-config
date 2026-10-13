# This is my configuration to have a Windows 11 VM with GPU and USB passthrough.
# INFO: Start the VM from the “Windows 11” desktop entry, or run:
#  `virsh -c qemu:///system start win11`
# INFO: To apply changes after rebuilding the nix config, you may also need to run:
#  - `sudo systemctl restart libvirtd.service`
#  - `sudo systemctl restart libvirtd-config.service`
#  - `virsh -c qemu:///system define modules/vm/win11.xml`
# INFO: If the VM has never been run, the disk has to be created using:
#  `sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11.qcow2 200G`
# And to increase the size of the disk later, run the following when the VM is off:
#  `sudo qemu-img resize /var/lib/libvirt/images/win11.qcow2 +100G`
# WARN: USB devices can't be connected to the red ports while the VM is starting or
#  the whole PC will crash. Other ports are fine, and the red ports can be used
#  while the VM is running.
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

  # This is run by libvirtd as root, not by the program that requested the VM start.
  # It runs outside the graphical user session that it stops.
  lifecycleHook = pkgs.writeShellScript "${vmName}-lifecycle" ''
    set -eu
    shopt -s nullglob

    # QEMU hooks receive: domain name, operation, suboperation, and extra args.
    # This hook is installed globally, so ignore events for other domains.
    if [ "$#" -lt 3 ] || [ "$1" != "${vmName}" ]; then
      exit 0
    fi

    restore_host() {
      # During prepare:begin the USB controller is still host-owned; during
      #  release:end it has been rebound to xhci_hcd. Restarting BlueZ in either
      #  case clears any stale controller state.
      ${pkgs.systemd}/bin/systemctl restart bluetooth.service || true
      # The user has been logged out before the VM starts. Starting the display
      #  manager presents the greeter; the next login starts a fresh niri/DMS
      #  session through graphical-session.target.
      ${pkgs.systemd}/bin/systemctl start display-manager.service || true
    }

    case "$2:$3" in
      prepare:begin)
        # Every failure after this point must restore the host. A non-zero hook
        #  exit rejects the domain start before libvirt detaches the Radeon.
        tmp_handoff_complete=0
        cleanup() {
          tmp_status="$?"
          if [ "$tmp_handoff_complete" -eq 0 ]; then
            restore_host
          fi
          exit "$tmp_status"
        }
        trap cleanup EXIT

        # Stop the greeter before logging out the active graphical session, so
        #  it cannot start a replacement session during the Radeon handoff.
        ${pkgs.systemd}/bin/systemctl stop display-manager.service

        # The MediaTek adapter is behind 10:00.0. Stop BlueZ before libvirt
        #  removes that controller so it does not retain a disappearing hci device.
        ${pkgs.systemd}/bin/systemctl stop bluetooth.service

        # Stop graphical-session.target first so the next login gets a fresh
        #  session transaction and automatically starts DMS again. Terminating
        #  the graphical session then stops niri and remaining session processes.
        tmp_uid="$(${pkgs.coreutils}/bin/id -u ${vars.username})"
        ${pkgs.util-linux}/bin/runuser -u ${vars.username} -- ${pkgs.coreutils}/bin/env \
          XDG_RUNTIME_DIR="/run/user/$tmp_uid" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$tmp_uid/bus" \
          ${pkgs.systemd}/bin/systemctl --user start niri-shutdown.target

        # Find and terminate only the user's active Wayland session. This logs
        #  out the graphical desktop while preserving SSH and recovery sessions.
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

        # Discover the Radeon DRM nodes so the handoff can verify that no
        #  process still has the card or render device open before libvirt
        #  replaces amdgpu.
        tmp_drm_nodes=()
        for tmp_node in /sys/bus/pci/devices/0000:03:00.0/drm/card*/dev /sys/bus/pci/devices/0000:03:00.0/drm/renderD*/dev; do
          tmp_drm_nodes+=("/dev/dri/$(basename "$(dirname "$tmp_node")")")
        done
        if [ "''${#tmp_drm_nodes[@]}" -eq 0 ]; then
          echo "could not find Radeon DRM nodes" >&2
          exit 1
        fi

        # Autostarted applications may use only the Radeon render node and
        #  outlive niri. The host session is being replaced by Windows, so they
        #  must not survive the driver handoff.
        ${pkgs.psmisc}/bin/fuser -k -TERM "''${tmp_drm_nodes[@]}" || true
        ${pkgs.coreutils}/bin/sleep 1
        ${pkgs.psmisc}/bin/fuser -k -KILL "''${tmp_drm_nodes[@]}" || true

        # Confirm that the driver can be detached without a process using it.
        tmp_attempt=0
        while ${pkgs.psmisc}/bin/fuser -s "''${tmp_drm_nodes[@]}"; do
          tmp_attempt=$((tmp_attempt + 1))
          if [ "$tmp_attempt" -ge 300 ]; then
            echo "timed out waiting for Radeon DRM users to exit" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/sleep 0.1
        done
        ${pkgs.coreutils}/bin/sleep 1

        tmp_handoff_complete=1
        trap - EXIT
        ;;
      release:end)
        restore_host
        ;;
    esac
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
      hooks.qemu.win11-lifecycle = lifecycleHook;
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

  hm.home.file.".local/share/applications/${vmName}.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Windows 11
    Comment=Start the Windows 11 GPU-passthrough virtual machine
    Exec=${pkgs.libvirt}/bin/virsh -c qemu:///system start ${vmName}
    Icon=computer
    Terminal=false
    Categories=System;Emulator;
    StartupNotify=true
  '';

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
