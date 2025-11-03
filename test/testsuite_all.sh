#!/bin/bash

# test_suite_all.sh
#
# Runs all tests defined in `./test/testcases.sh`

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
export this_dir

function test_in_subshell() ( # subshell
	source "$this_dir/testcases.sh"
	run_test "$1"
)

# sudo authenticate up front for tests that require it
sudo true

# test state isolation enforced by one-test-per-subshell
test_in_subshell test_regex_eth_addr
test_in_subshell test_regex_eth_addr_csv
test_in_subshell test_regex_eth_validator_pubkey
test_in_subshell test_regex_eth_validator_pubkey_csv
test_in_subshell test_parse_index_from_signing_key_path
test_in_subshell test_get_latest_prysm_version
test_in_subshell test_download_prysm
test_in_subshell test_download_ethdo
test_in_subshell test_download_ethereal
test_in_subshell test_download_mevboost
