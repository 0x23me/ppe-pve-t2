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
