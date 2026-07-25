# Docker

En ferdig arbeidsstasjon: `claude` CLI, `fzf`, `whiptail`, `jq`, `git`, `ripgrep` og
menyen — uten å installere noe på verten utover Docker selv.

```bash
cd docker
docker compose run --rm meny          # rett inn i menyen
docker compose run --rm meny bash     # shell, med «claude -meny» tilgjengelig
```

Bruk `run`, ikke `up`: `fzf` og `whiptail` krever TTY.

## Hva som ligger hvor

| | Innhold |
|---|---|
| **I imaget** | Verktøyene og `claude-meny.sh`. ~600 MB. |
| **Montert inn** | Repoene, samtalene, git-identitet. |

Repo og samtaler ligger **ikke** i imaget, og det er ikke en forglemmelse:

- repo-treet er stort og endrer seg konstant — et image med det bakt inn er utdatert
  i samme sekund det bygges
- samtalene er *tilstand*; bakt inn forsvinner de ved hver `docker compose build`
- config-mappa inneholder `.credentials.json` — Claude-innlogginga di. Et image med
  den i er et image som ikke kan deles med noen.

## Sti-paritet er et krav, ikke en preferanse

Container-siden av volumene **må** være `/root/workspace` og `/root/Claude/.claude`.
To grunner:

1. Menyen hopper over enhver samtale der `cwd` fra transkriptet ikke finnes på disk.
2. Claude Code utleder prosjektmappenavnet fra saniterte `cwd` (`/root/workspace/x`
   → `-root-workspace-x`), og `--resume <id>` finner bare sesjonen i mappa som
   matcher gjeldende `cwd`.

Monterer du på f.eks. `/workspace` i stedet, forsvinner hele historikken fra menyen
og nye samtaler skrives til et parallelt sett prosjektmapper. Historikken deler seg
i to — uten én feilmelding.

Host-siden kan derimot flyttes fritt med env-variabler:

```bash
MENY_WORKSPACE=/home/kari/dev MENY_CONFIG=/home/kari/.claude docker compose run --rm meny
```

Merk at samtaler startet i containeren da får `cwd=/root/workspace/...`, som ikke
finnes på verten din. **Velg én modus og bli i den**, eller bruk identiske stier
begge steder (da kan du veksle fritt).

## Innlogging

Config-mappa er montert, så en allerede innlogget vert gir en innlogget container —
tokenet følger med volumet, aldri imaget. Er volumet tomt, kjør `claude login` i
containeren (device-flow, skriver ut en URL) eller sett `ANTHROPIC_API_KEY`.

## Git

`~/.gitconfig` og `~/.git-credentials` monteres **read-only**. Sistnevnte er
klartekst-token — den er din egen fil, pakken leverer ingen legitimasjon. Begge må
finnes på verten før første kjøring; ellers oppretter Docker dem som *mapper*.
Bruker repoene dine SSH-remotes, må du montere `~/.ssh` selv.

## Pinne versjon

`CLAUDE_VERSION` går rett til den offisielle installeren, som tar
`stable|latest|<versjon>`:

```bash
CLAUDE_VERSION=2.1.220 docker compose build     # reproduserbart bygg
```

Default er `stable`, som kan ligge bak `latest` på verten din.

## Bevisste utelatelser

- **Docker-socket monteres ikke.** `/var/run/docker.sock` inn i en container er
  root-ekvivalent på verten. Trenger du container-arbeid *inne* i containeren, legg
  det i en egen override-fil du selv eier.
- **Ingen SSH-nøkler, ingen tailscale.** Containeren er for kodearbeid. Drift av
  andre maskiner — proxmox, CT-er, servere over SSH — gjør du fra verten; å montere
  nøklene inn river ned poenget med isolasjonen.

## Verifisere at det virker

Sammenlign samtalelista i containeren med verten — samme antall, samme stier:

```bash
docker compose run --rm meny bash -lc \
  'ls -t "$CLAUDE_CONFIG_DIR"/projects/*/*.jsonl | wc -l'
```

Start så en samtale i containeren og sjekk at det **ikke** dukket opp en ny mappe i
`$CLAUDE_CONFIG_DIR/projects/` — den skal havne i samme mappe verten bruker for den
stien. Gjør den ikke det, er sti-pariteten brutt.

## VS Code

`.devcontainer/devcontainer.json` peker på samme Dockerfile, så «Reopen in
Container» gir samme oppsett med de samme volumene.
