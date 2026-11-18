# Positivo ES8336 Audio Fix

A small, manual ALSA mixer workaround for the ES8336 audio codec found in the Positivo Motion C4128G-15.

> **Status:** tested successfully in a Zorin OS Live session on one Positivo Motion C4128G-15. The same laptop also had working audio in Linux Mint Live after applying equivalent mixer settings. This is a device-specific workaround, not a universal ES8336 driver or a confirmed permanent fix.

## The symptom

On this laptop, the installed `sof-essx8336` UCM profile attempts to use mixer controls that are not exposed by the hardware, including `DAC Mono Mix Switch`, `Headphone Mixer`, `Differential Mux`, and `Digital Mic Mux`. WirePlumber logs reported that no UCM HiFi verb was valid, and audio did not work with the generic fallback profile.

The following mixer settings restored speaker audio during the Live session:

- Speaker Switch: on
- Headphone Switch: on
- DAC Playback Volume: 151
- PGA master playback controls: 32

## Usage

1. Download `fix-audio.sh`.
2. Open a terminal in the downloaded folder.
3. Run:

```bash
chmod +x fix-audio.sh
./fix-audio.sh
```

The script only changes ALSA mixer values for the current session. It does not install packages, modify UCM files, change the kernel, or configure automatic startup. Mixer settings may reset after reboot.

If your audio card is not card 0, specify its ALSA card index:

```bash
CARD=1 ./fix-audio.sh
```

## Safety and compatibility

- Start with a low system volume before testing.
- The script checks that each named control exists before changing it.
- It is intended for the tested Positivo Motion C4128G-15 / ES8336 setup. Other Positivo Motion variants may expose different controls.
- No guarantee is made for other distributions, kernel versions, or hardware revisions.
- If any control is missing, the script stops and reports it rather than guessing.

## Technical notes

The working values were first discovered and validated manually with ALSA `amixer` on Linux Mint Live and Zorin OS Live. The Zorin test used the ES8336 / `sof-essx8336` card.

This repository documents the known working mixer workaround. It does not yet provide a permanent UCM profile correction.

## License

MIT
