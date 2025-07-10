#!/bin/bash

# tests.sh
#
# Runs unit and integration tests.

# -------------------------- HEADER -------------------------------------------

this_dir="$(dirname "$(realpath "$0")")"
source "$this_dir/../src/common.sh"

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null || exit

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null || return
	[[ -d $temp_dir ]] && sudo rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_exit' EXIT

# -------------------------- TEST FIXTURES ------------------------------------

failures=()

function reset_test_failures() {
	failures=()
}

function print_test_results() {
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
	printinfo -n "Running: ${color_lightgray}$1${color_reset}..."
	"$1"
	print_test_results
}

#
# these functions adapt the `check_` functions to the test fixtures:
#

function _dont_expect_checkfailures() {
	if [[ ${#_check_failures[@]} -gt 0 ]]; then
		failures+=("${_check_failures[@]}")
	fi
}

function _expect_checkfailures() {
	local expected_count=$1
	local actual_count=${#_check_failures[@]}
	if [[ $expected_count -ne $actual_count ]]; then
		failures+=("line $(caller): check-failures expected: ${expected_count}, actual: ${color_red}$actual_count${color_reset}")
	fi
}

# -------------------------- TEST CASES ---------------------------------------

# tests for `$parse_index_from_signing_key_path` in common.sh
function test_parse_index_from_signing_key_path() {
	local valids=(
		'm/12381/3600/0/0/0'
		'm/12381/3600/1/0/0'
		'm/12381/3600/2/0/0'
	)
	local invalids=(
		'm/12381/3600/a/0/0'  # invalid index
		'm/12382/3600/1/0/0'  # wrong prefix
		'm/12381/3600/2/0'    # too short
		'm/12381/3600/42/0/0' # wrong index
		'zebra'               # not a zoo
	)
	local curtest
	local i
	local actual_index

	for ((i = 0; i < ${#valids[@]}; i++)); do
		curtest=${valids[i]}
		if ! parse_index_from_signing_key_path "$curtest" actual_index; then
			failures+=("Expected valid: $curtest")
		else
			expected_index="$i"
			if [[ $actual_index -ne $i ]]; then
				failures+=("Expected index $expected_index but found $actual_index [$curtest]")
			fi
		fi
	done

	for ((i = 0; i < ${#invalids[@]}; i++)); do
		curtest=${invalids[i]}
		if parse_index_from_signing_key_path "$curtest" actual_index 2>/dev/null; then
			expected_index="$i"
			if [[ $actual_index -eq $i ]]; then
				failures+=("Invalid path [$curtest] found unexpectedly valid index of $actual_index")
			fi
		fi
	done
}

# tests for `$regex_eth_addr` in common.sh
function test_regex_eth_addr() {
	local valids=(
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f'
		'0x0123456789abcdefABCDEF01234567890abcdef0'
		'0x0000000000000000000000000000000000000000'
		'0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
	)
	local invalids=(
		'0x0123456789abcdefABCDEF01234567890abcdef0,0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f'                                            # csv
		'0x0123456789abcdefABCDEF01234567890abcdef0,0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f,0x0123456789abcdefABCDEF01234567890abcdef0' # csv
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068'                                                                                        # too short
		'0xZEBRA123FAACf8071bd4bb5AB99Db01938090689'                                                                                       # invalid characters
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f1'                                                                                      # too long
		'f19B1c91FAACf8071bd4bb5AB99Db0193809068f1'                                                                                        # missing 0x
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

# tests for `$regex_eth_validator_pubkey` in common.sh
function test_regex_eth_validator_pubkey() {
	local valids=(
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270b'
		'0x0123456789abcdefABCDEF01234567890abcdef00123456789abcdefABCDEF01234567890abcdef00123456789abcdef'
		'0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
		'0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
	)
	local invalids=(
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,0x0123456789abcdefABCDEF01234567890abcdef00123456789abcdefABCDEF01234567890abcdef00123456789abcdef' # csv
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f'                                                                                                                                                            # too short
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540ZEBRA'                                                                                                    # invalid characters
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B1'                                                                                                   # too long
		'a90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B'                                                                                                      # missing 0x
	)
	local curtest
	local i

	for ((i = 0; i < ${#valids[@]}; i++)); do
		curtest=${valids[i]}
		if [[ ! $curtest =~ $regex_eth_validator_pubkey ]]; then
			failures+=("Expected valid: $curtest")
		fi
	done

	for ((i = 0; i < ${#invalids[@]}; i++)); do
		curtest=${invalids[i]}
		if [[ $curtest =~ $regex_eth_validator_pubkey ]]; then
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
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068'                                              # too short
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068,0x0123456789abcdefABCDEF01234567890abcdefg'   # too short csv
		'0xZEBRA123FAACf8071bd4bb5AB99Db01938090689'                                             # invalid characters
		'0xf19B1c91FAACf8071bd4bb5AB99Db0193809068f1'                                            # too long
		'f19B1c91FAACf8071bd4bb5AB99Db0193809068f1'                                              # missing 0x
		'f19B1c91FAACf8071bd4bb5AB99Db0193809068f,f19B1c91FAACf8071bd4bb5AB99Db0193809068f'      # missing 0x csv
		'0x0123456789abcdefABCDEF01234567890abcdef0,0x0x0123456789abcdefABCDEF01234567890abcde'  # too many 0x
		',0x0123456789abcdefABCDEF01234567890abcdef0,0x0123456789abcdefABCDEF01234567890abcdef0' # leading comma
		'0x0123456789abcdefABCDEF01234567890abcdef0 0x0123456789abcdefABCDEF01234567890abcdef0'  # spaced not csv
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

# tests for `$regex_eth_validator_pubkey_csv` in common.sh
function test_regex_eth_validator_pubkey_csv() {
	local valids=(
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B'
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,0x0123456789abcdefABCDEF01234567890abcdef00123456789abcdefABCDEF01234567890abcdef00123456789abcdef'
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,0x0123456789abcdefABCDEF01234567890abcdef00123456789abcdefABCDEF01234567890abcdef00123456789abcdef'
	)
	local invalids=(
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270'                                                                                                      # too short
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270,0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270'    # too short csv
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540ZEBRA'                                                                                                     # invalid characters
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B1'                                                                                                    # too long
		'a90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B'                                                                                                       # missing 0x
		'a90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,a90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B'      # missing 0x csv
		'0x0x0fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,0x0x0fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B'  # too many 0x
		',0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B,0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B' # leading comma
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B 0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B'  # spaced not csv
		'0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B, 0xa90fdc2762f674332536dff57c4669e022c42881a600d2d5c1cb9b8b951fce3df0a209a7a97802302f55fdd2540d270B' # csv plus space
	)
	local curtest
	local i

	for ((i = 0; i < ${#valids[@]}; i++)); do
		curtest=${valids[i]}
		if [[ ! $curtest =~ $regex_eth_validator_pubkey_csv ]]; then
			failures+=("Expected valid: $curtest")
		fi
	done

	for ((i = 0; i < ${#invalids[@]}; i++)); do
		curtest=${invalids[i]}
		if [[ $curtest =~ $regex_eth_validator_pubkey_csv ]]; then
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
		if ! echo "$curtest" | continue_or_exit 3; then
			failures+=("Expected 'yes' (${curtest:-"<blank>"})")
		fi
	done

	for ((i = 0; i < ${#nos[@]}; i++)); do
		curtest=${nos[i]}
		echo "$curtest" | continue_or_exit 3
		if [[ $? -ne 3 ]]; then
			failures+=("Expected 'no' (${curtest:-"<blank>"})")
		fi
	done
}

# tests for `get_latest_prysm_version()` in common.sh
function test_get_latest_prysm_version() {
	local _
	if ! get_latest_prysm_version _ &>/dev/null; then
		failures+=("failed to get latest prysm version")
	fi
}

# tests for "download_prysm" in common.sh
function test_download_prysm() {
	local program="beacon-chain" version="v5.1.0"
	local expected="${program}-${version}-linux-amd64" actual
	if ! download_prysm $program $version actual; then
		failures+=("failed to download prysm")
	elif [[ $expected != "$actual" ]]; then
		failures+=("expected: $expected, actual: $actual")
	elif [[ ! -f $expected ]]; then
		failures+=("downloaded file not found: $expected")
	fi

	program="non-existent-program"
	expected="${program}-${version}-linux-amd64"
	if download_prysm $program $version actual &>/dev/null; then
		failures+=("failed to err on non-existent program")
	fi
}

function test_download_ethdo() {
	local version='v1.37.4' sha256='a133b5d284f5fb2e6c4406764cae3f0cbb49355edf01081befda132af651c344'
	local expected='ethdo-1.37.4-linux-amd64.tar.gz' actual
	if ! download_wealdtech ethdo $version $sha256 actual; then
		failures+=("failed to download ethdo")
	elif [[ $expected != "$actual" ]]; then
		failures+=("expected: $expected, actual: $actual")
	elif [[ ! -f $expected ]]; then
		failures+=("downloaded file not found: $expected")
	fi
}

function test_download_ethereal() {
	local version='v2.11.5' sha256='ed4cc43fc35c16264f21a163fd3ffc0d4cefc79916984ab6718c9a847cd08f8f'
	local expected='ethereal-2.11.5-linux-amd64.tar.gz' actual
	if ! download_wealdtech ethereal $version $sha256 actual; then
		failures+=("failed to download ethereal")
	elif [[ $expected != "$actual" ]]; then
		failures+=("expected: $expected, actual: $actual")
	elif [[ ! -f $expected ]]; then
		failures+=("downloaded file not found: $expected")
	fi
}

function test_download_mevboost() {
	local version='v1.9' sha256='2056f87e1b0f100c8d6ef9c85abe0e2d5dfb520cb1819237861b0cfa4394736f'  
	local expected='mev-boost_1.9_linux_amd64.tar.gz' actual
	if ! download_mevboost $version $sha256 actual; then
		failures+=("failed to download mevboost")
	elif [[ $expected != "$actual" ]]; then
		failures+=("expected: $expected, actual: $actual")
	elif [[ ! -f $expected ]]; then
		failures+=("downloaded file not found: $expected")
	fi
}

# test for check_directory_does_not_exist() in common.sh
function test_check_directory_does_not_exist() {
	local exists_arr=(
		'./tempdir1/'
		'./tempdir2/zebra'
	)
	local exists_root_arr=(
		'./tempdir3/'
		'./tempdir4/zebra'
	)
	local not_exist_arr=(
		'./tempdir5/'
		'./tempdir6/zebra'
	)
	local not_exist_root_arr=(
		'./tempdir7/'
		'./tempdir8/zebra'
	)
	local curtest i len

	# exists
	reset_checks
	len=${#exists_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_arr[i]}"
		mkdir -p "$curtest"
		check_directory_does_not_exist curtest
	done
	_expect_checkfailures "$len"

	# exists, owned by root
	reset_checks
	len=${#exists_root_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_root_arr[i]}"
		sudo mkdir -p "$curtest"
		check_directory_does_not_exist --sudo curtest
	done
	_expect_checkfailures "$len"

	# not exist
	reset_checks
	len=${#not_exist_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${not_exist_arr[i]}"
		check_directory_does_not_exist curtest
	done
	_dont_expect_checkfailures

	# not exist, owned by root
	reset_checks
	for ((i = 0; i < ${#not_exist_root_arr[@]}; i++)); do
		curtest="${not_exist_root_arr[i]}"
		check_directory_does_not_exist --sudo curtest
	done
	_dont_expect_checkfailures
}

# test for check_directory_exists() in common.sh
function test_check_directory_exists() {
	local exists_arr=(
		'./tempdir1/'
		'./tempdir2/zebra'
	)
	local exists_root_arr=(
		'./tempdir3/'
		'./tempdir4/zebra'
	)
	local not_exist_arr=(
		'./tempdir5/'
		'./tempdir6/zebra'
	)
	local not_exist_root_arr=(
		'./tempdir7/'
		'./tempdir8/zebra'
	)
	local curtest i len

	# exists
	reset_checks
	len=${#exists_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_arr[i]}"
		mkdir -p "$curtest"
		check_directory_exists curtest
	done
	_dont_expect_checkfailures

	# exists, owned by root
	reset_checks
	len=${#exists_root_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${exists_root_arr[i]}"
		sudo mkdir -p "$curtest"
		check_directory_exists --sudo curtest
	done
	_dont_expect_checkfailures

	# not exist
	reset_checks
	len=${#not_exist_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${not_exist_arr[i]}"
		check_directory_exists curtest
	done
	_expect_checkfailures "$len"

	# not exist, owned by root
	reset_checks
	len=${#not_exist_root_arr[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${not_exist_root_arr[i]}"
		check_directory_exists --sudo curtest
	done
	_expect_checkfailures "$len"
}

# test for check_file_does_not_exist() in common.sh
function test_check_file_does_not_exist() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	check_file_does_not_exist curtest
	_expect_checkfailures 1

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	check_file_does_not_exist --sudo curtest
	_expect_checkfailures 1

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_file_does_not_exist curtest
	_dont_expect_checkfailures

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_file_does_not_exist --sudo curtest
	_dont_expect_checkfailures
}

# test for check_file_exists() in common.sh
function test_check_file_exists() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	check_file_exists curtest
	_dont_expect_checkfailures

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	check_file_exists --sudo curtest
	_dont_expect_checkfailures

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_file_exists curtest
	_expect_checkfailures 1

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_file_exists --sudo curtest
	_expect_checkfailures 1
}

# test for check_executable_does_not_exist() in common.sh
function test_check_executable_does_not_exist() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	chmod +x "$curtest"
	check_executable_does_not_exist curtest
	_expect_checkfailures 1

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	sudo chmod +x "$curtest"
	check_executable_does_not_exist --sudo curtest
	_expect_checkfailures 1

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_executable_does_not_exist curtest
	_dont_expect_checkfailures

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_executable_does_not_exist --sudo curtest
	_dont_expect_checkfailures
}

# test for check_executable_exists() in common.sh
function test_check_executable_exists() {
	local exists='./parent1/child1'
	local exists_root='./parent2/child2'
	local not_exist='./parent3/child3'
	local not_exist_root='./parent4/child4'
	local curtest

	# exists
	reset_checks
	mkdir -p "$exists"
	curtest="$exists/zebra_exists"
	touch "$curtest"
	chmod +x "$curtest"
	check_executable_exists curtest
	_dont_expect_checkfailures

	# exists, owned by root
	reset_checks
	sudo mkdir -p "$exists_root"
	curtest="$exists_root/zebra_exists_root"
	sudo touch "$curtest"
	sudo chmod +x "$curtest"
	check_executable_exists --sudo curtest
	_dont_expect_checkfailures

	# not exist
	reset_checks
	mkdir -p "$not_exist"
	curtest="$not_exist/zebra_not_exist"
	check_executable_exists curtest
	_expect_checkfailures 1

	# not exist, owned by root
	reset_checks
	sudo mkdir -p "$not_exist_root"
	curtest="$not_exist_root/zebra_not_exist_root"
	check_executable_exists --sudo curtest
	_expect_checkfailures 1
}

function test_check_is_valid_ipv4_address() {
	local valid=(
		'192.168.1.50'
		'255.255.255.0'
		'10.10.0.42'
	)
	local invalid=(
		'2600:8801:9a00:c:8aff:8ec2:f651'
		'256.1.1.1'
		'google.com'
	)
	local i curtest len

	# valid
	reset_checks
	len=${#valid[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${valid[i]}"
		check_is_valid_ipv4_address curtest
	done
	_dont_expect_checkfailures

	# invalid
	reset_checks
	len=${#invalid[@]}
	for ((i = 0; i < len; i++)); do
		curtest="${invalid[i]}"
		check_is_valid_ipv4_address curtest
	done
	_expect_checkfailures "$len"
}

# -------------------------- TEST DRIVER --------------------------------------

assert_sudo

run_test test_regex_eth_addr
run_test test_regex_eth_addr_csv
run_test test_regex_eth_validator_pubkey
run_test test_regex_eth_validator_pubkey_csv
run_test test_parse_index_from_signing_key_path
run_test test_yes_or_no
run_test test_continue_or_exit
run_test test_get_latest_prysm_version
run_test test_download_prysm
run_test test_download_ethdo
run_test test_download_ethereal
run_test test_download_mevboost
run_test test_check_directory_does_not_exist
run_test test_check_directory_exists
run_test test_check_file_does_not_exist
run_test test_check_file_exists
run_test test_check_executable_does_not_exist
run_test test_check_executable_exists
run_test test_check_is_valid_ipv4_address
