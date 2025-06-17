## You’re right—those steps were outdated. Here’s the **correct, up-to-date process** for enabling touchscreen on a Surface Book 3 with Linux Mint:

---

## ✅ 1. Add the linux-surface repository properly

Mint’s default repos no longer include `add-repo.sh`. Instead, use the official instructions:

```bash
# Install required tools
sudo apt update && sudo apt install curl gnupg

# Add Microsoft GPG key and surface repo
curl -sSL https://raw.githubusercontent.com/linux-surface/linux-surface/main/pkg/keys/surface.asc | sudo gpg --dearmor -o /usr/share/keyrings/linux-surface.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/linux-surface.gpg] https://pkg.surfacelinux.com/debian release main" |
  sudo tee /etc/apt/sources.list.d/linux-surface.list

# Update package list
sudo apt update
```

This replaces the old script with direct repository configuration.

---

## ✅ 2. Install the kernel and essential packages

```bash
sudo apt install linux-image-surface linux-headers-surface iptsd libwacom-surface
```

* **`linux-image-surface`**: custom kernel with Surface-specific patches, including touch support
* **`iptsd`**: Intel Precise Touch & Stylus daemon (necessary for touchscreen)
* **`libwacom-surface`**: Wacom driver support for pen/touch ⁠([forums.linuxmint.com][1], [github.com][2], [reddit.com][3], [itsfoss.community][4])

---

## ✅ 3. Reboot and verify touchscreen

1. Reboot your Surface Book 3.
2. Run `xinput list` to check if touchscreen shows up.
3. Touch the screen—multi-touch should now work.

---

## ⚠️ Troubleshooting Tips

* Make sure **iptsd** is running:

  ```bash
  systemctl status iptsd
  ```

  If it’s not active, start it with:

  ```bash
  sudo systemctl enable --now iptsd
  ```

* If touchscreen still doesn’t respond:

  * Update your BIOS/firmware to the latest version.
  * Ensure secure boot is disabled or enroll the Surface signing key when installing the new kernel.

---

### 🎯 Why it works now

The `linux-surface` project provides a tailored kernel and user-space services that support the Surface’s proprietary touchscreen and pen input—which aren’t supported by default in the regular Linux Mint kernel ([itsfoss.community][4]).

---

Let me know once you’ve tried these steps—happy to help with `iptsd` logs or other tweaks if needed!

[1]: https://forums.linuxmint.com/viewtopic.php?t=374636&utm_source=chatgpt.com "Touchscreen, pen, camera not working-SurfaceBook"
[2]: https://github.com/linux-surface/linux-surface?utm_source=chatgpt.com "linux-surface/linux-surface: Linux Kernel for Surface Devices - GitHub"
[3]: https://www.reddit.com/r/SurfaceLinux/comments/eixoic/guide_installing_linux_on_surface_devices/?utm_source=chatgpt.com "r/SurfaceLinux on Reddit: [GUIDE] Installing Linux on Surface Devices"
[4]: https://itsfoss.community/t/surface-pro-touchscreen-doesn-t-work-on-linux-mint-22-x/12247?utm_source=chatgpt.com "Surface Pro touchscreen doesn't work on Linux Mint 22.x"
