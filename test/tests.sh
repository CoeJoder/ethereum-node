#!/bin/bash
set -Eeuo pipefail

this_dir="$(dirname "$(realpath "$0")")"
common_sh="$this_dir/../scripts/common.sh"
source "$common_sh"

# -------------------------- TEST FIXTURES ------------------------------------

failures=()

function reset() {
  failures=()
}

function print_any_failures() {
  local failcount=${#failures[@]}
  local i
  if [[ $failcount -eq 0 ]]; then
    echo "Tests passed."
    return 0
  fi
  echo "Tests failed ($failcount):"
  for ((i = 0 ; i < failcount ; i++ )); do
    echo "  ${failures[i]}"
  done
}

# -------------------------- TEST CASES ---------------------------------------

# tests for `$regex_hex_csv` const in common.sh
function test_regex_hex_list() {
  local valids=(
    '0xabc'
    '0x123'
    '0xabc123'
    '0xabc,0x123'
    '0xabc,0x123,0xdEaDBeEf567'
  )
  local invalids=(
    '0xZEBRA123'
    'abc123'
    'abc123,efg456'
    'x123,0xabc'
    '0xabc,0x123,'
    ',0xabc,0x123'
    '0x1 0x2'
    '0x1, 0x2'
  )
  local curtest
  local i

  for ((i = 0 ; i < ${#valids[@]} ; i++ )); do
    curtest=${valids[i]}
    if [[ ! $curtest =~ $regex_hex_csv ]]; then
      failures+=("Expected valid: $curtest")
    fi
  done

  for ((i = 0 ; i < ${#invalids[@]} ; i++ )); do
    curtest=${invalids[i]}
    if [[ $curtest =~ $regex_hex_csv ]]; then
      failures+=("Expected invalid: $curtest")
    fi
  done
}

# -------------------------- TEST DRIVER --------------------------------------

reset
test_regex_hex_list
print_any_failures
