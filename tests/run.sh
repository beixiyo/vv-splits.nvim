#!/bin/sh

set -eu

tests_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
nvim_bin=${NVIM_BIN:-nvim}
passed=0

for test_file in "$tests_dir"/test_*.lua; do
  test_name=$(basename -- "$test_file")
  printf 'RUN: %s\n' "$test_name"
  "$nvim_bin" --headless -u NONE -l "$test_file"
  passed=$((passed + 1))
  printf 'PASS: %s\n' "$test_name"
done

printf 'PASS: %d test files\n' "$passed"
