# protonord-sw-claudemeny

`claude -meny` — en whiptail-basert launcher for Claude Code: velg kjøremodus,
modell, kategori og repo, og start Claude Code i riktig mappe.

## Installering

`.bashrc` sourcer funksjonen fra der repoet er klonet:

```bash
[ -f /sti/til/protonord-sw-claudemeny/claude-meny.sh ] \
  && source /sti/til/protonord-sw-claudemeny/claude-meny.sh
```

Åpne nytt shell (eller `source ~/.bashrc`), så er `claude -meny` tilgjengelig.
`claude <args>` uten `-meny` går rett til vanlig Claude Code (funksjonen wrapper
`command claude`).

## Bruk — fem steg

1. **Modus** — Normal / Auto-rediger (`--permission-mode acceptEdits`) /
   Full agent (`--allowedTools …`) / Plan (`--permission-mode plan`).
2. **Modell** — Standard (config-default) / Opus 4.8 / Sonnet 5 / Haiku 4.5 (`--model …`).
3. **Kategori** — avledet av mappenivået under workspace-roten, sortert etter
   sist jobbet.
4. **Repo** — repo i valgt kategori, sortert etter sist jobbet (git last-commit-tid).
   «(nåværende mappe)» i steg 3 hopper over dette steget.
5. **Historikk** — viser chat-historikken for valgt mappe (inntil 8 samtaler,
   nyeste øverst) med tidsstempel og tekstutsnitt (summary-linje eller første
   brukermelding fra transkriptet). Velg en samtale (`--resume <session-id>`)
   eller «Ny samtale». Ingen historikk → beskjed, så ny samtale.
   Transkripter leses fra `$CLAUDE_CONFIG_DIR/projects/<mappe-sti med tegn
   utenfor [A-Za-z0-9-] byttet til «-»>/*.jsonl`.

## Krav

- `whiptail` (newt)
- `claude` CLI i PATH
- `jq` (tekstutsnitt i historikk-steget)
- git-repoer under `/root/workspace/<kategori>/<repo>` (maxdepth 2)

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
