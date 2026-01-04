# Proxmox VE Kernel with T2 Mac Support - APT Repository

Automated build and distribution of Proxmox VE kernels with T2 Mac hardware support.

## What is this?

This repository automatically builds Proxmox VE kernel packages optimized for Apple T2 Mac hardware. The kernels are built from official Proxmox sources with T2 patches applied and made available through an easy-to-use APT repository hosted on GitHub Pages.

## Quick Installation

### 1. Add GPG signing key

```bash
sudo mkdir -p /usr/share/keyrings
wget -qO /usr/share/keyrings/ppe-pve-t2.gpg https://0x23me.github.io/ppe-pve-t2/KEY.gpg
```

### 2. Add repository

```bash
echo "deb [signed-by=/usr/share/keyrings/ppe-pve-t2.gpg] https://0x23me.github.io/ppe-pve-t2 trixie main" | \
  sudo tee /etc/apt/sources.list.d/ppe-pve-t2.list
```

### 3. Update package index

```bash
sudo apt update
```

### 4. Install kernel

```bash
# Install latest 6.17 series kernel
sudo apt install proxmox-kernel-6.17

# Or install specific version
sudo apt install proxmox-kernel-6.17.4-2-pve-t2

# Or install headers
sudo apt install proxmox-headers-6.17
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
- **APT Repository**: Easy installation via APT repository hosted on GitHub Pages
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
sudo rm /usr/share/keyrings/ppe-pve-t2.gpg

# Update package cache
sudo apt update
```

## How It Works

This repository uses a three-stage workflow to automatically build and publish kernels:

### 1. Check Upstream (Daily)

- Monitors [Proxmox kernel repository](git://git.proxmox.com/git/pve-kernel.git) for new tags
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
- Publishes to GitHub Pages
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
   - PVE kernel tag (e.g., `pve-kernel-6.17.4-2`)
   - T2Linux commit hash (e.g., `699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9`)

## Pinning T2 Patches Version

To use a specific t2linux commit instead of auto-detection:

1. Edit `versions.json`
2. Set `"pinned_t2linux_commit": "COMMIT_HASH"`
3. Commit and push

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
├── docs/                   # GitHub Pages (APT repository)
│   ├── pool/main/          # .deb packages
│   ├── dists/trixie/       # Repository metadata
│   └── KEY.gpg             # Public GPG key
├── versions.json           # Version tracking
└── README.md              # This file
```

## Technical Details

### APT Repository Structure

```
https://0x23me.github.io/ppe-pve-t2/
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
gpg --show-keys /usr/share/keyrings/ppe-pve-t2.gpg
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
