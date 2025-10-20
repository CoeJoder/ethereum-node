#!/bin/bash

# common.sh
#
# A project-wide library of constants and utility functions.

# -------------------------- HEADER -------------------------------------------

# this file is sourced, so `export` is not required
# shellcheck disable=SC2034

# propagate top-level ERR traps to subcontexts
set -E

# enable extended globbing
shopt -s extglob

# -------------------------- CONSTANTS ----------------------------------------

# the 'src' folder is renamed to the following on deployment
dist_dirname='ethereum-node'

# supported networks
testnet='hoodi'
mainnet='mainnet'

# set paths based on dev or prod environment
common_sh_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
if [[ $(basename "$common_sh_dir") == "$dist_dirname" ]]; then
	# prod
	proj_dir="$common_sh_dir"
	src_dir="$proj_dir"
	external_dir="$proj_dir/external"
else
	# dev
	proj_dir="$(realpath "$common_sh_dir/..")"
	src_dir="$proj_dir/src"
	external_dir="$proj_dir/external"
	tools_dir="$proj_dir/tools"
	test_dir="$proj_dir/test"
fi

# import external libs
source "$external_dir/bash-tools/src/bash-tools.sh"

# project files
log_file="$proj_dir/log.txt"
log_file_previous="$proj_dir/log-previous.txt"
env_base_sh="$src_dir/env-base.sh"
env_sh="$src_dir/env.sh"

# log rotation threshold
max_log_size=2097152 # 2 MB

# common `jq` filters
filter_all='.[] | {
	index,
	status,
	balance,
	pubkey: .validator.pubkey,
	bls_withdrawal_credentials: .validator.withdrawal_credentials
}'
filter_active='.[] | select(.status == "active_ongoing") | {
	index,
	status,
	balance,
	pubkey: .validator.pubkey,
	bls_withdrawal_credentials: .validator.withdrawal_credentials
}'
filter_active_indices='.[] | select(.status == "active_ongoing") |
	.index'
filter_active_pubkeys='.[] | select(.status == "active_ongoing") |
	.validator.pubkey'
filter_all_pubkeys='.[] |
	.validator.pubkey'
filter_active_bls_withdrawal_credentials='.[] | select(.status == "active_ongoing") |
	.validator.withdrawal_credentials'

# e.g., "0xAbC123"
regex_eth_addr='^0x[[:xdigit:]]{40}$'

# e.g., "0xAbC123,0xdEf456"
regex_eth_addr_csv='^0x[[:xdigit:]]{40}(,0x[[:xdigit:]]{40})*$'

# unsigned integer regex e.g., for single validator index
regex_uint='^[[:digit:]]+$'

# e.g., 183526,182347
regex_eth_validator_indices_csv='^[[:digit:]]+(,[[:digit:]]+)*$'

regex_eth_validator_pubkey='^0x[[:xdigit:]]{96}$'
regex_eth_validator_pubkey_v2='^[[:xdigit:]]{96}$'

regex_eth_validator_pubkey_csv='^0x[[:xdigit:]]{96}(,0x[[:xdigit:]]{96})*$'
regex_eth_validator_pubkey_csv_v2='^[[:xdigit:]]{96}(,[[:xdigit:]]{96})*$'

regex_eth_validator_bls_withdrawal_credentials='^0x[[:xdigit:]]{64}$'

# see: https://eips.ethereum.org/EIPS/eip-2334#validator-keys
regex_eth_validator_signing_key_path='m/12381/3600/([[:digit:]]+)/0/0'

# prompted by the EthStaker Deposit CLI
regex_keystore_password='^.{8,}$'
errmsg_keystore_password='expected a valid keystore password of at least 8-digits'

# generic error messages to display on ERR trap
errmsg_noretry="\nSomething went wrong.  Send ${theme_filename}log.txt${color_reset} to the HGiC (Head Geek-in-Charge)"
errmsg_retry="$errmsg_noretry, or just try it again and don't screw it up this time ;)"

# -------------------------- UTILITIES ----------------------------------------

# script init tasks
function housekeeping() {
	log_start
	log_timestamp
	set_env
}

