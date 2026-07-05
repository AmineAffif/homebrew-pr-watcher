#!/usr/bin/env bats
# Validates the PR-URL regex through the add path: a valid URL lands in the
# config, an invalid one is rejected (non-zero exit, config untouched).
load test_helper

@test "accepts a valid PR URL" {
  run pr-watcher-add-url "https://github.com/owner/repo/pull/42"
  [ "$status" -eq 0 ]
  run config_prs
  [ "$output" = "https://github.com/owner/repo/pull/42" ]
}

@test "normalizes a trailing slash" {
  pr-watcher-add-url "https://github.com/o/r/pull/7/"
  run config_prs
  [ "$output" = "https://github.com/o/r/pull/7" ]
}

@test "accepts owner/repo with dots, dashes, underscores" {
  run pr-watcher-add-url "https://github.com/my-org/my_repo.js/pull/3"
  [ "$status" -eq 0 ]
  run config_prs
  [ "$output" = "https://github.com/my-org/my_repo.js/pull/3" ]
}

@test "rejects a non-github host" {
  run pr-watcher-add-url "https://gitlab.com/o/r/pull/1"
  [ "$status" -ne 0 ]
  no_prs_stored
}

@test "rejects github.com in the userinfo (github.com@evil.com)" {
  run pr-watcher-add-url "https://github.com@evil.com/o/r/pull/1"
  [ "$status" -ne 0 ]
  no_prs_stored
}

@test "rejects a lookalike host (github.com.evil.com)" {
  run pr-watcher-add-url "https://github.com.evil.com/o/r/pull/1"
  [ "$status" -ne 0 ]
  no_prs_stored
}

@test "rejects HTML metacharacters in the owner segment" {
  run pr-watcher-add-url 'https://github.com/<script>/r/pull/1'
  [ "$status" -ne 0 ]
  no_prs_stored
}

@test "rejects an issues URL (only /pull/ is allowed)" {
  run pr-watcher-add-url "https://github.com/o/r/issues/1"
  [ "$status" -ne 0 ]
}

@test "rejects a missing PR number" {
  run pr-watcher-add-url "https://github.com/o/r/pull/"
  [ "$status" -ne 0 ]
}

@test "rejects a plain http (non-TLS) URL" {
  run pr-watcher-add-url "http://github.com/o/r/pull/1"
  [ "$status" -ne 0 ]
}
