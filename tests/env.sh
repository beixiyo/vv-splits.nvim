#!/bin/sh
# Only declare the external integration prerequisite; shared entry owns isolation.
command -v tmux >/dev/null 2>&1 || {
  printf 'vv-test: splits integration tests require an existing tmux executable on PATH\n' >&2
  return 1
}
