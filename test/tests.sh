#!/bin/bash

this_dir="$(dirname "$(realpath "$0")")"
common_sh="$this_dir/../src/common.sh"
source "$common_sh"

# -------------------------- TEST FIXTURES ------------------------------------

failures=()

function reset_test_failures() {
	failures=()
}

function print_test_failures() {
	local failcount=${#failures[@]}
	local i
	if [[ $failcount -eq 0 ]]; then
		echo "${color_green}passed${color_reset}"
		reset_test_failures
		return 0
	fi
	echo "${color_red}failed ($failcount)${color_reset}:"
	for ((i = 0; i < failcount; i++)); do
		echo "  ${failures[i]}"
	done
	reset_test_failures
}

function run_test() {
	echo -n "Running: ${color_lightgray}$1${color_reset}..."
	"$1"
	print_test_failures
}

# -------------------------- TEST CASES ---------------------------------------

# tests for `$regex_eth_addr` in common.sh
function test_regex_eth_addr() {
	local valids=(
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f'
		'0x0123456789abcdefABCDEF01234567890abcdef0'
		'0x0000000000000000000000000000000000000000'
		'0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
	)
	local invalids=(
		'0x0123456789abcdefABCDEF01234567890abcdef0,0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f' # csv
		'0x0123456789abcdefABCDEF01234567890abcdef0,0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f,0x0123456789abcdefABCDEF01234567890abcdef0' # csv
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068' # too short
		'0xZEBRA123FAACf8071bd4bb5AB99Db01938090689' # invalid characters
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f1' # too long
		'f19B1c91FAACf8071bd4bb5AB99Db0193809068f1' # missing 0x
	)
	local curtest
	local i

	for ((i = 0; i < ${#valids[@]}; i++)); do
		curtest=${valids[i]}
		if [[ ! $curtest =~ $regex_eth_addr ]]; then
			failures+=("Expected valid: $curtest")
		fi
	done

	for ((i = 0; i < ${#invalids[@]}; i++)); do
		curtest=${invalids[i]}
		if [[ $curtest =~ $regex_eth_addr ]]; then
			failures+=("Expected invalid: $curtest")
		fi
	done
}

# tests for `$regex_eth_addr_csv` in common.sh
function test_regex_eth_addr_csv() {
	local valids=(
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f'
		'0x0123456789abcdefABCDEF01234567890abcdef0,0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f'
		'0x0123456789abcdefABCDEF01234567890abcdef0,0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f,0x0123456789abcdefABCDEF01234567890abcdef0'
	)
	local invalids=(
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068' # too short
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068,0x0123456789abcdefABCDEF01234567890abcdefg' # too short csv
		'0xZEBRA123FAACf8071bd4bb5AB99Db01938090689' # invalid characters
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f1' # too long
		'f19B1c91FAACf8071bd4bb5AB99Db0193809068f1' # missing 0x
		'f19B1c91FAACf8071bd4bb5AB99Db0193809068f,f19B1c91FAACf8071bd4bb5AB99Db0193809068f' # missing 0x csv
		'0x0123456789abcdefABCDEF01234567890abcdef0,0x0x0123456789abcdefABCDEF01234567890abcde' # too many 0x
		',0x0123456789abcdefABCDEF01234567890abcdef0,0x0123456789abcdefABCDEF01234567890abcdef0' # leading comma
		'0x0123456789abcdefABCDEF01234567890abcdef0 0x0123456789abcdefABCDEF01234567890abcdef0' # spaced not csv
		'0x0123456789abcdefABCDEF01234567890abcdef0, 0x0123456789abcdefABCDEF01234567890abcdef0' # csv plus space
	)
	local curtest
	local i

	for ((i = 0; i < ${#valids[@]}; i++)); do
		curtest=${valids[i]}
		if [[ ! $curtest =~ $regex_eth_addr_csv ]]; then
			failures+=("Expected valid: $curtest")
		fi
	done

	for ((i = 0; i < ${#invalids[@]}; i++)); do
		curtest=${invalids[i]}
		if [[ $curtest =~ $regex_eth_addr_csv ]]; then
			failures+=("Expected invalid: $curtest")
		fi
	done
}

# tests for `yes_or_no()` in common.sh
function test_yes_or_no() {
	#
	# --default-yes
	#
	if echo "y" | yes_or_no "--default-yes" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (y)(--default-yes)")
	fi
	if echo "n" | yes_or_no "--default-yes" "Continue?"; then
		failures+=("Expected 'no' (n)(--default-yes)")
	else
		: # success
	fi
	if echo "" | yes_or_no "--default-yes" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (<blank>)(--default-yes)")
	fi
	if echo "zebra" | yes_or_no "--default-yes" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (zebra)(--default-yes)")
	fi

	#
	# --default-no
	#
	if echo "y" | yes_or_no "--default-no" "Continue?"; then
		: # success
	else
		failures+=("Expected 'yes' (y)(--default-no)")
	fi
	if echo "n" | yes_or_no "--default-no" "Continue?"; then
		failures+=("Expected 'no' (n)(--default-no)")
	else
		: # success
	fi
	if echo "" | yes_or_no "--default-no" "Continue?"; then
		failures+=("Expected 'no' (<blank>)(--default-no)")
	else
		: # success
	fi
	if echo "zebra" | yes_or_no "--default-no" "Continue?"; then
		failures+=("Expected 'no' (zebra)(--default-no)")
	else
		: # success
	fi
}

# tests for `continue_or_exit()` in common.sh
function test_continue_or_exit() {
	local yeses=(
		'y'
		'yes'
	)
	local nos=(
		'n'
		'no'
		''
		'zebra'
	)
	local curtest i

	for ((i = 0; i < ${#yeses[@]}; i++)); do
		curtest=${yeses[i]}
		$(echo "$curtest" | continue_or_exit 3)
		if [[ $? -ne 0 ]]; then
			failures+=("Expected 'yes' (${curtest:-"<blank>"})")
		fi
	done

	for ((i = 0; i < ${#nos[@]}; i++)); do
		curtest=${nos[i]}
		$(echo "$curtest" | continue_or_exit 3)
		if [[ $? -ne 3 ]]; then
			failures+=("Expected 'no' (${curtest:-"<blank>"})")
		fi
	done
}

# tests for `get_latest_prysm_version()` in common.sh
function test_get_latest_prysm_version() {
	local pversion
	if get_latest_prysm_version pversion; then
		printinfo "Latest prysm version: $pversion"
	else
		failures+=("failed to get latest prysm version")
	fi
}

# -------------------------- TEST DRIVER --------------------------------------

run_test test_regex_eth_addr
run_test test_regex_eth_addr_csv
run_test test_yes_or_no
run_test test_continue_or_exit
run_test test_get_latest_prysm_version
