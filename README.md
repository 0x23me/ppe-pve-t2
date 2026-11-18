# Proxmox VE Kernel with T2 Mac Support - APT Repository

Automated build and distribution of Proxmox VE kernels with T2 Mac hardware support.

## What is this?

This repository automatically builds Proxmox VE kernel packages optimized for Apple T2 Mac hardware. The kernels are built from official Proxmox sources with T2 patches applied and made available through an easy-to-use APT repository hosted at apt.0x23.me.

## Quick Installation

### 1. Add GPG signing key

```bash
sudo mkdir -p /usr/share/keyrings
wget -qO /usr/share/keyrings/ppe-pve-t2.asc https://apt.0x23.me/KEY.gpg
```

### 2. Add repository

```bash
echo "deb [signed-by=/usr/share/keyrings/ppe-pve-t2.asc] https://apt.0x23.me trixie main" | \
  sudo tee /etc/apt/sources.list.d/ppe-pve-t2.list
```

### 3. Update package index

```bash
sudo apt update
```

### 4. Install kernel

```bash
# Install the latest 7.3 series T2 kernel and its headers (headers are
# needed for DKMS modules, e.g. out-of-tree NIC drivers)
sudo apt install proxmox-kernel-t2-7.3 proxmox-headers-t2-7.3

# Or stay on the 7.0 series
sudo apt install proxmox-kernel-t2-7.0 proxmox-headers-t2-7.0

# Or install a specific version
sudo apt install proxmox-kernel-7.0.14-26-pve-t2
```

The series metapackages are named with `t2` (`proxmox-kernel-t2-7.0`,
`proxmox-headers-t2-7.0`), so they don't collide with Proxmox's own
`proxmox-kernel-7.0` and both can stay installed; no apt pinning needed.
New T2 kernels then arrive with a normal `apt upgrade`.

Two series are built side by side: 7.0 and 7.3. The repository holds the newest
build of each, so a 7.0 install keeps getting 7.0 updates and doesn't move to 7.3
on its own.

```bash
```

### 5. Reboot

```bash
sudo reboot
```

After reboot, verify the kernel:
```bash
uname -r  # Should show something like 6.17.4-2-pve-t2
```

## Features

- **Automated Builds**: Daily checks for new upstream versions and automatic builds
- **APT Repository**: Easy installation via APT repository hosted at apt.0x23.me
- **T2 Mac Support**: Full hardware support for T2 Macs including:
  - Touch Bar
  - BCE (Buffer Copy Engine)
  - Bluetooth
  - APFS filesystem
- **GitHub Releases**: All builds are also available as GitHub releases

## Available Packages

Check the repository for all available kernel versions:

```bash
apt list 'proxmox-kernel-*'
```

The repository maintains multiple kernel versions, allowing you to install or downgrade to any available version.

## Updating

When new kernel versions are published, update as usual:

```bash
sudo apt update
sudo apt upgrade
```

## Removing

To remove the repository:

```bash
# Remove repository configuration
sudo rm /etc/apt/sources.list.d/ppe-pve-t2.list

# Remove GPG key
sudo rm /usr/share/keyrings/ppe-pve-t2.asc

# Update package cache
sudo apt update
```

## How It Works

This repository uses a three-stage workflow to automatically build and publish kernels:

### 1. Check Upstream (Daily)

