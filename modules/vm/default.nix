{
  pkgs,
  vars,
  ...
}:
{
  # The Ryzen 7 7700 iGPU (0000:12:00.0) drives the NixOS desktop. Bind the
  # discrete Radeon and its HDMI/DP audio function to VFIO before amdgpu can
  # claim them; this avoids an unsafe live single-GPU detach/rebind cycle.
  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "vfio-pci.ids=1002:73bf,1002:ab28"
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
    };
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

  # After rebuilding and rebooting, verify with:
  #   lspci -nnk -s 03:00.0 -s 03:00.1
  # Both functions must report `Kernel driver in use: vfio-pci`. The host
  # desktop must remain usable on the motherboard DisplayPort (the iGPU) before
  # defining or starting modules/vm/win11.xml.
}
