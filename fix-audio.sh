#!/usr/bin/env bash
set -Eeuo pipefail

CARD="${CARD:-0}"

if ! command -v amixer >/dev/null 2>&1; then
  echo "Erro: amixer não encontrado. Ele faz parte do pacote alsa-utils." >&2
  exit 1
fi

if ! amixer -c "$CARD" info >/dev/null 2>&1; then
  echo "Erro: não consegui acessar a placa ALSA $CARD." >&2
  echo "Veja as placas disponíveis com: cat /proc/asound/cards" >&2
  exit 1
fi

controls="$(amixer -c "$CARD" controls)"

require_control() {
  local name="$1"
  if ! grep -Fq "name='$name'" <<<"$controls"; then
    echo "Controle ausente: $name" >&2
    echo "Nenhuma alteração adicional será tentada." >&2
    exit 1
  fi
}

set_control() {
  local name="$1"
  local value="$2"
  require_control "$name"
  echo "Aplicando: $name = $value"
  amixer -c "$CARD" cset "name='$name'" "$value"
}

# Validate all expected controls before changing any mixer value.
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

echo "Aplicando workaround ES8336 na placa ALSA $CARD..."
set_control "Speaker Switch" on
set_control "Headphone Switch" on
set_control "DAC Playback Volume" 151
set_control "PGA1.0 1 Master Playback Volume" 32
set_control "PGA5.0 5 Master Playback Volume" 32
set_control "PGA6.0 6 Master Playback Volume" 32
set_control "PGA7.0 7 Master Playback Volume" 32

echo
echo "Concluído. Teste o áudio com volume baixo."
echo "As alterações são temporárias e podem ser perdidas após reiniciar."
