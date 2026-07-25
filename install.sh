#!/usr/bin/env bash
# Installer «claude -meny»: pakkekrav + source-linje i ~/.bashrc. Idempotent —
# trygg å kjøre flere ganger.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src="$here/claude-meny.sh"
[ -f "$src" ] || { echo "fant ikke $src" >&2; exit 1; }

# --- pakker ---
missing=()
for p in fzf whiptail jq; do command -v "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
    echo "mangler: ${missing[*]}"
    if command -v apt-get >/dev/null 2>&1; then
        # ponytail: kun apt — andre distroer får beskjed, ikke en pakkeleder-abstraksjon
        if [ "$(id -u)" = 0 ]; then apt-get install -y "${missing[@]}"
        else sudo apt-get install -y "${missing[@]}"; fi
    else
        echo "installer disse selv og kjør på nytt: ${missing[*]}" >&2
        exit 1
    fi
fi
command -v claude >/dev/null 2>&1 \
    || echo "advarsel: 'claude' finnes ikke i PATH — se https://claude.ai/install.sh" >&2

# --- bashrc ---
rc="$HOME/.bashrc"
if grep -qF 'claude-meny.sh' "$rc" 2>/dev/null; then
    echo "allerede installert i $rc"
else
    printf '\n# claude -meny (%s)\n[ -f %s ] && source %s\n' "$(date +%F)" "$src" "$src" >> "$rc"
    echo "lagt til i $rc"
fi

cat <<EOF

Ferdig. Åpne nytt shell (eller: source $rc), så er 'claude -meny' tilgjengelig.

Valgfrie innstillinger:
  CLAUDE_MENY_ROOT=/sti/til/repoer   rot for repo-lista (default /root/workspace)
  CLAUDE_MENY_SKIP=mappenavn         hopp over én mappe i repo-lista
  CLAUDE_CONFIG_DIR=/sti/.claude     der Claude Code lagrer samtalene
EOF
