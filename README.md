# Positivo ES8336 Audio Fix

A small, manual ALSA mixer workaround for the ES8336 audio codec found in the Positivo Motion C4128G-15.

> **Status:** tested successfully in a Zorin OS Live session on one Positivo Motion C4128G-15. The same laptop also had working audio in Linux Mint Live after applying equivalent mixer settings. This is a device-specific workaround, not a universal ES8336 driver or a confirmed permanent fix.

## The symptom

On this laptop, the installed `sof-essx8336` UCM profile attempts to use mixer controls that are not exposed by the hardware, including `DAC Mono Mix Switch`, `Headphone Mixer`, `Differential Mux`, and `Digital Mic Mux`. WirePlumber logs reported that no UCM HiFi verb was valid, and audio did not work with the generic fallback profile.

The workaround applies these mixer settings:

- Speaker Switch: on
- Headphone Switch: on
- DAC Playback Volume: 184 by default (seven steps below the reported maximum of 191)
- PGA master playback controls: 32 (their reported maximum)

The ES8336 reports a DAC Playback Volume range of 0–191. The default 184 is an experimental higher setting, not a verified safe or distortion-free level for every speaker. Start with a low system volume and stop increasing playback if you hear distortion or other unusual speaker behavior.

## Usage

1. Download `fix-audio.sh`.
2. Open a terminal in the downloaded folder.
3. Run:

```bash
chmod +x fix-audio.sh
./fix-audio.sh
```

To choose a different DAC value, set `DAC_VOLUME` (valid range: 0–191):

```bash
DAC_VOLUME=184 ./fix-audio.sh
```

The script only changes ALSA mixer values for the current session. It does not install packages, modify UCM files, change the kernel, or configure automatic startup. Mixer settings may reset after reboot.

If your audio card is not card 0, specify its ALSA card index:

```bash
CARD=1 ./fix-audio.sh
```

## Safety and compatibility

- Start with a low system volume before testing.
- The value 184 is seven steps below the codec control's reported maximum, but that margin does not guarantee that the laptop speakers can handle the resulting output without distortion.
- The script checks that each named control exists and validates the DAC value before changing mixer values.
- It is intended for the tested Positivo Motion C4128G-15 / ES8336 setup. Other Positivo Motion variants may expose different controls.
- No guarantee is made for other distributions, kernel versions, or hardware revisions.
- If any control is missing, the script stops and reports it rather than guessing.

## Technical notes

The original working values were first discovered and validated manually with ALSA `amixer` on Linux Mint Live and Zorin OS Live. The Zorin test used the ES8336 / `sof-essx8336` card. The higher default DAC setting is based on the codec's reported mixer range; it is an adjustment to test, not a claim that the speaker hardware can safely or cleanly reproduce that output.

This repository documents the known working mixer workaround. It does not yet provide a permanent UCM profile correction.

## License

MIT
