#!/usr/bin/env bats
# SwiftBar plugin output: menu-bar label, watched-PR rows, and resilience.
load test_helper

plugin() { "$REPO/plugin/pr-watcher.5m.sh"; }

@test "plugin shows open/total and one row per watched PR" {
  echo '{"prs":["https://github.com/o/r/pull/1","https://github.com/a/b/pull/2"]}' > "$HOME/.pr-watcher/config.json"
  echo '{"https://github.com/o/r/pull/1":"MERGED"}' > "$HOME/.pr-watcher/state.json"
  run plugin
  [ "$status" -eq 0 ]
  echo "$output" | grep -q ':eye: 1/2'
  echo "$output" | grep -q 'r #1 — MERGED | href=https://github.com/o/r/pull/1'
  echo "$output" | grep -q 'b #2 — OPEN | href=https://github.com/a/b/pull/2'
  echo "$output" | grep -q '📋 Copy URL | shell=pr-watcher-copy param1="https://github.com/o/r/pull/1"'
  echo "$output" | grep -q '🗑 Remove | shell=pr-watcher-remove-url param1="https://github.com/a/b/pull/2"'
}

@test "plugin shows a dash when nothing is watched" {
  echo '{"prs":[]}' > "$HOME/.pr-watcher/config.json"
  echo '{}' > "$HOME/.pr-watcher/state.json"
  run plugin
  [ "$status" -eq 0 ]
  echo "$output" | grep -q ':eye: —'
}

@test "plugin tolerates a corrupt state.json (resets, still renders)" {
  echo '{"prs":["https://github.com/o/r/pull/1"]}' > "$HOME/.pr-watcher/config.json"
  printf 'not json at all' > "$HOME/.pr-watcher/state.json"
  run plugin
  [ "$status" -eq 0 ]
  echo "$output" | grep -q ':eye: 1/1'
}

@test "plugin surfaces a corrupt config.json without crashing" {
  printf '{bad json' > "$HOME/.pr-watcher/config.json"
  echo '{}' > "$HOME/.pr-watcher/state.json"
  run plugin
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'not valid JSON'
}
