#!/usr/bin/env bash
# SwiftBar plugin — pr-watcher UI.
# Refresh every 5 min (from filename `.5m.`). State is read from the cache
# populated hourly by the launchd job — this plugin never hits GitHub itself.
#
# UX:
#   • If clipboard holds a GitHub PR URL not yet watched → 1-click add row.
#   • Each watched PR is a submenu: Copy URL, Remove. Row click opens the PR.
#   • "Add PR…" dialog stays as a fallback for typed URLs.
#
# <bitbar.title>pr-watcher</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.desc>Menu bar UI for the pr-watcher GitHub PR notifier</bitbar.desc>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"
umask 077

CONFIG="${HOME}/.pr-watcher/config.json"
STATE="${HOME}/.pr-watcher/state.json"
LOG="${HOME}/.pr-watcher/logs/pr-watcher.log"

mkdir -p "$(dirname "$CONFIG")"
[ -f "$CONFIG" ] || echo '{"prs":[]}' > "$CONFIG"
[ -f "$STATE" ]  || echo '{}' > "$STATE"

# Stay resilient to malformed files. A bad state.json is safe to reset (the
# poller repopulates it); a bad config.json is surfaced without clobbering it.
if ! jq -e . "$CONFIG" >/dev/null 2>&1; then
  echo ":eye: ⚠️"; echo "---"; echo "config.json is not valid JSON | color=red"
  echo "⚙️ Edit config… | shell=/usr/bin/open param1=\"${CONFIG}\" terminal=false"
  exit 0
fi
jq -e . "$STATE" >/dev/null 2>&1 || echo '{}' > "$STATE"

# Counts (total + still-open) in a single jq pass.
{ IFS=$'\t' read -r count open_count; } < <(
  jq -r --slurpfile s "$STATE" \
    '[(.prs | length),
      (.prs | map(select(($s[0][.] // "OPEN") == "OPEN")) | length)] | @tsv' "$CONFIG"
)

# ─── Menu bar label ────────────────────────────────────────────────────────────
if [ "${count:-0}" -eq 0 ]; then
  echo ":eye: —"
else
  echo ":eye: ${open_count}/${count}"
fi
echo "---"

# ─── Clipboard quick-add ───────────────────────────────────────────────────────
clip="$(pbpaste 2>/dev/null | tr -d '[:space:]')"
if [[ "$clip" =~ ^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/pull/[0-9]+/?$ ]]; then
  clip_url="${clip%/}"
  is_watched="$(jq -r --arg u "$clip_url" '.prs | any(. == $u)' "$CONFIG")"
  if [ "$is_watched" = "false" ]; then
    clip_label="$(echo "$clip_url" | sed -E 's|https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*|\2 #\3|')"
    printf '✨ Add from clipboard: %s | shell=pr-watcher-add-url param1="%s" terminal=false refresh=true color=#4c6ef5\n' \
      "$clip_label" "$clip_url"
    echo "---"
  fi
fi

# ─── Watched PRs (row = open PR, submenu = copy + remove) ──────────────────────
if [ "${count:-0}" -eq 0 ]; then
  echo "No PRs watched — copy a GitHub PR URL and click here | color=gray"
else
  # One jq pass emits "url<TAB>state<TAB>label" for every watched PR; the label
  # (owner/repo #num) is computed in jq, so there's no per-row sed/jq spawn.
  while IFS=$'\t' read -r url state label; do
    [ -z "$url" ] && continue
    case "$state" in
      MERGED) icon=":checkmark.seal.fill:" ; color="#2f9e44" ;;
      CLOSED) icon=":xmark.circle.fill:"   ; color="#c92a2a" ;;
      OPEN)   icon=":circle.dashed:"       ; color="#f08c00" ;;
      *)      icon=":questionmark.circle:" ; color="gray"    ;;
    esac

    printf '%s %s — %s | href=%s color=%s\n' "$icon" "$label" "$state" "$url" "$color"
    printf -- '-- 📋 Copy URL | shell=pr-watcher-copy param1="%s" terminal=false\n' "$url"
    printf -- '-- 🗑 Remove | shell=pr-watcher-remove-url param1="%s" terminal=false refresh=true\n' "$url"
  done < <(
    jq -r --slurpfile s "$STATE" \
      '.prs[] as $u | ($u | split("/")) as $p
       | [$u, ($s[0][$u] // "OPEN"), "\($p[4]) #\($p[6])"] | @tsv' "$CONFIG"
  )
fi

# ─── Global actions ────────────────────────────────────────────────────────────
echo "---"
echo "➕ Add PR (type URL)… | shell=pr-watcher-add terminal=false refresh=true"
echo "🔄 Check now | shell=pr-watcher param1=\"--force\" terminal=false refresh=true"

# ─── Footer ────────────────────────────────────────────────────────────────────
echo "---"
echo "📄 Open log | shell=/usr/bin/open param1=\"${LOG}\" terminal=false"
echo "⚙️ Edit config… | shell=/usr/bin/open param1=\"${CONFIG}\" terminal=false"
