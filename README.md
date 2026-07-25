# protonord-sw-claudemeny

`claude -meny` — en whiptail-basert launcher for Claude Code: velg kjøremodus,
modell, kategori og repo, og start Claude Code i riktig mappe.

## Installering

```bash
git clone https://github.com/IBICO74/protonord-sw-claudemeny.git
cd protonord-sw-claudemeny && ./install.sh
```

`install.sh` installerer `fzf`, `whiptail` og `jq` (apt) og legger source-linja i
`~/.bashrc`. Den er idempotent — trygg å kjøre flere ganger. Vil du gjøre det manuelt:

```bash
[ -f /sti/til/protonord-sw-claudemeny/claude-meny.sh ] \
  && source /sti/til/protonord-sw-claudemeny/claude-meny.sh
```

Åpne nytt shell (eller `source ~/.bashrc`), så er `claude -meny` tilgjengelig.
`claude <args>` uten `-meny` går rett til vanlig Claude Code (funksjonen wrapper
`command claude`).

### Docker

Vil du ikke installere noe på verten utover Docker:

```bash
cd docker && docker compose run --rm meny
```

Imaget inneholder verktøyene og menyen; repoene og samtalene monteres inn. Se
[docs/DOCKER.md](docs/DOCKER.md) — særlig avsnittet om sti-paritet, som må stemme
for at historikken skal virke.

### Innstillinger

| Variabel | Default | Hva den gjør |
|---|---|---|
| `CLAUDE_MENY_ROOT` | `/root/workspace` | Rot for repo-lista (`<rot>/<kategori>/<repo>`) |
| `CLAUDE_MENY_SKIP` | *(tom)* | Hopp over én mappe i repo-lista, f.eks. et stort arkiv |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | Der Claude Code lagrer samtalene |

## Bruk

1. **Samtaler** — de 50 nyeste samtalene på tvers av hele serveren (fzf,
   nyeste øverst). Venstre kolonne viser dato og **hele mappestien** — ingen
   samtaletekst, så stien aldri kuttes. Panelet til høyre viser samtalen live
   mens du flytter markøren (Outlook-stil); skriv for å søke, Ctrl-U/D blar i
   forhåndsvisningen. Velg en samtale (`--resume <session-id>`) eller «Ny
   samtale (velg mappe)». Mappen hentes fra `cwd`-feltet i transkriptet;
   transkripter leses fra `$CLAUDE_CONFIG_DIR/projects/*/*.jsonl`.
2. **Kategori + repo** — kun ved ny samtale: kategori (mappenivå under
   workspace-roten) → repo, begge sortert etter sist jobbet (git
   last-commit-tid). «(nåværende mappe)» hopper over repo-steget.
3. **Modus** — Normal / Auto-rediger (`--permission-mode acceptEdits`) /
   Full agent (`--allowedTools …`) / Plan (`--permission-mode plan`).
4. **Modell** — Opus / Fable / Sonnet / Haiku, eller uten `--model`. Menyen sender
   **aliaser** (`--model opus`), ikke versjonsnumre, så valget følger alltid nyeste
   modell i familien uten at skriptet må oppdateres. Siste valg («uten `--model`»)
   overlater modellen til CLI-ens eget standardvalg, som kan ligge en generasjon bak.

Deretter `cd` til valgt mappe og Claude starter (med `--resume` hvis en
eksisterende samtale ble valgt).

## Krav

- `fzf` (samtalelisten med forhåndsvisning)
- `whiptail` (newt) — modus/modell/repo-stegene
- `claude` CLI i PATH
- `jq` (tekstutsnitt og forhåndsvisning)
- git-repoer under `$CLAUDE_MENY_ROOT/<kategori>/<repo>` (maxdepth 2)

## Tema

Night Owl-inspirert `NEWT_COLORS` (mørk `#011627`-bakgrunn, cyan/blå aksenter).
whiptail støtter bare **navngitte ANSI-farger** — de rendres i terminalens palett,
så sett Termius til Night Owl for riktig look. Juster `NEWT_COLORS` i `claude-meny.sh`.

## GitHub-speil

GitHub-utgaven er et automatisk push-speil — endringer skjer i kilderepoet,
ikke via PR/push til GitHub.

## Debug

`CLAUDE_MENY_DEBUG=1 claude -meny` → skriver til `/tmp/claude-meny-debug.txt`
(av som standard).