- Checks each series ("train") listed in `versions.json`: 7.3 from the tags in
  [proxmox-kernel.git](git://git.proxmox.com/git/proxmox-kernel.git), 7.0 from
  [pve-kernel.git](git://git.proxmox.com/git/pve-kernel.git), where Proxmox kept the kernel up to 7.0
- Monitors [t2linux patches](https://github.com/t2linux/linux-t2-patches) for updates
- Automatically selects appropriate t2linux commit based on kernel version
- Triggers build if new versions are detected

### 2. Build

- Builds kernel in Docker container (debian:trixie)
- Clones pve-kernel source at specific tag
- Applies t2linux hardware support patches
- Applies T2.patch (adds `-t2` suffix and enables T2 configs)
- Compiles kernel packages (~30-60 minutes)
- Uploads artifacts and updates `versions.json`

### 3. Publish

- Downloads build artifacts
- Adds packages to APT repository using `aptly`
- Signs with GPG
- Uploads the APT repository to apt.0x23.me
- Creates GitHub Release with packages

## Version Selection

### PVE Kernel Version

Uses the latest tag from the official Proxmox kernel repository.

### T2 Patches Version

Automatically selects the appropriate t2linux patches commit:

- For kernel 6.17, finds the "6.18" version bump commit and uses its parent
- If no next version bump exists, uses HEAD (latest)
- Can be manually pinned by setting `pinned_t2linux_commit` in `versions.json`

## Compatibility

- **Distribution**: Debian Trixie (Proxmox VE 9 base)
- **Architecture**: amd64 only
- **Hardware**: Optimized for Apple T2 Mac systems

## Manually Triggering Builds

You can manually trigger a build via GitHub Actions:

1. Go to **Actions** → **Build PVE Kernel with T2 Support**
2. Click **Run workflow**
3. Enter:
   - Proxmox kernel release (e.g. `proxmox/7.3.5-1` or `proxmox-kernel-7.0.14-30`)
   - T2Linux commit hash (e.g., `699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9`)

## Pinning T2 Patches Version

To use a specific t2linux commit instead of auto-detection:

1. Edit `versions.json`
2. Set `"pinned_t2linux_commit": "COMMIT_HASH"` under the series in `trains`
3. Commit and push

7.3 is pinned to t2linux `dd9b845`: newer t2linux commits rework the SMC drivers and
don't apply to Proxmox's 7.3 yet.

## Adding a Series

Add it to `trains` in `versions.json` with `"last_build": null`. The next daily
check builds and publishes it. A new series may need rebased t2linux patches in
`patches/t2-overrides/<series>/`.

To unpin: Set to `null`

## Repository Structure

```
ppe-pve-t2/
├── .github/workflows/      # GitHub Actions workflows
│   ├── check-upstream.yml  # Daily version check
│   ├── build.yml           # Kernel build
│   └── publish.yml         # APT publish
├── patches/
│   └── T2.patch            # Build system modifications
├── scripts/
│   ├── check-versions.sh   # Version comparison
│   ├── find-t2-commit.sh   # Auto-detect t2linux commit
│   ├── build-kernel.sh     # Docker build script
│   └── publish-repo.sh     # APT publish script
├── docs/                   # APT repository, built by publish (not committed)
│   ├── pool/main/          # .deb packages
│   ├── dists/trixie/       # Repository metadata
│   └── KEY.gpg             # Public GPG key
├── versions.json           # Version tracking
└── README.md              # This file
```

## Technical Details

### APT Repository Structure

```
https://apt.0x23.me/
├── pool/main/              # Package pool
├── dists/trixie/           # Distribution metadata
│   ├── Release             # Repository metadata
│   ├── InRelease          # GPG-signed metadata
│   └── main/binary-amd64/ # Architecture-specific packages
└── KEY.gpg                 # Public GPG signing key
```

### GPG Key Fingerprint

```
47BEEF6A0CC800F7EB4A19C4C4F60CABCD494490
```

Verify the key fingerprint after importing:
```bash
gpg --show-keys /usr/share/keyrings/ppe-pve-t2.asc
```

## Credits

This repository builds upon work from:

- [fabianishere/pve-edge-kernel](https://github.com/fabianishere/pve-edge-kernel) - Build system inspiration
- [AdityaGarg8/pve-edge-kernel-t2](https://github.com/AdityaGarg8/pve-edge-kernel-t2) - Original T2 patches integration
- [Proxmox](https://git.proxmox.com/) - Base kernel source
- [t2linux](https://github.com/t2linux/linux-t2-patches) - T2 Mac hardware support patches

## Support

For issues related to:
- **Build system/repository**: Open an issue in this repository
- **Kernel functionality**: Report to [t2linux](https://github.com/t2linux/linux-t2-patches/issues)
- **Proxmox kernel**: See [Proxmox forums](https://forum.proxmox.com/)

## License

This repository's automation and build scripts are released under MIT License.

The Proxmox kernel and t2linux patches retain their original licenses.

## Contributing

Contributions to the repository infrastructure are welcome. Please open an issue or pull request.