# set the project environment variables
function set_env() {
	reset_checks
	check_executable_exists env_base_sh
	print_failed_checks --error || exit
	# shellcheck source=./env-base.sh
	source "$env_base_sh"

	# warn if private env is missing but don't exit
	reset_checks
	check_executable_exists env_sh
	if print_failed_checks --warn; then
		# shellcheck source=./env.sh
		source "$env_sh"
	else
		press_any_key_to_continue
	fi
}

# append to log file
# shellcheck disable=SC2120  # optional args
function log_timestamp() {
	local _file="$log_file"
	if [[ $# -gt 0 ]]; then
		_file="$1"
	fi
	echo -e "\n$(get_timestamp)" >>"$_file"
}

# rotate log file if necessary and begin logging terminal output
function log_start() {
	local log_size
	if [[ -f $log_file ]]; then
		log_size=$(stat -c %s "$log_file")
		if [[ $log_size -ge $max_log_size ]]; then
			printwarn "log file ≥ $max_log_size B"
			if yes_or_no --default-yes "Rotate log?"; then
				mv -vf "$log_file" "$log_file_previous"
				echo -e "Log rotated: $log_file_previous" >>"$log_file"
			fi
		fi
	fi
	log_resume
}

# restore stdout & stderr
function log_pause() {
	echo -e "[Logging paused] $*" >>"$log_file"
	exec 1>&3 2>&4
}

# backup stdout & stderr, and redirect both to tee'd logfile
# shellcheck disable=SC2120  # optional args
function log_resume() {
	exec 3>&1 4>&2
	exec &> >(tee -a "$log_file")
	echo -e "[Logging resumed] $*" >>"$log_file"
}

# callback for ERR trap with a 'retry' msg
function on_err_retry() {
	on_err $? "at line $(caller): $errmsg_retry"
}

# callback for ERR trap without a 'noretry' msg
function on_err_noretry() {
	on_err $? "at line $(caller): $errmsg_noretry"
}

# get the latest EthStaker Deposit CLI release version
function get_latest_deposit_cli_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_deposit_cli_version outvar"
		return 2
	fi
	local outvar="$1"
	get_latest_github_release "ethstaker/ethstaker-deposit-cli" "$outvar"
}

# get the latest prysm release version
function get_latest_prysm_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_prysm_version outvar"
		return 2
	fi
	local outvar="$1"
	get_latest_github_release "OffchainLabs/prysm" "$outvar"
}

# get the latest ethdo release version
function get_latest_ethdo_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_ethdo_version outvar"
		return 2
	fi
	local outvar="$1"
	get_latest_github_release "wealdtech/ethdo" "$outvar"
}

# get the latest ethereal release version
function get_latest_ethereal_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_ethereal_version outvar"
		return 2
	fi
	local outvar="$1"
	get_latest_github_release "wealdtech/ethereal" "$outvar"
}

# get the latest mevboost release version
function get_latest_mevboost_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_mevboost_version outvar"
		return 2
	fi
	local outvar="$1"
	get_latest_github_release "flashbots/mev-boost" "$outvar"
}

