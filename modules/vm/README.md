# Windows Radeon passthrough

`default.nix` configures the NixOS host and the experimental live GPU handoff.
`win11.xml` is the persistent libvirt domain definition for the `win11` guest.

> [!WARNING]
> The live Radeon handoff is experimental. It deliberately stops the NixOS
> graphical session and terminates every process with the Radeon DRM nodes open
> before libvirt binds the GPU to VFIO. Keep SSH, Tailscale, or another recovery
> path available. Do **not** start this VM with `virsh start`; use
> `sudo systemctl start win11-start`.

## Hardware findings

| Device | PCI address / group | Conclusion |
| --- | --- | --- |
| Radeon GPU | `0000:03:00.0`, group 14 | Used by NixOS with `amdgpu` while Windows is off; dynamically bound to `vfio-pci` while Windows runs. |
| Radeon audio | `0000:03:00.1`, group 15 | Moves with the Radeon to Windows. |
| Ryzen iGPU | `0000:12:00.0`, group 29 | Keep enabled in firmware as a recovery/headless fallback. It does not need a monitor for the normal live-switch workflow. |
| USB controller | `0000:12:00.3`, group 31 | Safe Windows-only controller; no host devices were present during discovery. |
| USB controller | `0000:12:00.4`, group 32 | Safe Windows controller for the Rift and anything plugged into its physical ports. |
| USB controller | `0000:10:00.0`, group 27 with bridge `0000:06:0c.0` | Passed successfully as an endpoint while the bridge remains host-owned; its physical ports are Windows-only while the VM runs. |
| USB controller | `0000:13:00.0`, group 34 | Detaching/resetting it caused a host reset; excluded from the guest. |
| Realtek Ethernet | `0000:0e:00.0`, group 25 | Not currently passed. Windows uses the virtual e1000e NAT adapter. |
| MediaTek Wi-Fi | `0000:0f:00.0`, group 26 | Not passed; NixOS retains Wi-Fi and remote recovery. |

## GPU switching model

NixOS uses Radeon outputs `DP-1` and `DP-2` while Windows is off. Starting
`win11-start` stops the display manager, DMS, niri, EasyEffects, and any other
Radeon DRM users. It waits for the DRM nodes to be clear, then libvirt assigns
the Radeon to Windows. Windows uses those same physical Radeon outputs.

When Windows shuts down, libvirt reattaches the Radeon to `amdgpu`. Its QEMU
`release:end` hook starts the display manager, waits for niri's Wayland socket,
and starts DMS again. The user session is intentionally replaced; GPU-using
applications such as Discord may be killed during the handoff.

This avoids the original unsafe approach, which tried to detach the active GPU
while niri/Mesa still held it open and caused host resets.

## Starting and stopping

The VM must be shut down before redefining its XML. The `<uuid>` in
`win11.xml` is intentionally stable; do not use `virsh undefine --nvram` for
normal updates because it replaces the virtual TPM identity.

Apply NixOS changes and update libvirt hooks:

```sh
sudo nixos-rebuild switch --flake .#orange
sudo systemctl restart libvirtd-config.service
```

Update the stopped domain after editing XML:

```sh
sudo virsh -c qemu:///system define modules/vm/win11.xml
```

Start Windows only through the handoff service:

```sh
sudo systemctl start win11-start
```

Shut Windows down normally. Do not force it off unless recovery requires it.
The display manager should return automatically. If niri returns with only a
gray background, start DMS manually:

```sh
systemctl --user reset-failed dms.service
systemctl --user start dms.service
```

## USB policy

Controller passthrough is used for `12:00.3`, `12:00.4`, and `10:00.0`.
Their physical ports are Windows-only while the VM runs. The `10:00.0`
controller is an AMD 600-series chipset USB 3.2 endpoint in IOMMU group 27,
which also contains bridge `06:0c.0`.

Libvirt rejects the bridge itself as a non-endpoint hostdev, but successfully
assigns `10:00.0` while leaving `06:0c.0` bound to `pcieport`. Windows then
gets the controller and its physical ports, including USB devices connected
after Windows has started. This is preferable to individual USB hostdev
entries, which were unreliable for the Logitech receiver, MediaTek Bluetooth,
and Cosmos devices.

The controller uses a bus-level reset. Do not manually unbind `06:0c.0`:
that made startup unstable in testing. If controller release causes a host
failure on a future kernel, use the recovery path and reboot rather than
attempting to assign the bridge. A dedicated PCIe USB controller in its own
IOMMU group remains the cleaner long-term design.

### Bluetooth

The MediaTek Bluetooth USB device is `0e8d:0616`. If it is ever attached to
Windows, Windows may need the matching MediaTek Bluetooth driver from MSI or
Windows Update; its absence from Device Manager can be a guest-driver issue,
not only a libvirt matching issue.

## Guest devices

- 24 GiB RAM, 12 vCPUs (6 cores × 2 threads)
- UEFI/Q35, TPM 2.0, Hyper-V enlightenments
- 200 GiB sparse QCOW2 disk at `/var/lib/libvirt/images/win11.qcow2`
- Windows ISO at
  `/home/pebble/Documents/en-us_windows_11_consumer_editions_version_26h2_x64_dvd_af326c9d.iso`
- e1000e NAT networking through libvirt's `default` network
- No QXL/SPICE video device: it previously became the Windows primary virtual
  monitor and hid the physical Radeon login screen.

Create the disk once if it does not exist:

```sh
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11.qcow2 200G
```

The QCOW2 file is sparse: its guest-visible capacity is 200 GiB, while host
storage grows as Windows writes data. Expand it only while the VM is off:

```sh
sudo qemu-img resize /var/lib/libvirt/images/win11.qcow2 +100G
```

Then extend the partition in Windows Disk Management.

After installation, eject the Windows installer ISO:

```sh
sudo virsh -c qemu:///system change-media win11 sdb --eject --config
```
