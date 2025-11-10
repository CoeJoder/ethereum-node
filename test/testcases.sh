#!/bin/bash

# tests.sh
#
# Runs unit and integration tests.

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

# import script under test (which imports `bash-tools`)
source "$this_dir/../src/common.sh"

# import `bash-tools` test framework
source "$this_dir/../external/bash-tools/test/test_framework.sh"

# .env setup
housekeeping
set_loglevel 'info'

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
