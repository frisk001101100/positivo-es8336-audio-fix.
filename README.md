# Positivo Motion C4128G-15 — ES8336 Audio Fix

A lightweight ALSA mixer workaround for restoring speaker and headphone output on the **Positivo Motion C4128G-15** laptop with the Everest Semiconductor ES8336 audio codec.

> [!IMPORTANT]
> This is a device-specific mixer workaround, not a replacement audio driver or a permanent UCM fix. It was tested on one Positivo Motion C4128G-15. Other hardware revisions and distributions may expose different mixer controls.

## Overview

On the tested laptop, the installed `sof-essx8336` UCM profile attempted to use mixer controls that were not exposed by the hardware. WirePlumber reported that no valid UCM HiFi verb was available, and the generic fallback did not restore audio.

This script applies the mixer settings that restored audio during testing:

| ALSA mixer control | Applied value |
| --- | ---: |
| `Speaker Switch` | `on` |
| `Headphone Switch` | `on` |
| `DAC Playback Volume` | `191` (default) |
| `PGA1.0 1 Master Playback Volume` | `32` |
| `PGA5.0 5 Master Playback Volume` | `32` |
| `PGA6.0 6 Master Playback Volume` | `32` |
| `PGA7.0 7 Master Playback Volume` | `32` |

The DAC control reports a range of `0–191`. The default is set to `191`, the requested upper limit. **A control's maximum is not a guarantee of clean output or safe acoustic volume.** Begin with a low system volume, increase carefully, and reduce the level if you hear distortion. Avoid testing at high volume through headphones.

## Requirements

- Positivo Motion C4128G-15 with the ES8336 codec and the expected ALSA controls
- Linux with ALSA utilities
- `bash`, `amixer`, and `grep`

On Debian/Ubuntu-based distributions (including Zorin OS):

```bash
sudo apt update
sudo apt install alsa-utils
```

## Quick start

Download and run the script:

```bash
curl -fL "https://raw.githubusercontent.com/frisk001101100/positivo-es8336-audio-fix./main/fix-audio.sh" -o fix-audio.sh
chmod +x fix-audio.sh
./fix-audio.sh
```

The script checks that all required controls exist before changing any mixer value. It stops with an error if the expected hardware controls are missing.

## Configuration

The default DAC value is `191`. You can override it for a single run with `DAC_VOLUME`:

```bash
DAC_VOLUME=184 ./fix-audio.sh
```

Valid values are integers from `0` to `191`.

If the audio device is not ALSA card `0`, select another card index with `CARD`:

```bash
CARD=1 ./fix-audio.sh
```

Both options can be combined:

```bash
CARD=1 DAC_VOLUME=184 ./fix-audio.sh
```

## Troubleshooting

### The script says that an ALSA card cannot be accessed

List the available cards:

```bash
cat /proc/asound/cards
```

Then rerun the script with the correct index, for example `CARD=1 ./fix-audio.sh`.

### A mixer control is missing

Inspect the controls exposed by the codec:

```bash
amixer -c 0 controls
```

The script intentionally stops instead of guessing values for a different hardware layout.

### Audio settings reset after reboot

That is expected. This workaround changes runtime ALSA mixer values only. It does not install a service, configure automatic startup, modify UCM files, change the kernel, or make the settings persistent.

## Validation notes

- Audio was restored on a Positivo Motion C4128G-15 in a Zorin OS Live session.
- Equivalent mixer settings also restored audio on the same laptop in Linux Mint Live.
- The original working values were identified and checked manually with `amixer`.
- The higher default DAC setting uses the control's reported upper limit; it is not a claim that every speaker or headphone can handle that output without distortion.

## Scope

This repository documents a practical workaround for the tested laptop. It does not currently provide a corrected UCM profile, a kernel patch, or a universal fix for every ES8336 device.

## License

MIT. See [LICENSE](LICENSE).
