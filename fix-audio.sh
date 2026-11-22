#!/usr/bin/env bash
#
# Positivo Motion C4128G-15 — ES8336 audio workaround
# https://github.com/frisk001101100/positivo-es8336-audio-fix.
#
# Applies the validated ALSA mixer profile and can install a persistent
# systemd service to reapply it at every boot.

set -Eeuo pipefail

readonly SERVICE_NAME="positivo-es8336-audio-fix.service"
readonly INSTALL_DIR="/usr/local/libexec/positivo-es8336-audio-fix"
readonly INSTALLED_SCRIPT="$INSTALL_DIR/fix-audio.sh"
readonly SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
readonly CONFIG_FILE="/etc/default/positivo-es8336-audio-fix"

CARD="${CARD:-0}"
DAC_VOLUME="${DAC_VOLUME:-191}"
readonly RETRIES="${RETRIES:-15}"
readonly RETRY_DELAY="${RETRY_DELAY:-2}"

log() { printf '[audio-fix] %s\n' "$*"; }
error() { printf '[audio-fix] Error: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Positivo Motion ES8336 Audio Fix

Usage:
  ./fix-audio.sh [--apply]
  sudo ./fix-audio.sh --install
  sudo ./fix-audio.sh --uninstall
  ./fix-audio.sh --status
  ./fix-audio.sh --help

Commands:
  --apply       Apply the mixer profile now (default).
  --install     Install and enable the persistent systemd service.
  --uninstall   Stop the service and remove installed service files.
  --status      Show the systemd service status.
  --help        Show this help.

Configuration:
  CARD=0          ALSA card index (default: 0).
  DAC_VOLUME=191  DAC volume, integer from 0 to 191 (default: 191).
USAGE
}

validate_config() {
  if [[ ! "$CARD" =~ ^[0-9]+$ ]]; then
    error "CARD must be a non-negative integer."
    return 1
  fi
  if [[ ! "$DAC_VOLUME" =~ ^[0-9]+$ ]] || (( DAC_VOLUME < 0 || DAC_VOLUME > 191 )); then
    error "DAC_VOLUME must be an integer between 0 and 191."
    return 1
  fi
  if [[ ! "$RETRIES" =~ ^[1-9][0-9]*$ ]] || [[ ! "$RETRY_DELAY" =~ ^[1-9][0-9]*$ ]]; then
    error "RETRIES and RETRY_DELAY must be positive integers."
    return 1
  fi
}

require_root() {
  if (( EUID != 0 )); then
    error "This command requires administrator privileges. Run it with sudo."
    exit 1
  fi
}

get_controls() {
  amixer -c "$CARD" controls 2>/dev/null
}

has_required_controls() {
  local controls="$1"
  local name
  for name in \
    "Speaker Switch" \
    "Headphone Switch" \
    "DAC Playback Volume" \
    "PGA1.0 1 Master Playback Volume" \
    "PGA5.0 5 Master Playback Volume" \
    "PGA6.0 6 Master Playback Volume" \
    "PGA7.0 7 Master Playback Volume"; do
    if ! grep -Fq "name='$name'" <<<"$controls"; then
      return 1
    fi
  done
}

set_control() {
  local name="$1"
  local value="$2"
  log "Setting $name = $value"
  amixer -c "$CARD" cset "name='$name'" "$value" >/dev/null
}

apply_profile() {
  local attempt controls
  command -v amixer >/dev/null 2>&1 || {
    error "amixer was not found. Install it with: sudo apt install alsa-utils"
    return 1
  }

  for ((attempt = 1; attempt <= RETRIES; attempt++)); do
    if amixer -c "$CARD" info >/dev/null 2>&1; then
      controls="$(get_controls || true)"
      if has_required_controls "$controls"; then
        break
      fi
    fi
    if (( attempt == RETRIES )); then
      error "ES8336 controls were not ready or were not found on ALSA card $CARD."
      error "Check the card with: cat /proc/asound/cards"
      return 1
    fi
    log "Waiting for ALSA card $CARD (attempt $attempt/$RETRIES)..."
    sleep "$RETRY_DELAY"
  done

  log "Applying ES8336 mixer profile to ALSA card $CARD..."
  set_control "Speaker Switch" on
  set_control "Headphone Switch" on
  set_control "DAC Playback Volume" "$DAC_VOLUME"
  set_control "PGA1.0 1 Master Playback Volume" 32
  set_control "PGA5.0 5 Master Playback Volume" 32
  set_control "PGA6.0 6 Master Playback Volume" 32
  set_control "PGA7.0 7 Master Playback Volume" 32

  log "Profile applied. DAC Playback Volume: $DAC_VOLUME (range: 0–191)."
  log "Start with a low system volume and increase carefully."
}

install_service() {
  require_root
  command -v systemctl >/dev/null 2>&1 || {
    error "systemd/systemctl is required for persistent mode."
    exit 1
  }
  command -v amixer >/dev/null 2>&1 || {
    error "Install ALSA utilities first: sudo apt install alsa-utils"
    exit 1
  }

  local source
  source="$(readlink -f "$0")"
  mkdir -p "$INSTALL_DIR" /etc/default
  install -m 0755 "$source" "$INSTALLED_SCRIPT"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cat >"$CONFIG_FILE" <<'CONFIG'
# ALSA card index and validated ES8336 mixer profile.
CARD=0
DAC_VOLUME=191
RETRIES=15
RETRY_DELAY=2
CONFIG
    chmod 0644 "$CONFIG_FILE"
  fi

  cat >"$SERVICE_FILE" <<'UNIT'
[Unit]
Description=Persistent ES8336 audio mixer settings for Positivo Motion
Documentation=https://github.com/frisk001101100/positivo-es8336-audio-fix.
After=sound.target
Wants=sound.target

[Service]
Type=oneshot
EnvironmentFile=-/etc/default/positivo-es8336-audio-fix
ExecStart=/usr/local/libexec/positivo-es8336-audio-fix/fix-audio.sh --apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
  chmod 0644 "$SERVICE_FILE"

  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME"
  log "Persistent service installed and enabled."
  log "Settings will be reapplied during boot."
  log "Configuration: $CONFIG_FILE"
  log "Check status with: systemctl status $SERVICE_NAME"
}

uninstall_service() {
  require_root
  command -v systemctl >/dev/null 2>&1 || {
    error "systemctl was not found; cannot safely manage the service."
    exit 1
  }

  systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$CONFIG_FILE"
  rm -f "$INSTALLED_SCRIPT"
  rmdir "$INSTALL_DIR" 2>/dev/null || true
  systemctl daemon-reload
  systemctl reset-failed "$SERVICE_NAME" >/dev/null 2>&1 || true
  log "Persistent service and its configuration have been removed."
}

show_status() {
  if ! command -v systemctl >/dev/null 2>&1; then
    error "systemctl was not found."
    exit 1
  fi
  systemctl status "$SERVICE_NAME" --no-pager
}

main() {
  local command="${1:---apply}"
  case "$command" in
    --apply)
      validate_config
      apply_profile
      ;;
    --install)
      validate_config
      install_service
      ;;
    --uninstall)
      uninstall_service
      ;;
    --status)
      show_status
      ;;
    --help|-h)
      usage
      ;;
    *)
      error "Unknown command: $command"
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
