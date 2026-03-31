# cresume — cross-directory Claude Code session resume picker
# Sourced as a shell function (works in both bash and zsh)

cresume() {
  local sessions_dir="$HOME/.claude/projects"
  local show_all=false
  local search_term=""
  local limit=50

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--all) show_all=true; shift ;;
      *) search_term="$1"; shift ;;
    esac
  done

  if ! command -v fzf &>/dev/null; then
    echo "cresume: fzf is required. Install with: brew install fzf" >&2
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    echo "cresume: jq is required. Install with: brew install jq" >&2
    return 1
  fi

  local workdir count jsonl head_lines cwd session_id git_branch user_msg
  local title last_ts date_str relative_time ts_epoch now_epoch diff_seconds
  local short_path fsize dim bold reset selected_display idx
  local selected_session_id selected_cwd

  workdir=$(mktemp -d)

  _cresume_cleanup() { rm -rf "$workdir"; }

  dim=$'\033[2m'
  bold=$'\033[1m'
  reset=$'\033[0m'
  count=0

  for jsonl in "$sessions_dir"/*/*.jsonl; do
    [[ -f "$jsonl" && -s "$jsonl" ]] || continue

    head_lines=$(head -30 "$jsonl")

    cwd=$(echo "$head_lines" | jq -r 'select(.cwd != null) | .cwd' 2>/dev/null | head -1)
    session_id=$(echo "$head_lines" | jq -r 'select(.sessionId != null) | .sessionId' 2>/dev/null | head -1)
    git_branch=$(echo "$head_lines" | jq -r 'select(.gitBranch != null) | .gitBranch' 2>/dev/null | head -1)

    [[ -z "$cwd" || -z "$session_id" ]] && continue

    # Unless --all, only show sessions from the current directory and below (case-insensitive)
    local cwd_lower pwd_lower
    cwd_lower=$(echo "$cwd" | tr '[:upper:]' '[:lower:]')
    pwd_lower=$(echo "$PWD" | tr '[:upper:]' '[:lower:]')
    if [[ "$show_all" == false && "$cwd_lower" != "$pwd_lower" && "$cwd_lower" != "$pwd_lower/"* ]]; then
      continue
    fi

    user_msg=$(echo "$head_lines" | jq -r 'select(.type == "user") | .message.content' 2>/dev/null | head -1)
    [[ -z "$user_msg" ]] && continue

    title=$(echo "$user_msg" | head -1 | cut -c1-80)

    printf '%s\n%s\n' "$session_id" "$cwd" > "$workdir/meta_$count"

    # Build preview: first few user prompts from the session
    local prompt_count=0
    : > "$workdir/preview_$count"
    while IFS= read -r msg; do
      [[ -z "$msg" ]] && continue
      prompt_count=$((prompt_count + 1))
      [[ $prompt_count -gt 5 ]] && break
      if [[ $prompt_count -gt 1 ]]; then
        printf '\n────────────────────────────────\n\n' >> "$workdir/preview_$count"
      fi
      printf '› %s\n' "$(echo "$msg" | head -3)" >> "$workdir/preview_$count"
    done < <(jq -r 'select(.type == "user" and (.message.content | type) == "string") | .message.content' "$jsonl" 2>/dev/null)

    last_ts=$(tail -1 "$jsonl" | jq -r '.timestamp // empty' 2>/dev/null)
    if [[ -z "$last_ts" ]]; then
      last_ts=$(echo "$head_lines" | jq -r 'select(.timestamp != null) | .timestamp' 2>/dev/null | tail -1)
    fi

    if [[ -z "$last_ts" ]]; then
      date_str=$(date -r "$jsonl" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    else
      date_str=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${last_ts%%.*}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "${last_ts:0:16}")
    fi

    relative_time=""
    if [[ -n "$last_ts" ]]; then
      ts_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${last_ts%%.*}" "+%s" 2>/dev/null)
      now_epoch=$(date "+%s")
      if [[ -n "$ts_epoch" ]]; then
        diff_seconds=$((now_epoch - ts_epoch))
        if [[ $diff_seconds -lt 60 ]]; then
          relative_time="just now"
        elif [[ $diff_seconds -lt 3600 ]]; then
          relative_time="$((diff_seconds / 60)) minutes ago"
        elif [[ $diff_seconds -lt 86400 ]]; then
          relative_time="$((diff_seconds / 3600)) hours ago"
        elif [[ $diff_seconds -lt 604800 ]]; then
          relative_time="$((diff_seconds / 86400)) days ago"
        else
          relative_time="$date_str"
        fi
      fi
    fi
    [[ -z "$relative_time" ]] && relative_time="$date_str"

    short_path="${cwd/#$HOME/~}"
    [[ ! -d "$cwd" ]] && short_path="$short_path [missing]"

    fsize=$(du -h "$jsonl" 2>/dev/null | awk '{print $1}')

    printf '%s\t%s\n' "$date_str" "$count" >> "$workdir/order"

    printf '%b%s%b\n%b  %s · %s · %s · %s%b\n\n' \
      "$bold" "$title" "$reset" \
      "$dim" "$relative_time" "$short_path" "${git_branch:-none}" "${fsize:-?}" "$reset" \
      > "$workdir/display_$count"

    count=$((count + 1))
  done

  if [[ ! -f "$workdir/order" ]]; then
    echo "cresume: no sessions found" >&2
    _cresume_cleanup
    return 1
  fi

  # Build null-delimited fzf input, sorted by date descending
  : > "$workdir/fzf_input"
  sort -r "$workdir/order" | if [[ "$show_all" == false ]]; then head -"$limit"; else cat; fi | \
    while IFS=$'\t' read -r _ idx; do
      cat "$workdir/display_$idx" >> "$workdir/fzf_input"
      printf '\0' >> "$workdir/fzf_input"
    done

  # Build a lookup file: line 1 of each display (the title) mapped to its index
  sort -r "$workdir/order" | if [[ "$show_all" == false ]]; then head -"$limit"; else cat; fi | \
    while IFS=$'\t' read -r _ i; do
      title_line=$(head -1 "$workdir/display_$i" | sed 's/\x1b\[[0-9;]*m//g')
      printf '%s\t%s\n' "$title_line" "$i"
    done > "$workdir/title_map"

  # Preview script: matches the first line of selection to find the index
  cat > "$workdir/preview.sh" << PREVIEW_EOF
#!/usr/bin/env bash
# Extract first line, strip ANSI codes, look up in title_map
first_line=\$(echo "\$@" | head -1 | sed 's/\x1b\[[0-9;]*m//g')
idx=\$(grep -F "\$first_line" "$workdir/title_map" | head -1 | awk -F'\t' '{print \$NF}')
if [[ -n "\$idx" && -f "$workdir/preview_\$idx" ]]; then
  cat "$workdir/preview_\$idx"
else
  echo "No preview available"
fi
PREVIEW_EOF
  chmod +x "$workdir/preview.sh"

  # Run fzf
  selected_display=$(fzf --read0 \
      --ansi \
      --query="$search_term" \
      --header="Select a Claude session to resume" \
      --no-multi \
      --reverse \
      --preview="$workdir/preview.sh {}" \
      --preview-window=right:40%:wrap \
      < "$workdir/fzf_input")

  if [[ -z "$selected_display" ]]; then
    _cresume_cleanup
    return 0
  fi

  # Match selection back to index via title
  local selected_title
  selected_title=$(echo "$selected_display" | head -1 | sed 's/\x1b\[[0-9;]*m//g')
  idx=$(grep -F "$selected_title" "$workdir/title_map" | head -1 | awk -F'\t' '{print $NF}')

  if [[ -z "$idx" || ! -f "$workdir/meta_$idx" ]]; then
    _cresume_cleanup
    return 1
  fi

  selected_session_id=$(sed -n '1p' "$workdir/meta_$idx")
  selected_cwd=$(sed -n '2p' "$workdir/meta_$idx")

  _cresume_cleanup

  if [[ -d "$selected_cwd" ]]; then
    cd "$selected_cwd" || return 1
    echo "Changed to: $selected_cwd"
  else
    echo "Warning: directory $selected_cwd no longer exists. Staying in current directory." >&2
  fi

  claude --resume "$selected_session_id"
}
