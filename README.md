# Positivo Motion C4128G-15 — ES8336 Audio Fix

A lightweight ALSA mixer workaround for restoring speaker and headphone output on the **Positivo Motion C4128G-15** laptop with the Everest Semiconductor ES8336 audio codec.

> [!IMPORTANT]
> This is a device-specific mixer workaround, not a replacement audio driver or a permanent UCM fix. It was tested on one Positivo Motion C4128G-15. Other hardware revisions and distributions may expose different mixer controls.

## Overview

On the tested laptop, the installed `sof-essx8336` UCM profile attempted to use mixer controls that were not exposed by the hardware. WirePlumber reported that no valid UCM HiFi verb was available, and the generic fallback did not restore audio.

This project applies the mixer settings that restored audio during testing:

| ALSA mixer control | Applied value |
| --- | ---: |
| `Speaker Switch` | `on` |
| `Headphone Switch` | `on` |
| `DAC Playback Volume` | `191` |
| `PGA1.0 1 Master Playback Volume` | `32` |
| `PGA5.0 5 Master Playback Volume` | `32` |
| `PGA6.0 6 Master Playback Volume` | `32` |
| `PGA7.0 7 Master Playback Volume` | `32` |

The DAC control reports a range of `0–191`; this project's default is `191`. A control's maximum is not a guarantee of clean output or safe acoustic volume. Begin with a low system volume, increase carefully, and reduce the level if you hear distortion. Avoid testing at high volume through headphones.

## Requirements

- Positivo Motion C4128G-15 with the ES8336 codec and expected ALSA controls
- Linux with systemd (for persistent mode)
- `bash`, `amixer`, `grep`, and `systemctl`

On Debian/Ubuntu-based distributions (including Zorin OS and Linux Mint):

```bash
sudo apt update
sudo apt install alsa-utils git
```

## Installation

Clone the repository and enter its directory:

```bash
git clone https://github.com/frisk001101100/positivo-es8336-audio-fix..git
cd positivo-es8336-audio-fix.
```

Apply the profile immediately:

```bash
./fix-audio.sh --apply
```

## Persistent mode (recommended)

Install the systemd service:

```bash
sudo ./fix-audio.sh --install
```

The installer:

1. Installs the script under `/usr/local/libexec/positivo-es8336-audio-fix/`.
2. Creates a systemd oneshot service that runs after `sound.target`.
3. Enables the service at boot and starts it immediately.
4. Retries ALSA device detection for up to 30 seconds if the card is not ready yet.

After installation, the mixer profile is automatically reapplied on every boot. No manual command is needed after restarting.

Check the service:

```bash
systemctl status positivo-es8336-audio-fix.service
journalctl -u positivo-es8336-audio-fix.service -b
```

### Configuration

The installer creates `/etc/default/positivo-es8336-audio-fix`:

```bash
sudo nano /etc/default/positivo-es8336-audio-fix
```

Available settings:

```bash
CARD=0
DAC_VOLUME=191
RETRIES=15
RETRY_DELAY=2
```

- `CARD`: ALSA card index (default: `0`).
- `DAC_VOLUME`: integer from `0` to `191` (default: `191`).
- `RETRIES`: number of device-readiness attempts.
- `RETRY_DELAY`: seconds between attempts.

After changing the configuration, restart the service:

```bash
sudo systemctl restart positivo-es8336-audio-fix.service
```

To remove persistent mode completely:

```bash
sudo ./fix-audio.sh --uninstall
```

The uninstaller disables and stops the service, then removes its service file, installed script, and configuration file.

## Manual commands

Apply the profile at any time:

```bash
./fix-audio.sh
# or
./fix-audio.sh --apply
```

Select a different ALSA card for a one-time application:

```bash
CARD=1 ./fix-audio.sh --apply
```

Override the DAC value for a one-time application:

```bash
DAC_VOLUME=184 ./fix-audio.sh --apply
```

Show persistent service status:

```bash
./fix-audio.sh --status
```

## Troubleshooting

### The service fails because an ALSA card cannot be accessed

List the available cards:

```bash
cat /proc/asound/cards
```

If the ES8336 is not card `0`, update `CARD` in `/etc/default/positivo-es8336-audio-fix` and restart the service.

### A mixer control is missing

Inspect the controls exposed by the codec:

```bash
amixer -c 0 controls
```

The script intentionally stops instead of guessing values for a different hardware layout. Check the service log:

```bash
journalctl -u positivo-es8336-audio-fix.service -b --no-pager
```

### Audio settings reset after reboot

Confirm that the service is enabled:

```bash
systemctl is-enabled positivo-es8336-audio-fix.service
systemctl status positivo-es8336-audio-fix.service
```

If the service failed, inspect its boot log with `journalctl` as shown above.

## Validation notes

- Audio was restored on a Positivo Motion C4128G-15 in a Zorin OS Live session.
- Equivalent mixer settings also restored audio on the same laptop in Linux Mint Live.
- The original working values were identified and checked manually with `amixer`.
- Persistent mode uses systemd to reapply the same tested mixer profile; it does not modify the kernel, GRUB, or UCM configuration.

- Audio was also restored in an installed Zorin OS session on the same C4128G-15, with the persistent systemd service enabled and reporting a successful boot-time application.
- Playback was verified through ALSA `speaker-test` using the default output; audible test tone and normal music playback (Weezer) were confirmed.
- A further power-cycle test is still pending; persistence is configured and the service ran successfully at boot, but survival across a subsequent reboot has not yet been independently confirmed.

## Scope

This repository documents a practical workaround for the tested laptop. It does not provide a corrected UCM profile, a kernel patch, or a universal fix for every ES8336 device.

## License

MIT. See [LICENSE](LICENSE).
