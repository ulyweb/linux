The primary reason the touchscreen on your Microsoft Surface Book 3 isn't working with Manjaro is that the device's specialized hardware often requires **custom kernel modules and drivers**. The default Manjaro kernel, while robust, doesn't always include the specific patches and drivers needed to fully support the unique hardware found in Surface devices. This is a common issue for many Linux distributions on Surface hardware.

-----

### Solution: Installing the `linux-surface` Kernel

To fix this, you need to install and use a custom kernel specifically patched for Surface devices, often referred to as the `linux-surface` kernel. This kernel includes the necessary drivers for the touchscreen, pen, and other unique Surface features.

#### Step 1: Install the `linux-surface` Repository Key

First, you need to add the repository that hosts the `linux-surface` kernel to your Manjaro system. This involves importing the repository's public key to ensure the packages you download are legitimate.

1.  Open a terminal.
2.  Run the following command to import the key:
    ```bash
    sudo pacman-key --recv-keys 56A6966C22709405F41F5E68C6A526118D685C92
    sudo pacman-key --init
    sudo pacman-key --populate
    ```
    This ensures that you can trust the packages you're about to install.

#### Step 2: Add the `linux-surface` Repository

Next, add the `linux-surface` repository to your `pacman` configuration.

1.  Open the `pacman` configuration file in a text editor with root privileges:

    ```bash
    sudo nano /etc/pacman.conf
    ```

2.  Add the following lines to the end of the file:

    ```
    [linux-surface]
    Server = https://pkg.surfacelinux.com/arch/
    ```

3.  Save the file and exit the text editor.

#### Step 3: Install the Custom Kernel and Drivers

Now you can install the `linux-surface` kernel and the required packages.

1.  Update your system's package list:

    ```bash
    sudo pacman -Syyu
    ```

2.  Install the `linux-surface` kernel, headers, and the input drivers. The specific package names may vary slightly, but a common approach is to install the latest `linux-surface` package along with `iptsd` for input drivers.

    ```bash
    sudo pacman -S linux-surface linux-surface-headers iptsd
    ```

    You may be prompted to select a specific version or dependency. Follow the on-screen instructions.

#### Step 4: Reboot Your System

After the installation is complete, reboot your Surface Book 3.

```bash
sudo reboot
```

Upon rebooting, your system should automatically load the new `linux-surface` kernel. The touchscreen and pen input should now be working correctly. If you still encounter issues, you may need to check the official `linux-surface` project page for more specific instructions for your device model.

-----

This video provides an overview of setting up Manjaro on a laptop with a touchscreen, which can be a helpful visual guide for general steps.

[Setting up Manjaro in a Laptop (Touch Screen)](https://www.youtube.com/watch?v=iY2Hcm0Pcjo)
http://googleusercontent.com/youtube_content/0
