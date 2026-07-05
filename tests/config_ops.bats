#!/usr/bin/env bats
# Config/state mutations: add, remove, dedup, copy, and file permissions.
load test_helper

@test "add-url is idempotent (no duplicates)" {
  pr-watcher-add-url "https://github.com/o/r/pull/1"
  pr-watcher-add-url "https://github.com/o/r/pull/1"
  run config_prs
  [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
}

@test "remove-url deletes the URL from both config and state" {
  pr-watcher-add-url "https://github.com/o/r/pull/1"
  echo '{"https://github.com/o/r/pull/1":"MERGED"}' > "$HOME/.pr-watcher/state.json"
  pr-watcher-remove-url "https://github.com/o/r/pull/1"
  run config_prs
  [ -z "$output" ]
  run jq -r 'has("https://github.com/o/r/pull/1")' "$HOME/.pr-watcher/state.json"
  [ "$output" = "false" ]
}

@test "config.json stays valid JSON after a series of operations" {
  pr-watcher-add-url "https://github.com/o/r/pull/1"
  pr-watcher-add-url "https://github.com/a/b/pull/2"
  pr-watcher-remove-url "https://github.com/o/r/pull/1"
  run jq -e . "$HOME/.pr-watcher/config.json"
  [ "$status" -eq 0 ]
  run config_prs
  [ "$output" = "https://github.com/a/b/pull/2" ]
}

@test "copy sends the exact URL to the clipboard" {
  pr-watcher-copy "https://github.com/o/r/pull/99"
  run cat "$STUB_LOG/pbcopy.out"
  [ "$output" = "https://github.com/o/r/pull/99" ]
}

@test "created config/state files are owner-only (0600)" {
  pr-watcher-add-url "https://github.com/o/r/pull/1"
  [ "$(stat -f '%OLp' "$HOME/.pr-watcher/config.json")" = "600" ]
}
