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

    # --- Steg 1: kjøremodus (fortsett/ny velges per repo i steg 5) ---
    local modus
    modus=$(whiptail \
        --title "Claude Code" \
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

    # --- Steg 2: modell ---
    local modell
    modell=$(whiptail \
        --title "Claude Code - modell" \
        --menu "Velg modell  (standard: config-default):" \
        16 54 6 \
        -- \
        "d" "Standard (config-default)" \
        "o" "Opus 4.8" \
        "s" "Sonnet 5" \
        "h" "Haiku 4.5" \
        3>&1 1>&2 2>&3)
    [[ -z "$modell" ]] && return
    case $modell in
        o) mode_args+=(--model claude-opus-4-8) ;;
        s) mode_args+=(--model claude-sonnet-5) ;;
        h) mode_args+=(--model claude-haiku-4-5-20251001) ;;
    esac

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

    # --- Samle git-repos som "ts|kategori|path" ---
    local -a rows=()
    local line
    while IFS= read -r line; do rows+=("$line"); done < <(
        find /root/workspace -mindepth 1 -maxdepth 2 -type d -not -name '.*' \
            -not -path '*/protonord_produkter/*' 2>/dev/null | while IFS= read -r d; do
            [ -d "$d/.git" ] || continue
            rel=${d#/root/workspace/}
            if [[ "$rel" == */* ]]; then kat=${rel%%/*}; else kat="andre"; fi
            ts=$(git -C "$d" log -1 --format="%ct" 2>/dev/null)
            [ -z "$ts" ] && ts=$(stat -c %Y "$d" 2>/dev/null || echo 0)
            printf '%s|%s|%s\n' "$ts" "$kat" "$d"
        done
    )
    echo "repos: ${#rows[@]}" >> "$_dbg"

    # --- Steg 3: kategori (nyeste aktivitet øverst) ---
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

    local mappe
    if [[ "$kategori" == "." ]]; then
        mappe=$PWD
    else
        # --- Steg 4: repo i valgt kategori (sist jobbet øverst) ---
        local -a repo_menu=()
        local rts rkat rpath name
        while IFS='|' read -r rts rkat rpath; do
            [ -z "$rpath" ] && continue
            name=${rpath#/root/workspace/}
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
        mappe="/root/workspace/$valgt"
    fi

    # --- Steg 5: chat-historikk for valgt mappe -> fortsett eller ny ---
    # Transkripter ligger i $CLAUDE_CONFIG_DIR/projects/<sti med / . _ -> ->
    local proj_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(printf '%s' "$mappe" | sed 's/[^A-Za-z0-9-]/-/g')"
    local -a hist_menu=() hist_ids=()
    local f sid hts ex hi=0
    for f in $(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -8); do
        sid=${f##*/}; sid=${sid%.jsonl}
        hts=$(stat -c %Y "$f" 2>/dev/null || echo 0)
        # utsnitt: summary-linje hvis den finnes, ellers første bruker-tekst
        ex=$(head -n 40 "$f" | jq -r 'if .type=="summary" then .summary
            elif .type=="user" and (.message.content|type=="string") then .message.content
            elif .type=="user" then ([.message.content[]? | select(.type=="text") | .text] | join(" "))
            else empty end | gsub("\\s+"; " ")' 2>/dev/null \
            | grep -vE '^(<|Caveat:|$)' | head -1)
        hi=$((hi+1))
        hist_ids+=("$sid")
        hist_menu+=("$hi" "$(date -d "@$hts" +'%d.%m %H:%M') · ${ex:0:44}")
    done
    echo "historikk i $proj_dir: $hi" >> "$_dbg"

    if [[ $hi -gt 0 ]]; then
        local hvalg
        hvalg=$(whiptail \
            --title "Claude Code - historikk" \
            --menu "Chat-historikk i ${mappe#/root/workspace/} ($hi samtaler, nyeste øverst):" \
            20 76 9 \
            -- "n" "Ny samtale" "${hist_menu[@]}" \
            3>&1 1>&2 2>&3)
        [[ -z "$hvalg" ]] && return
        [[ "$hvalg" != "n" ]] && mode_args+=(--resume "${hist_ids[$((hvalg-1))]}")
    else
        whiptail --title "Claude Code" \
            --msgbox "Ingen chat-historikk for denne mappen - starter ny samtale." 8 62
    fi

    cd "$mappe" && command claude "${mode_args[@]}"
}
