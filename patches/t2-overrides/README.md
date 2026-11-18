# t2linux patch overrides

Rebased versions of t2linux patches that don't apply to Proxmox's kernel source
(Proxmox builds on Ubuntu's kernel tree, which carries backports that t2linux,
targeting mainline, doesn't expect).

`build-kernel.sh` copies `patches/t2-overrides/<major.minor>/*.patch` over the
t2linux patches with the same file name, for the matching kernel series only.

## 7.0 (pve-kernel 7.0.14-26, Ubuntu-7.0.0-43.43i1, t2linux 7ee7d19 / KVER=7.0.4)

- `2008-i915-4-lane-quirk-for-mbp15-1.patch`: i915 quirk list gained new entries
  (QUIRK_DISABLE_PSR2 etc.); quirk appended at the new end of the enum/table.
- `3001-applesmc-convert-static-structures-to-drvdata.patch`: upstream already
  added the destroy_workqueue() error path to applesmc_create_key_backlight().
- `4001-asahi-trackpad.patch`: upstream now has its own magicmouse_reset_resume()
  for USB Magic Mice; the SPI re-enable is added to it instead of defining a
  second function.

All 98 patches (Proxmox + t2linux with these overrides) were verified to apply
in order to the ubuntu-kernel submodule of pve-kernel 7.0.14-26.

When t2linux moves on or Proxmox bumps the Ubuntu base, re-check these: an
override silently replaces whatever t2linux ships under the same name.

## 7.3 (proxmox-kernel proxmox/7.3.5-1, mainline v7.3.5 + Proxmox's debian/patches, t2linux dd9b845 / KVER=7.3)

From 7.3 on, Proxmox builds the kernel from proxmox-kernel.git (see
`scripts/build-proxmox-kernel.sh`). The t2linux patches are appended to Proxmox's
quilt series and applied with fuzz 0, so a patch that only applies with fuzz or a
three-way merge needs an override.

- `2008-i915-4-lane-quirk-for-mbp15-1.patch`: the quirk enum gained
  QUIRK_ENABLE_DPCD_BACKLIGHT; the new quirk goes after it.
- `3008-treewide-Add-a-flag-to-detect-the-Apple-T2-chip.patch`: Proxmox carries
  Ubuntu's patch loading MOKx certs in load_uefi.c, which moves the context of the
  T2 cert-skip hunk; three-way merged, same change.
- `skip`: patches whose change is already in the kernel (9005, brcmfmac RX DMA
  direction, backported to 7.3.5).

All 34 remaining patches were verified to apply in order with `patch -F 0` on top
of Proxmox's 25 patches. t2linux commits after dd9b845 (the SMC rework of
2026-11-17/18) don't apply to 7.3.5 yet, not even to the plain mainline tag.
