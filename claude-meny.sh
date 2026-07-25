# Forhåndsvisning for fzf: mappe, dato og slutten av samtalen (der du slapp)
_clprev() {
    [[ -f "$1" ]] || { echo "Start en ny samtale — velg mappe i neste steg."; return; }
    local cwd; cwd=$(head -n 40 "$1" | jq -r '.cwd // empty' 2>/dev/null | head -1)
    printf '%s\n%s\n' "${cwd:-?}" "$(date -d "@$(stat -c %Y "$1")" +'%d.%m.%Y %H:%M')"
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    jq -r 'select(.type=="user" or .type=="assistant")
        | (if .type=="user" then "● DU" else "○ CLAUDE" end) as $who
        | (if (.message.content|type)=="string" then .message.content
           else ([.message.content[]? | select(.type=="text") | .text] | join("\n")) end) as $txt
        | select(($txt|length)>0)
        | select(($txt|startswith("<"))|not)
        | select(($txt|startswith("Caveat:"))|not)
        | "\n" + $who + ":\n" + $txt' "$1" 2>/dev/null | tail -n 80
}
export -f _clprev

claude() {
    if [[ "$1" != "-meny" ]]; then
        command claude "$@"
        return
    fi

    export NEWT_COLORS='
root=lightgray,black
border=brightcyan,black
window=lightgray,black
shadow=black,black
title=brightcyan,black
button=black,cyan
actbutton=black,brightcyan
listbox=lightgray,black
actlistbox=black,cyan
sellistbox=black,brightcyan
textbox=lightgray,black
acttextbox=black,cyan
entry=white,black
helpline=brightblue,black
roottext=brightblue,black
'

    # Debug kun hvis CLAUDE_MENY_DEBUG=1
    local _dbg=/dev/null
    if [[ "$CLAUDE_MENY_DEBUG" == "1" ]]; then
        _dbg=/tmp/claude-meny-debug.txt
        echo "START $(date)" > "$_dbg"
    fi

    # alder-hjelper
    local now; now=$(date +%s)
    _clage() {
        local diff=$(( now - $1 ))
        if   [[ $diff -lt 3600   ]]; then printf "< 1t"
        elif [[ $diff -lt 86400  ]]; then printf "i dag"
        elif [[ $diff -lt 172800 ]]; then printf "i går"
        elif [[ $diff -lt 604800 ]]; then printf "%dd siden" $((diff/86400))
        else date -d "@$1" +"%d.%m.%y" 2>/dev/null || printf "?"
        fi
    }

    # --- Steg 1: siste samtaler på hele serveren, fzf med forhåndsvisning ---
    # Mappen hentes fra cwd-feltet i transkriptet, ikke fra prosjekt-mappenavnet
    # (sanitert sti er ikke reverserbar).
    if ! command -v fzf >/dev/null 2>&1; then
        whiptail --title "Claude Code" --msgbox "Trenger fzf: apt-get install fzf" 8 50
        return
    fi
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    # Rot for repo-lista — overstyr med CLAUDE_MENY_ROOT på andre oppsett
    local root="${CLAUDE_MENY_ROOT:-/root/workspace}"
    local -a lines=("➕ Ny samtale (velg mappe)"$'\t'"NY"$'\t'"-")
    local -A _seen=()
    local f sid hts cwd hi=0
    # ponytail: de 50 nyeste, ikke alt — én jq per fil, alt ville blitt tregt
    while IFS= read -r f && [[ $hi -lt 50 ]]; do
        cwd=$(head -n 40 "$f" 2>/dev/null | jq -r '.cwd // empty' 2>/dev/null | head -1)
        [[ -z "$cwd" || ! -d "$cwd" ]] && continue
        sid=${f##*/}; sid=${sid%.jsonl}
        # samme sesjon kan ligge i flere prosjektmapper (cwd endret underveis)
        [[ -n "${_seen[$sid]}" ]] && continue
        _seen[$sid]=1
        hts=$(stat -c %Y "$f" 2>/dev/null || echo 0)
        hi=$((hi+1))
        # venstre kolonne: dato + hele mappestien. Samtaleteksten står i preview.
        lines+=("$(printf '%s │ %s' "$(date -d "@$hts" +'%d.%m.%y %H:%M')" "$cwd")"$'\t'"$f"$'\t'"$cwd")
    done < <(ls -t "$cfg"/projects/*/*.jsonl 2>/dev/null)
    echo "samtaler: $hi" >> "$_dbg"

    local mappe resume_sid="" valg vfile vcwd
    if [[ $hi -gt 0 ]]; then
        valg=$(printf '%s\n' "${lines[@]}" | fzf \
            --delimiter=$'\t' --with-nth=1 --no-sort --layout=reverse \
            --prompt="Søk > " \
            --header="Enter: velg · Esc: avbryt · Ctrl-U/D: bla i forhåndsvisning" \
            --preview '_clprev {2}' --preview-window=right:50%:wrap \
            --bind 'ctrl-u:preview-page-up,ctrl-d:preview-page-down' \
            --color=16,border:14,prompt:14,pointer:14,hl:14,hl+:14,bg+:6,fg+:0,header:4,info:4)
        [[ -z "$valg" ]] && return
        IFS=$'\t' read -r _ vfile vcwd <<<"$valg"
    else
        vfile="NY"
    fi

    if [[ "$vfile" == "NY" ]]; then
        # --- Samle git-repos som "ts|kategori|path" ---
        local -a rows=() find_args=("$root" -mindepth 1 -maxdepth 2 -type d -not -name '.*')
        # CLAUDE_MENY_SKIP: én mappe å hoppe over (f.eks. et stort produktarkiv)
        [[ -n "${CLAUDE_MENY_SKIP:-}" ]] && find_args+=(-not -path "*/$CLAUDE_MENY_SKIP/*")
        local line
        while IFS= read -r line; do rows+=("$line"); done < <(
            find "${find_args[@]}" 2>/dev/null | while IFS= read -r d; do
                [ -d "$d/.git" ] || continue
                rel=${d#"$root"/}
                if [[ "$rel" == */* ]]; then kat=${rel%%/*}; else kat="andre"; fi
                ts=$(git -C "$d" log -1 --format="%ct" 2>/dev/null)
                [ -z "$ts" ] && ts=$(stat -c %Y "$d" 2>/dev/null || echo 0)
                printf '%s|%s|%s\n' "$ts" "$kat" "$d"
            done
        )
        echo "repos: ${#rows[@]}" >> "$_dbg"

        # --- Kategori (nyeste aktivitet øverst) ---
        local -a cat_menu=("." "(nåværende mappe)")
        local cts cname
        while IFS='|' read -r cts cname; do
            [ -z "$cname" ] && continue
            cat_menu+=("$cname" "sist jobbet: $(_clage "$cts")")
        done < <(printf '%s\n' "${rows[@]}" | awk -F'|' '$2!=""{ if($1>mx[$2]) mx[$2]=$1 } END{ for(c in mx) print mx[c]"|"c }' | sort -rn)

        local kategori
        kategori=$(whiptail \
            --title "Claude Code - kategori" \
            --menu "Velg kategori:" \
            20 60 10 \
            -- "${cat_menu[@]}" \
            3>&1 1>&2 2>&3)
        [[ -z "$kategori" ]] && return

        if [[ "$kategori" == "." ]]; then
            mappe=$PWD
        else
            # --- Repo i valgt kategori (sist jobbet øverst) ---
            local -a repo_menu=()
            local rts rkat rpath name
            while IFS='|' read -r rts rkat rpath; do
                [ -z "$rpath" ] && continue
                name=${rpath#"$root"/}
                repo_menu+=("$name" "$(_clage "$rts")")
            done < <(printf '%s\n' "${rows[@]}" | awk -F'|' -v c="$kategori" '$2==c' | sort -rn)

            local n_items=$(( ${#repo_menu[@]} / 2 ))
            local list_h=$(( n_items < 14 ? n_items : 14 )); [ "$list_h" -lt 1 ] && list_h=1

            local valgt
            valgt=$(whiptail \
                --title "Claude Code - $kategori" \
                --menu $'Sortert etter sist jobbet (nyeste øverst).\nPil opp/ned + Enter.' \
                22 72 "$list_h" \
                -- "${repo_menu[@]}" \
                3>&1 1>&2 2>&3)
            [[ -z "$valgt" ]] && return
            mappe="$root/$valgt"
        fi
    else
        mappe=$vcwd
        resume_sid=${vfile##*/}; resume_sid=${resume_sid%.jsonl}
    fi

    # --- Steg 2: kjøremodus ---
    local modus
    modus=$(whiptail \
        --title "Claude Code - ${mappe#"$root"/}" \
        --menu "Velg kjøremodus:" \
        14 50 4 \
        -- \
        "1"  "Normal" \
        "2"  "Auto-rediger" \
        "3"  "Full agent" \
        "4"  "Planmodus" \
        3>&1 1>&2 2>&3)
    [[ -z "$modus" ]] && return

    local -a mode_args=()
    case $modus in
        2)  mode_args+=(--permission-mode acceptEdits) ;;
        3)  mode_args+=(--allowedTools "Edit Write MultiEdit Bash WebFetch WebSearch NotebookEdit") ;;
        4)  mode_args+=(--permission-mode plan) ;;
    esac

    # --- Steg 3: modell ---
    # Aliaser, ikke versjonsnumre: --model opus/fable/sonnet/haiku peker alltid på
    # nyeste i familien, så menyen blir ikke utdatert ved nye modeller.
    local modell
    modell=$(whiptail \
        --title "Claude Code - modell" \
        --menu "Velg modell (aliasene gir alltid nyeste versjon):" \
        16 60 5 \
        -- \
        "o" "Opus     - nyeste Opus (standardvalg)" \
        "f" "Fable    - kraftigst" \
        "s" "Sonnet   - rask og god" \
        "h" "Haiku    - raskest og billigst" \
        "d" "Uten --model (det CLI/config selv velger)" \
        3>&1 1>&2 2>&3)
    [[ -z "$modell" ]] && return
    case $modell in
        o) mode_args+=(--model opus) ;;
        f) mode_args+=(--model fable) ;;
        s) mode_args+=(--model sonnet) ;;
        h) mode_args+=(--model haiku) ;;
    esac

    [[ -n "$resume_sid" ]] && mode_args+=(--resume "$resume_sid")
    cd "$mappe" && command claude "${mode_args[@]}"
}
