# Windows GPU passthrough

> [!IMPORTANT]
> This is a two-GPU configuration. The Ryzen 7 7700 iGPU at `0000:12:00.0`
> drives NixOS through the motherboard DisplayPort (`DP-4`); the discrete Radeon
> is reserved for Windows. This replaces the unsafe live single-GPU handoff,
> which reset the host and must not be reintroduced.

`default.nix` configures the NixOS host. `win11.xml` is the persistent libvirt
domain definition for the `win11` guest.

The checked-in `win11.xml` is a **GPU-only staging configuration**. Windows
owns the discrete Radeon while NixOS retains its iGPU desktop, all USB
controllers, Bluetooth, wired Ethernet, and local input. The earlier attempt
to hand all USB controllers to Windows reset the host before QEMU started, so
those devices must not be re-added until the GPU-only VM has booted and shut
down reliably.

Do **not** enable autostart for this domain.

## Host configuration

The NixOS module enables AMD IOMMU, loads the VFIO modules from the initrd, and
binds the Radeon GPU (`1002:73bf`) plus its audio function (`1002:ab28`) to
`vfio-pci` at boot. It also configures libvirt, virt-manager, QEMU/KVM, OVMF
firmware discovery, TPM emulation, and the default NAT network prerequisites.

There is intentionally no GPU lifecycle hook. NixOS never claims the discrete
Radeon, so starting and stopping Windows does not stop the display manager or
tear down the NixOS graphical session.

Apply host changes and reboot before using the VM:

```sh
sudo nixos-rebuild switch --flake .#orange
sudo reboot
```

After boot, verify that IOMMU was enabled:

```sh
cat /proc/cmdline
# Expected to include: amd_iommu=on iommu=pt
```

## Devices transferred to Windows

All addresses below were detected on this host. Each device is isolated in its
own IOMMU group, so libvirt can manage it with `managed='yes'`.

| Device           | PCI address    | IOMMU group | Effect while `win11` runs                                                                                     |
| ---------------- | -------------- | ----------: | ------------------------------------------------------------------------------------------------------------- |
| Ryzen iGPU       | `0000:12:00.0` |          29 | NixOS host GPU; motherboard DisplayPort / `DP-4`.                                                             |
| AMD GPU          | `0000:03:00.0` |          14 | Bound to VFIO at boot; Windows owns its physical display output.                                              |
| AMD GPU audio    | `0000:03:00.1` |          15 | Windows owns HDMI/DisplayPort audio.                                                                          |
| USB controller   | `0000:10:00.0` |          27 | Windows owns the Bluetooth adapter, Logitech keyboard/mouse receiver, USB audio, hubs, and connected sensors. |
| USB controller   | `0000:12:00.3` |          31 | Reserved for Windows USB ports.                                                                               |
| USB controller   | `0000:12:00.4` |          32 | Windows owns the Rift headset, Rift audio, and Rift sensors.                                                  |
| USB controller   | `0000:13:00.0` |          34 | Reserved for Windows USB ports.                                                                               |
| Realtek Ethernet | `0000:0e:00.0` |          25 | Windows owns `enp14s0`; NixOS loses wired networking.                                                         |

The MediaTek Wi-Fi device (`0000:0f:00.0`, `wlp15s0`, IOMMU group 26) is **not**
passed through. NixOS keeps Wi-Fi while the VM runs, so the existing virtual
network adapter can provide a recovery connection for Windows.

## Create and import the VM

The XML expects a sparse QCOW2 disk at
`/var/lib/libvirt/images/win11.qcow2` and the Windows installer ISO at:

```text
/home/pebble/Documents/en-us_windows_11_consumer_editions_version_26h2_x64_dvd_af326c9d.iso
```

Create the 200 GiB virtual disk once:

```sh
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11.qcow2 200G
```

QCOW2 is sparse: it has 200 GiB of guest-visible capacity but consumes host
disk space only as Windows writes to it.

Enable libvirt's default NAT network once. The XML retains an e1000e adapter
for Windows installation and recovery; it uses the NixOS Wi-Fi connection and
does not require a Windows VirtIO driver.

```sh
sudo virsh -c qemu:///system net-autostart default
sudo virsh -c qemu:///system net-start default
```

If `net-start` reports that the network is already active, no action is needed.

Import or update the persistent VM definition while the VM is shut down:

```sh
sudo virsh -c qemu:///system define modules/vm/win11.xml
sudo virsh -c qemu:///system list --all
```

`virt-manager` will show the imported VM as `win11`. If virt-manager edits the
hardware, preserve this repository XML separately and re-run `virsh define`
when you want the checked-in definition to be authoritative.

## Starting, installing, and stopping

Start from an SSH session or a host virtual terminal rather than relying on the
host graphical desktop, because the start hook stops it:

```sh
sudo virsh -c qemu:///system start win11
```

The monitor connected to the passed-through AMD GPU should show Windows Setup.
After startup, the passed-through keyboard/mouse and Bluetooth belong to
Windows, not NixOS. Keep a recovery method available for the first boot, such
as SSH from another machine or physical power/reset access.

The virtual disk is SATA and the virtual recovery NIC is e1000e, which lets
Windows Setup see storage and networking without a separate VirtIO driver ISO.
Install the AMD Windows GPU driver after Windows is installed.

After installation, eject the installer ISO so subsequent boots use the Windows
disk directly:

```sh
sudo virsh -c qemu:///system change-media win11 sdb --eject --config
```

Shut down Windows normally. Do not force it off unless recovery requires it;
a normal shutdown gives the guest time to release devices. Once it has stopped,
libvirt returns all PCI devices to NixOS and the host display manager starts.

## Expanding the Windows disk

Shut down the VM first, then extend the QCOW2 virtual capacity:

```sh
sudo qemu-img resize /var/lib/libvirt/images/win11.qcow2 +100G
```

Then boot Windows and use **Disk Management** to extend the C: partition. The
example changes the virtual capacity from 200 GiB to 300 GiB.
