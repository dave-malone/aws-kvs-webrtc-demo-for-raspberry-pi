# Raspberry Pi Setup Guide

This guide covers how to prepare a Raspberry Pi for use with the KVS WebRTC demo. It reflects the current state of Raspberry Pi OS (Bookworm and Trixie) as of 2026, including the move to NetworkManager and cloud-init.

## Supported configurations

| Pi Model | OS | Status |
|---|---|---|
| Raspberry Pi 4 Model B | Raspbian Bookworm (12), armhf | Tested, working |
| Raspberry Pi Zero 2 W | Raspbian Trixie (13), armhf | Tested, working |
| Any Pi | arm64 (64-bit OS) | Untested |

## Flashing the SD card

Use the [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (v2.0+) to flash the SD card.

1. Select your Pi model
2. Choose **Raspberry Pi OS (32-bit)** — the latest available (Bookworm or Trixie)
3. In the customization settings, configure:
   - Hostname
   - Username and password
   - WiFi SSID and password
   - Enable SSH
   - Your SSH public key (optional but recommended)
4. Flash the card

## Important: WiFi may not connect on first boot

Despite configuring WiFi in the Imager, **headless WiFi setup is unreliable** on current Raspberry Pi OS versions. This is a known issue across Bookworm and Trixie related to the transition from `wpa_supplicant` to NetworkManager and cloud-init.

If your Pi doesn't appear on the network after 3-4 minutes:

### Option A: Connect a monitor and keyboard

1. Connect a mini-HDMI monitor and USB keyboard to the Pi
2. Log in with the username/password you set in the Imager
3. Configure WiFi manually:
   ```bash
   sudo nmtui
   ```
   Select "Activate a connection", choose your network, enter the password.

4. Enable SSH and passwordless sudo for remote management:
   ```bash
   sudo systemctl enable ssh
   sudo systemctl start ssh
   sudo sh -c 'echo "YOUR_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/010_nopasswd'
   ```

5. Get the IP address:
   ```bash
   hostname -I
   ```

6. Disconnect the monitor/keyboard and switch to SSH from your laptop.

### Option B: USB gadget mode (Pi Zero 2 W only)

On Trixie images (2025-10-20+), the `rpi-usb-gadget` package is included. If you enabled "USB Gadget Mode" in the Imager:

1. Connect the Pi's **USB port** (not PWR) to your Mac/PC
2. Wait 2-3 minutes for first boot
3. Try: `ssh your-user@your-hostname.local` or `ssh your-user@10.12.194.1`

If this doesn't work, fall back to Option A. USB gadget mode requires the `rpi-usb-gadget` package to be properly initialized by cloud-init, which depends on the same first-boot process that may have failed for WiFi.

### Option C: Ethernet (if available)

If your Pi has an Ethernet port (Pi 4, Pi 3B+), connect it directly to your router with an Ethernet cable. It will get a DHCP address automatically. Check your router's DHCP leases for the Pi's IP.

## After connecting

Once you can SSH to the Pi, verify everything is working:

```bash
# Check OS version
cat /etc/os-release | head -4

# Check WiFi is connected
nmcli device status

# Check camera (if attached)
rpicam-hello --list-cameras

# Ensure SSH persists across reboots
sudo systemctl enable ssh
```

## NetworkManager basics

Raspberry Pi OS Bookworm and Trixie use NetworkManager instead of the older `dhcpcd` + `wpa_supplicant` stack. Key commands:

```bash
# Show all network interfaces and their status
nmcli device status

# List available WiFi networks
nmcli device wifi list

# Connect to a WiFi network
sudo nmcli device wifi connect "SSID" password "PASSWORD"

# Interactive terminal UI (easiest for WiFi setup)
sudo nmtui

# Show saved connections
nmcli connection show

# Delete a saved connection
sudo nmcli connection delete "connection-name"
```

## What changed from Bullseye

| Feature | Bullseye (Debian 11) | Bookworm (Debian 12) | Trixie (Debian 13) |
|---|---|---|---|
| Network manager | dhcpcd + wpa_supplicant | NetworkManager | NetworkManager + Netplan |
| Headless WiFi | `wpa_supplicant.conf` on boot | Unreliable (cloud-init) | Unreliable (cloud-init) |
| SSH enable | `touch /boot/ssh` | `touch /boot/ssh` (sometimes works) | cloud-init `enable_ssh: true` |
| Camera stack | `raspistill`, V4L2 | libcamera | libcamera |
| First-boot config | `firstrun.sh` | `firstrun.sh` | cloud-init |
| USB gadget | Manual (`dwc2` + `g_ether`) | Manual (`dwc2` + `g_ether`) | `rpi-usb-gadget` package |

## Preparing for the KVS WebRTC demo

Once your Pi is on the network and accessible via SSH, you're ready to run the provisioning script from your laptop:

```bash
./provision-local.sh \
  --profile your-aws-profile \
  --pi-host your-user@your-pi-ip \
  --thing-name your-thing-name
```

This handles everything else: installing build dependencies, compiling the SDK, setting up IoT credentials, and starting the streaming service.

## Known issues

### WiFi doesn't connect after Imager configuration

This is the most common issue. The Imager writes cloud-init configuration to the boot partition, but cloud-init's WiFi provisioning is unreliable on first boot. The workaround is to use `nmtui` with a monitor and keyboard attached.

### `raspi-config` WiFi setup doesn't work

On Bookworm and Trixie, `raspi-config`'s WiFi configuration may not apply correctly because it still targets the old `wpa_supplicant` system. Use `nmtui` or `nmcli` instead.

### Camera not detected

If `rpicam-hello --list-cameras` shows no cameras:
1. Check the ribbon cable connection
2. Verify `camera_auto_detect=1` is in `/boot/firmware/config.txt`
3. Reboot after any config changes

### SSH "Permission denied" after flashing

If the Imager's user/password configuration didn't apply:
1. Connect a monitor and keyboard
2. The default user may not exist — check with `cat /etc/passwd | grep 1000`
3. If no user exists, cloud-init failed. Create one manually:
   ```bash
   sudo adduser your-username
   sudo usermod -aG sudo your-username
   ```
