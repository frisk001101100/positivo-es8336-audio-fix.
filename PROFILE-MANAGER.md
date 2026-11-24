# Perfis JSON do Fix Audio

O gerenciador `audio-profile.py` adiciona perfis próprios em JSON ao workaround ALSA do ES8336. Esses arquivos são lidos pelo Fix Audio; não são arquivos de configuração nativos do ALSA nem presets do applet de som do Cinnamon.

## Requisitos

- Linux com ALSA e o codec/controlos ES8336 esperados pelo perfil
- Python 3
- `alsa-utils` (comando `amixer`)

## Uso

Na raiz do repositório:

```bash
# Identificar as placas ALSA e localizar a que tem os controles ES8336
python3 audio-profile.py list-cards

# Aplicar o perfil validado (detecta a placa automaticamente)
python3 audio-profile.py apply

# Salvar o mixer atual em um novo perfil
python3 audio-profile.py save-current meu-perfil.json

# Aplicar outro perfil salvo
python3 audio-profile.py apply meu-perfil.json

# Restaurar o estado salvo antes da primeira aplicação
python3 audio-profile.py restore
```

Se houver mais de uma placa compatível, informe o índice exibido por `list-cards`, por exemplo `--card 1`.

## Segurança e comportamento

- Antes da primeira aplicação, salva os valores atuais em `~/.local/state/positivo-es8336-audio-fix/original-mixer.json`.
- Não substitui esse backup nas aplicações seguintes, para que ele continue representando o estado anterior ao Fix Audio.
- `restore` reaplica esse backup.
- Valida nomes de controles e limites conhecidos antes de enviar valores ao ALSA.
- Não usa `sudo` automaticamente, não altera UCM, kernel, GRUB, PipeWire ou arquivos globais do ALSA.
- Os perfis JSON são dados do próprio projeto. O script não executa comandos encontrados dentro deles.

O perfil incluído em `profiles/es8336-tested.json` mantém os valores que já foram documentados como funcionais neste notebook. O DAC em 191 é o limite superior reportado pelo controle; comece com o volume geral baixo e aumente com cuidado.
