#!/usr/bin/env bats
# The core watch loop: an OPEN PR is silent, a merge fires the celebration
# exactly once, and re-runs after the merge stay quiet.
load test_helper

MERGED_JSON='{"state":"MERGED","mergedAt":"2026-07-05T10:00:00Z","title":"Fix things","number":42}'
OPEN_JSON='{"state":"OPEN","mergedAt":null,"title":"Fix things","number":42}'

seed_config() {
  echo '{"prs":["https://github.com/o/r/pull/42"]}' > "$HOME/.pr-watcher/config.json"
}

@test "an OPEN PR does not notify" {
  seed_config
  export GH_PR_JSON="$OPEN_JSON"
  run pr-watcher --force
  [ "$status" -eq 0 ]
  [ ! -f "$STUB_LOG/open.log" ]
  run state_of "https://github.com/o/r/pull/42"
  [ "$output" = "OPEN" ]
}

@test "a merged PR notifies exactly once across repeated runs" {
  seed_config
  export GH_PR_JSON="$MERGED_JSON"
  pr-watcher --force
  pr-watcher --force
  [ "$(grep -c . "$STUB_LOG/open.log")" -eq 1 ]
  run state_of "https://github.com/o/r/pull/42"
  [ "$output" = "MERGED" ]
}

@test "the celebration page is generated on merge" {
  seed_config
  export GH_PR_JSON="$MERGED_JSON"
  pr-watcher --force
  [ -f "$HOME/.pr-watcher/notify-42.html" ]
}

@test "a failed gh lookup is tolerated (logged, no crash)" {
  seed_config
  export GH_PR_JSON=""    # gh returns nothing
  run pr-watcher --force
  [ "$status" -eq 0 ]
  grep -q "gh pr view failed" "$HOME/.pr-watcher/logs/pr-watcher.log"
}
