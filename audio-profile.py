#!/usr/bin/env python3
"""Manage portable JSON profiles for the Positivo ES8336 ALSA mixer."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

FORMAT = "positivo-es8336-audio-profile"
SCHEMA_VERSION = 1
CONTROL_LIMITS = {
    "Speaker Switch": ("switch", None),
    "Headphone Switch": ("switch", None),
    "DAC Playback Volume": ("integer", (0, 191)),
    "PGA1.0 1 Master Playback Volume": ("integer", (0, 32)),
    "PGA5.0 5 Master Playback Volume": ("integer", (0, 32)),
    "PGA6.0 6 Master Playback Volume": ("integer", (0, 32)),
    "PGA7.0 7 Master Playback Volume": ("integer", (0, 32)),
}
DEFAULT_PROFILE = Path(__file__).resolve().parent / "profiles" / "es8336-tested.json"
BACKUP_FILE = Path.home() / ".local/state/positivo-es8336-audio-fix/original-mixer.json"


class ProfileError(Exception):
    pass


def run_amixer(card: int, *args: str) -> str:
    try:
        result = subprocess.run(
            ["amixer", "-c", str(card), *args],
            check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ProfileError("amixer não encontrado. Instale o pacote alsa-utils.") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or exc.stdout.strip() or "erro do ALSA"
        raise ProfileError(f"amixer falhou: {detail}") from exc
    return result.stdout


def available_cards() -> list[int]:
    cards_file = Path("/proc/asound/cards")
    if not cards_file.exists():
        raise ProfileError("Não foi possível ler /proc/asound/cards.")
    indices = []
    for line in cards_file.read_text(errors="replace").splitlines():
        match = re.match(r"^\s*(\d+)\s+\[", line)
        if match:
            indices.append(int(match.group(1)))
    if not indices:
        raise ProfileError("Nenhuma placa ALSA foi encontrada.")
    return indices


def controls_for(card: int) -> set[str]:
    output = run_amixer(card, "controls")
    return set(re.findall(r"name='([^']+)'", output))


def detect_card(requested: int | None = None) -> int:
    cards = [requested] if requested is not None else available_cards()
    matches = []
    for card in cards:
        try:
            names = controls_for(card)
        except ProfileError:
            continue
        if set(CONTROL_LIMITS).issubset(names):
            matches.append(card)
    if not matches:
        raise ProfileError("Não encontrei uma placa com todos os controles esperados do ES8336.")
    if len(matches) > 1:
        raise ProfileError(
            "Mais de uma placa corresponde ao perfil. Informe --card com o índice desejado: "
            + ", ".join(map(str, matches))
        )
    return matches[0]


def read_control(card: int, name: str) -> str:
    output = run_amixer(card, "cget", f"name='{name}'")
    match = re.search(r"^\s*: values=(.+)$", output, flags=re.MULTILINE)
    if not match:
        raise ProfileError(f"Não consegui ler o valor do controle: {name}")
    return match.group(1).strip()


def validate_profile(data: Any) -> dict[str, Any]:
    if not isinstance(data, dict) or data.get("format") != FORMAT:
        raise ProfileError("Arquivo não reconhecido como perfil do Fix Audio.")
    if data.get("schema_version") != SCHEMA_VERSION:
        raise ProfileError(f"Versão de perfil não suportada: {data.get('schema_version')!r}")
    controls = data.get("controls")
    if not isinstance(controls, dict) or not controls:
        raise ProfileError("O perfil precisa conter um objeto 'controls'.")
    for name, value in controls.items():
        if name not in CONTROL_LIMITS:
            raise ProfileError(f"Controle não permitido pelo perfil: {name}")
        kind, bounds = CONTROL_LIMITS[name]
        if kind == "switch":
            if str(value).lower() not in ("on", "off", "true", "false", "1", "0"):
                raise ProfileError(f"Valor inválido para {name}: {value!r}")
        else:
            if isinstance(value, bool) or not isinstance(value, int):
                raise ProfileError(f"{name} precisa ter um valor inteiro.")
            low, high = bounds
            if not low <= value <= high:
                raise ProfileError(f"{name} fora do intervalo permitido ({low}–{high}).")
    return data


def load_profile(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ProfileError(f"Perfil não encontrado: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ProfileError(f"JSON inválido em {path}: {exc}") from exc
    return validate_profile(data)


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def apply_controls(card: int, controls: dict[str, Any]) -> None:
    available = controls_for(card)
    missing = [name for name in controls if name not in available]
    if missing:
        raise ProfileError("Controles ausentes nesta placa: " + ", ".join(missing))
    for name, value in controls.items():
        run_amixer(card, "cset", f"name='{name}'", str(value))
        print(f"Aplicado: {name} = {value}")


def command_apply(args: argparse.Namespace) -> None:
    profile = load_profile(Path(args.profile))
    card = detect_card(args.card)
    if not BACKUP_FILE.exists():
        original = {name: read_control(card, name) for name in profile["controls"]}
        write_json(BACKUP_FILE, {
            "format": FORMAT, "schema_version": SCHEMA_VERSION,
            "device": "ES8336", "description": "Estado original salvo antes da primeira aplicação",
            "controls": original,
        })
        print(f"Backup original salvo em: {BACKUP_FILE}")
    else:
        print(f"Backup original preservado em: {BACKUP_FILE}")
    apply_controls(card, profile["controls"])
    print(f"Perfil aplicado na placa ALSA {card}.")


def command_save(args: argparse.Namespace) -> None:
    card = detect_card(args.card)
    controls = {name: read_control(card, name) for name in CONTROL_LIMITS}
    profile = {
        "format": FORMAT, "schema_version": SCHEMA_VERSION,
        "device": "ES8336", "description": "Perfil salvo do estado atual do mixer",
        "controls": controls,
    }
    validate_profile(profile)
    destination = Path(args.output).expanduser()
    write_json(destination, profile)
    print(f"Perfil salvo em: {destination}")


def command_restore(args: argparse.Namespace) -> None:
    if not BACKUP_FILE.exists():
        raise ProfileError(f"Backup original não encontrado: {BACKUP_FILE}")
    backup = load_profile(BACKUP_FILE)
    card = detect_card(args.card)
    apply_controls(card, backup["controls"])
    print(f"Estado original restaurado na placa ALSA {card}.")


def command_list(args: argparse.Namespace) -> None:
    for card in available_cards():
        try:
            names = controls_for(card)
        except ProfileError as exc:
            print(f"Placa {card}: indisponível ({exc})")
            continue
        status = "ES8336 compatível" if set(CONTROL_LIMITS).issubset(names) else "outro dispositivo"
        print(f"Placa ALSA {card}: {status}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Salva, valida, aplica e restaura perfis JSON do mixer ES8336."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    apply_parser = sub.add_parser("apply", help="aplica um perfil JSON")
    apply_parser.add_argument("profile", nargs="?", default=str(DEFAULT_PROFILE))
    apply_parser.add_argument("--card", type=int, help="índice ALSA; detectado automaticamente se omitido")
    apply_parser.set_defaults(func=command_apply)

    save_parser = sub.add_parser("save-current", help="salva o estado atual em um perfil JSON")
    save_parser.add_argument("output", help="caminho do arquivo JSON de saída")
    save_parser.add_argument("--card", type=int, help="índice ALSA; detectado automaticamente se omitido")
    save_parser.set_defaults(func=command_save)

    restore_parser = sub.add_parser("restore", help="restaura o backup anterior à primeira aplicação")
    restore_parser.add_argument("--card", type=int, help="índice ALSA; detectado automaticamente se omitido")
    restore_parser.set_defaults(func=command_restore)

    list_parser = sub.add_parser("list-cards", help="lista placas ALSA e identifica ES8336")
    list_parser.set_defaults(func=command_list)

    args = parser.parse_args()
    try:
        args.func(args)
    except (ProfileError, OSError) as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
