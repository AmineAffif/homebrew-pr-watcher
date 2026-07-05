#!/usr/bin/env bats
# Unit tests for the html_escape() function used to sanitize PR data before it
# is written into the celebration page.
load test_helper

@test "html_escape: < becomes &lt;" {
  _load_html_escape
  run html_escape '<'
  [ "$output" = '&lt;' ]
}

@test "html_escape: > becomes &gt;" {
  _load_html_escape
  run html_escape '>'
  [ "$output" = '&gt;' ]
}

@test "html_escape: & becomes &amp;" {
  _load_html_escape
  run html_escape '&'
  [ "$output" = '&amp;' ]
}

@test "html_escape: double quote becomes &quot;" {
  _load_html_escape
  run html_escape '"'
  [ "$output" = '&quot;' ]
}

@test "html_escape: single quote becomes &#39;" {
  _load_html_escape
  run html_escape "'"
  [ "$output" = '&#39;' ]
}

@test "html_escape: ampersand is escaped first (no &amp;lt; artifacts from < > escaping)" {
  _load_html_escape
  run html_escape '<&>'
  [ "$output" = '&lt;&amp;&gt;' ]
}

@test "html_escape: leaves ordinary text untouched" {
  _load_html_escape
  run html_escape 'Fix login redirect (#42)'
  [ "$output" = 'Fix login redirect (#42)' ]
}
