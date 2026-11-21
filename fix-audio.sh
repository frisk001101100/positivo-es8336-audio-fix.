#!/usr/bin/env bash
#
# Positivo Motion C4128G-15 — ES8336 audio workaround
# https://github.com/frisk001101100/positivo-es8336-audio-fix.
#
# Applies the ALSA mixer values validated on this laptop.
# Changes are runtime-only and may reset after reboot.

set -Eeuo pipefail

CARD="${CARD:-0}"
# The ES8336 control reports a range of 0–191. The repository's tested
# high-output profile uses the reported upper limit; this is not a
# guarantee that every speaker/headphone can reproduce it cleanly.
DAC_VOLUME="${DAC_VOLUME:-191}"

if [[ ! "$DAC_VOLUME" =~ ^[0-9]+$ ]] || (( DAC_VOLUME < 0 || DAC_VOLUME > 191 )); then
  echo "Error: DAC_VOLUME must be an integer between 0 and 191." >&2
  exit 1
fi

if ! command -v amixer >/dev/null 2>&1; then
  echo "Error: amixer was not found. Install it with: sudo apt install alsa-utils" >&2
  exit 1
fi

if ! amixer -c "$CARD" info >/dev/null 2>&1; then
  echo "Error: unable to access ALSA card $CARD." >&2
  echo "Available cards: cat /proc/asound/cards" >&2
  exit 1
fi

controls="$(amixer -c "$CARD" controls)"

require_control() {
  local name="$1"
  if ! grep -Fq "name='$name'" <<<"$controls"; then
    echo "Error: required mixer control not found: $name" >&2
    echo "No mixer changes have been applied." >&2
    exit 1
  fi
}

set_control() {
  local name="$1"
  local value="$2"
  echo "Setting $name = $value"
  amixer -c "$CARD" cset "name='$name'" "$value"
}

# Validate every required control before changing any mixer value.
for name in \
  "Speaker Switch" \
  "Headphone Switch" \
  "DAC Playback Volume" \
  "PGA1.0 1 Master Playback Volume" \
  "PGA5.0 5 Master Playback Volume" \
  "PGA6.0 6 Master Playback Volume" \
  "PGA7.0 7 Master Playback Volume"; do
  require_control "$name"
done

echo "Applying ES8336 mixer profile to ALSA card $CARD..."
set_control "Speaker Switch" on
set_control "Headphone Switch" on
set_control "DAC Playback Volume" "$DAC_VOLUME"
set_control "PGA1.0 1 Master Playback Volume" 32
set_control "PGA5.0 5 Master Playback Volume" 32
set_control "PGA6.0 6 Master Playback Volume" 32
set_control "PGA7.0 7 Master Playback Volume" 32

echo
echo "Done. DAC Playback Volume is set to $DAC_VOLUME (reported range: 0–191)."
echo "Start playback at a low system volume and check for distortion."
echo "Mixer changes are temporary and may be lost after reboot."