function download_jq() {
	if [[ $# -ne 3 ]]; then
		printerr "usage: download_jq jq_bin jq_bin_sha256 version"
		return 3
	fi
	local program_bin="$1" program_bin_sha256="$2" version="$3"
	local program_bin_url="https://github.com/jqlang/jq/releases/download/${version}/${program_bin}"
	local all_sha256="sha256sum.txt"
	local all_sha256_url="https://github.com/jqlang/jq/releases/download/${version}/${all_sha256}"
	download_file "$program_bin_url" || return
	download_file "$all_sha256_url" || return

	# all checksums are in a single file; we will filter it
	grep --color=never "$program_bin" "$all_sha256" >"$program_bin_sha256"
	shasum -a 256 -c "$program_bin_sha256" || return
}

# download and checksum a prysm program from the GitHub release page,
# and assign the bin filename to the given `outvar`
function download_prysm() {
	if [[ $# -ne 3 ]]; then
		printerr "usage: download_prysm program version outvar"
		return 2
	fi
	local program="$1" version="$2" outvar="$3"
	local program_bin="${program}-${version}-linux-amd64"
	local program_bin_url="https://github.com/OffchainLabs/prysm/releases/download/${version}/${program_bin}"
	local program_bin_sha256="${program}-${version}-linux-amd64.sha256"
	local program_bin_sha256_url="https://github.com/OffchainLabs/prysm/releases/download/${version}/${program_bin_sha256}"
	download_file "$program_bin_url" || return
	download_file "$program_bin_sha256_url" || return
	shasum -a 256 -cq "$program_bin_sha256" || return
	printf -v "$outvar" "%s" "$program_bin"
}

function download_wealdtech() {
	if [[ $# -ne 4 || ($1 != 'ethdo' && $1 != 'ethereal') ]]; then
		printerr "usage: download_wealdtech {ethdo|ethereal} version sha256_checksum outvar"
		return 2
	fi
	local program="$1" version="$2" sha256_checksum="$3" outvar="$4"
	# filenames exclude the first 'v' of version string
	local program_bin="${program}-${version:1}-linux-amd64.tar.gz"
	local program_bin_url="https://github.com/wealdtech/${program}/releases/download/${version}/${program_bin}"
	local program_bin_sha256="${program}-${version:1}-linux-amd64.tar.gz.sha256"
	local program_bin_sha256_url="https://github.com/wealdtech/${program}/releases/download/${version}/${program_bin_sha256}"
	download_file "$program_bin_url" || return

	# expected checksum should match downloaded checksum
	fetched_sha265="$(wget -qO - "$program_bin_sha256_url" | cat)"
	if [[ $fetched_sha265 != "$sha256_checksum" ]]; then
		printerr "Found: $fetched_sha265\nExpected: $sha256_checksum\n" \
			"Ensure that ${theme_value}${program}_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
		return 1
	fi
	echo "$sha256_checksum  $program_bin" | shasum -a 256 -cq - || return
	printf -v "$outvar" "%s" "$program_bin"
}

function download_mevboost() {
	if [[ $# -ne 3 ]]; then
		printerr "usage: download_mevboost version sha256_checksum outvar"
		return 2
	fi
	local version="$1" sha256_checksum="$2" outvar="$3"
	local program_bin="mev-boost_${version:1}_linux_amd64.tar.gz"
	local program_bin_url="https://github.com/flashbots/mev-boost/releases/download/${version}/${program_bin}"
	local program_bin_checksums_txt_url="https://github.com/flashbots/mev-boost/releases/download/${version}/checksums.txt"
	download_file "$program_bin_url" || return

	# checksum against the fetched value
	shasum --ignore-missing -a 256 -cq - < <(wget -qO - "$program_bin_checksums_txt_url") || return

	# checksum against the locally-saved value
	if ! echo "$sha256_checksum  $program_bin" | shasum -a 256 -cq -; then
		printerr "Checksum failed against locally-saved value!\n" \
			"Ensure that ${theme_value}mevboost_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
		return 1
	fi
	printf -v "$outvar" "%s" "$program_bin"
}

# downloads and installs a given version of a prysm program
function install_prysm() {
	if [[ $# -ne 5 ]]; then
		printerr "usage: install_prysm program version destination_bin owner group"
		return 2
	fi
	local program="$1" version="$2" destination_bin="$3" owner="$4" group="$5"
	local downloaded_bin
	download_prysm "$program" "$version" downloaded_bin || return
	sudo chown -v "${owner}:${group}" "$downloaded_bin" || return
	sudo chmod -v 550 "$downloaded_bin" || return
	sudo mv -vf "$downloaded_bin" "$destination_bin" || return
}

# downloads, extracts, and installs a given version of a wealdtech program
function install_wealdtech() {
	if [[ $# -ne 6 || ($1 != 'ethdo' && $1 != 'ethereal') ]]; then
		printerr "usage: install_wealdtech {ethdo|ethereal} version sha256_checksum destination_bin owner group"
		return 2
	fi
	local program="$1" version="$2" sha256_checksum="$3" destination_bin="$4" owner="$5" group="$6"
	local downloaded_tar
	download_wealdtech "$program" "$version" "$sha256_checksum" downloaded_tar || return
	tar xvzf "$downloaded_tar" || return
	sudo chown -v "${owner}:${group}" "./$program" || return
	sudo chmod -v 550 "./$program" || return
	sudo mv -vf "./$program" "$destination_bin" || return
}

# downloads, extracts, and installs a given version of MEV-Boost
function install_mevboost() {
	if [[ $# -ne 5 ]]; then
		printerr "usage: install_mevboost version sha256_checksum destination_bin owner group"
		return 2
	fi
	local version="$1" sha256_checksum="$2" destination_bin="$3" owner="$4" group="$5"
	local downloaded_tar
	download_mevboost "$version" "$sha256_checksum" downloaded_tar || return
	tar xvzf "$downloaded_tar" || return
	sudo chown -v "${owner}:${group}" "./mev-boost" || return
	sudo chmod -v 550 "./mev-boost" || return
	sudo mv -vf "./mev-boost" "$destination_bin" || return
}

# parses the index number from a validator signing key path per EIP-2334
# e.g. 'm/12381/3600/4/0/0' yields '4'
function parse_index_from_signing_key_path() {
	if [[ $# -ne 2 ]]; then
		printerr "usage: parse_index_from_signing_key_path signing_key_path outvar"
		return 2
	fi
	local signing_key_path="$1" outvar="$2"
	if [[ ! $signing_key_path =~ $regex_eth_validator_signing_key_path ]]; then
		printerr "unrecognized signing key path: $signing_key_path" >&2
		return 1
	fi
	printf -v "$outvar" "%s" "${BASH_REMATCH[1]}"
}

# true for non-deployed environment
function is_devmode() {
	[[ -n $tools_dir ]] &>/dev/null
}

function beaconchain_base_url() {
	if (($# != 2)); then
		printerr "usage: beaconchain_base_url network outvar"
		return 2
	fi
	local network="$1" outvar="$2"
	local beaconchain_url_subdomain=""
	if [[ $network != "$mainnet" ]]; then
		beaconchain_url_subdomain="${network}."
	fi
	printf -v "$outvar" "%s" "https://${beaconchain_url_subdomain}beaconcha.in"
}

# -------------------------- ASSERTIONS ---------------------------------------

# assert that script process is running on the node server
function assert_on_node_server() {
	assert_on_host "$node_server_hostname"
}

# assert that script process is not running on the node server
function assert_not_on_node_server() {
	assert_not_on_host "$node_server_hostname"
}

# -------------------------- CHECKS -------------------------------------------

function check_is_valid_ethereum_network() {
	if _check_is_defined "$1"; then
		if [[ ${!1} != "$mainnet" && ${!1} != "$testnet" ]]; then
			_check_failures+=("invalid Ethereum network: ${!1}")
		fi
	fi
}

function check_is_valid_ethereum_address() {
	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ $regex_eth_addr ]]; then
			_check_failures+=("invalid Ethereum address: ${!1}")
		fi
	fi
}

function check_is_valid_validator_mnemonic() {
	if _check_is_defined "$1"; then
		if [[ $(printf '%s' "${!1}" | wc -w) -ne 24 ]]; then
			_check_failures+=("$1: expected a 24-word seed phrase")
		fi
	fi
}

function check_is_valid_validator_index_or_pubkey() {
	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ $regex_uint && ! ${!1} =~ $regex_eth_validator_pubkey ]]; then
			_check_failures+=("$1: expected a validator index or pubkey")
		fi
	fi
}

function check_is_valid_validator_pubkeys() {
	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ $regex_eth_validator_pubkey_csv && ! ${!1} =~ $regex_eth_validator_pubkey_csv_v2 ]]; then
			_check_failures+=("$1: expected a comma-separated list of validator pubkeys")
		fi
	fi
}

function check_is_valid_eip2334_index() {
	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ ^[[:digit:]]+$ || ! ${!1} -ge 0 ]]; then
			_check_failures+=("$1: expected a valid EIP-2334 index ≥ 0")
		fi
	fi
}

function check_is_valid_keystore_password() {
	if _check_is_defined "$1"; then
		if [[ ! ${!1} =~ $regex_keystore_password ]]; then
			_check_failures+=("$1: $errmsg_keystore_password")
		fi
	fi
}

# -------------------------- FOOTER -------------------------------------------

# this script should be sourced rather than executed directly
assert_sourced
