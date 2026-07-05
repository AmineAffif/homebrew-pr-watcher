#!/usr/bin/env bash
# Shared setup for pr-watcher bats tests.
#
# Every test runs against an isolated $HOME so the scripts read/write their
# config/state under a throwaway ~/.pr-watcher, and every external command the
# scripts shell out to (gh, osascript, open, pbcopy, pbpaste) is stubbed so the
# suite runs headless — no network, no GUI dialogs, no real notifications.

setup() {
  REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.pr-watcher/logs"

  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  STUB_LOG="$BATS_TEST_TMPDIR/stublog"
  mkdir -p "$STUB_BIN" "$STUB_LOG"
  export STUB_LOG

  _make_stubs

  # Stubs win over the real tools; repo bin next so the scripts under test — and
  # the `pr-watcher --force` they call internally — resolve to our code.
  export PATH="$STUB_BIN:$REPO/bin:$PATH"

  export PR_WATCHER_SHARE="$REPO/templates"   # celebration template location
  export PRW_OPEN="$STUB_BIN/open"            # capture the "open in browser" call

  # Per-test overridable stub behaviour.
  export GH_PR_JSON=""    # JSON returned by `gh pr view`
  export OSA_OUT=""       # stdout returned by osascript (dialog / picker result)
  export CLIPBOARD=""     # what pbpaste returns
}

_make_stubs() {
  cat > "$STUB_BIN/gh" <<EOF
#!/usr/bin/env bash
echo "gh \$*" >> "$STUB_LOG/gh.log"
if [ "\$1" = "pr" ] && [ "\$2" = "view" ]; then
  printf '%s' "\${GH_PR_JSON:-}"
fi
EOF

  cat > "$STUB_BIN/osascript" <<EOF
#!/usr/bin/env bash
{ echo "argc=\$#"; for a in "\$@"; do echo "arg=\$a"; done; } >> "$STUB_LOG/osascript.argv"
cat >> "$STUB_LOG/osascript.stdin" 2>/dev/null || true
printf '%s' "\${OSA_OUT:-}"
EOF

  cat > "$STUB_BIN/open" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$STUB_LOG/open.log"
EOF

  cat > "$STUB_BIN/pbcopy" <<EOF
#!/usr/bin/env bash
cat > "$STUB_LOG/pbcopy.out"
EOF

  cat > "$STUB_BIN/pbpaste" <<EOF
#!/usr/bin/env bash
printf '%s' "\${CLIPBOARD:-}"
EOF

  chmod +x "$STUB_BIN"/*
}

# ── Assertion helpers ──────────────────────────────────────────────────────────
config_prs() { jq -r '.prs[]' "$HOME/.pr-watcher/config.json"; }
state_of()   { jq -r --arg u "$1" '.[$u] // ""' "$HOME/.pr-watcher/state.json"; }

# True when no PR is stored — config missing (rejected before creation) or empty.
no_prs_stored() {
  [ ! -f "$HOME/.pr-watcher/config.json" ] ||
    [ "$(jq -r '.prs | length' "$HOME/.pr-watcher/config.json")" -eq 0 ]
}

# Source the html_escape() function out of the pr-watcher script for unit tests.
_load_html_escape() {
  eval "$(sed -n '/^html_escape()/,/^}/p' "$REPO/bin/pr-watcher")"
}
