#!/bin/bash

# common.sh
#
# A library of constants and utility functions used throughout the project.

# -------------------------- HEADER -------------------------------------------

# propagate top-level ERR traps to subcontexts
set -E

# -------------------------- CONSTANTS ----------------------------------------

# the 'src' folder is renamed to the following on deployment
dist_dirname='ethereum-node'

# set paths based on dev or prod environment
common_sh_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
if [[ $(basename "$common_sh_dir") == $dist_dirname ]]; then
	# prod
	proj_dir="$common_sh_dir"
	src_dir="$common_sh_dir"
else
	# dev
	proj_dir="$(realpath "$common_sh_dir/..")"
	src_dir="$proj_dir/src"
	tools_dir="$proj_dir/tools"
	test_dir="$proj_dir/test"
fi

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

# e.g. "0xAbC123"
regex_eth_addr='^0x[[:xdigit:]]{40}$'

# e.g. "0xAbC123,0xdEf456"
regex_eth_addr_csv='^0x[[:xdigit:]]{40}(,0x[[:xdigit:]]{40})*$'

# e.g., 183526,182347
regex_eth_validator_indices_csv='^[[:digit:]]+(,[[:digit:]]+)*$'

regex_eth_validator_pubkey='^0x[[:xdigit:]]{96}$'
regex_eth_validator_pubkey_v2='^[[:xdigit:]]{96}$'

regex_eth_validator_pubkey_csv='^0x[[:xdigit:]]{96}(,0x[[:xdigit:]]{96})*$'
regex_eth_validator_pubkey_csv_v2='^[[:xdigit:]]{96}(,[[:xdigit:]]{96})*$'

regex_eth_validator_bls_withdrawal_credentials='^0x[[:xdigit:]]{64}$'

# see: https://eips.ethereum.org/EIPS/eip-2334#validator-keys
regex_eth_validator_signing_key_path='m/12381/3600/([[:digit:]]+)/0/0'

# prompted by the staking deposit CLI
regex_keystore_password='^.{8,}$'
errmsg_keystore_password='expected a valid keystore password of at least 8-digits'

# set colors only if tput is available
if [[ $(command -v tput && tput setaf 1 2>/dev/null) ]]; then
	color_red=$(tput setaf 1)
	color_green=$(tput setaf 2)
	color_yellow=$(tput setaf 3)
	color_blue=$(tput setaf 4)
	color_magenta=$(tput setaf 5)
	color_cyan=$(tput setaf 6)
	color_white=$(tput setaf 7)
	color_lightgray=$(tput setaf 245)
	color_reset=$(tput sgr0)
	bold=$(tput bold)
	theme_filename="${color_green}"
	theme_value="${color_green}"
	theme_url="${color_blue}"
	theme_command="${color_lightgray}"
	theme_example="${color_lightgray}"
fi

# generic error messages to display on ERR trap
errmsg_noretry="\nSomething went wrong.  Send ${theme_filename}log.txt${color_reset} to the HGiC (Head Geek-in-Charge)"
errmsg_retry="$errmsg_noretry, or just try it again and don't screw it up this time ;)"

# custom sudo-prompt which includes hostname
sudo_prompt_with_hostname='[sudo] password for %u@%H: '

# -------------------------- UTILITIES ----------------------------------------

# script init tasks
function housekeeping() {
	log_start
	log_timestamp
	set_env
}

# set the project environment variables
function set_env() {
	check_executable_exists env_base_sh
	print_failed_checks --error || exit
	source "$env_base_sh"

	# warn if private env is missing but don't exit
	check_executable_exists env_sh
	if print_failed_checks --warn; then
		source "$env_sh"
	else
		press_any_key_to_continue
	fi
}

# append to log file
function log_timestamp() {
	local _file="$log_file"
	if [[ $# -gt 0 ]]; then
		_file="$1"
	fi
	echo -e "\n$(date "+%m-%d-%Y, %r")" >>"$_file"
}

# rotate log file if necessary and begin logging terminal output
function log_start() {
	if [[ -f $log_file ]]; then
		local log_size=$(stat -c %s "$log_file")
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
	echo -e "[Logging paused] $@" >>"$log_file"
	exec 1>&3 2>&4
}

# backup stdout & stderr, and redirect both to tee'd logfile
function log_resume() {
	exec 3>&1 4>&2
	exec &> >(tee -a "$log_file")
	echo -e "[Logging resumed] $@" >>"$log_file"
}

# common logging suffix for INFO messages
function print_ok() {
	echo "${color_green}OK${color_reset}" >&2
}

# INFO log-level message to stderr
function printinfo() {
	local echo_opts='-e'
	if [[ $1 == '-n' ]]; then
		echo_opts='-en'
		shift
	fi
	echo $echo_opts "${color_green}INFO ${color_reset}$@" >&2
}

# WARN log-level message to stderr
function printwarn() {
	local echo_opts='-e'
	if [[ $1 == '-n' ]]; then
		echo_opts='-en'
		shift
	fi
	echo $echo_opts "${color_yellow}WARN ${color_reset}$@" >&2
}

# ERROR log-level message, with optional error code, to stderr
# examples:
#   `printerr "failed to launch"`
#   `printerr 2 "failed to launch"`
function printerr() {
	local code=$? msg
	if [[ $# -eq 2 ]]; then
		code=$1
		msg="$2"
		echo -e "${color_red}ERROR ${code}${color_reset} $msg" >&2
	elif [[ $# -eq 1 ]]; then
		msg="$1"
		echo -e "${color_red}ERROR${color_reset} $msg" >&2
	else
		echo "${color_red}ERROR${color_reset} usage: printerr [code] msg" >&2
		exit 2
	fi
}

# callback for ERR trap
# examples:
#   `trap 'on_err' ERR
#   `trap 'on_err "failed to launch"' ERR`
#   `trap 'on_err 2 "failed to launch"' ERR`
function on_err() {
	local exit_status=$?
	local msg="at line $(caller)"
	if [[ $# -eq 2 ]]; then
		exit_status=$1
		msg="$2"
	elif [[ $# -eq 1 ]]; then
		exit_status=$1
	fi
	printerr $exit_status "$msg"
	exit $exit_status
}

# callback for ERR trap with a 'retry' msg
function on_err_retry() {
	on_err $? "at line $(caller): $errmsg_retry"
}

# callback for ERR trap without a 'noretry' msg
function on_err_noretry() {
	on_err $? "at line $(caller): $errmsg_noretry"
}

# `read` but allows a default value
function read_default() {
	if [[ $# -ne 3 ]]; then
		echo "usage: read_default description default_val outvar" >&2
		return 1
	fi
	local description="$1" default_val="$2" outvar="$3" val
	echo -e "${description} (default: ${theme_example}$default_val${color_reset}):${theme_value}"
	read val
	if [[ -z $val ]]; then
		val="$default_val"
		# cursor up 1, echo value
		echo -e "\e[1A${val}"
	fi
	echo -en "${color_reset}"
	printf -v $outvar "$val"
}

# `read` but stylized like `read_default`
function read_no_default() {
	if [[ $# -ne 2 ]]; then
		echo "usage: read_no_default description outvar" >&2
		return 1
	fi
	local description="$1" outvar="$2" val
	read -p "${description}: ${theme_value}" val
	echo -en "${color_reset}"
	printf -v $outvar "$val"
}

# get the latest version string/tag name from a github repo
# source: https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
function get_latest_release() {
	curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
		grep '"tag_name":' |                                             # Get tag line
		sed -E 's/.*"([^"]+)".*/\1/'                                     # Pluck JSON value
}

# factor; get the latest "vX.Y.Z" version of a GH project
function _get_latest_version() {
	if [[ $# -ne 2 ]]; then
		printerr "expected two arguments: ghproject, outvar"
		return 2
	fi
	local ghproject="$1" outvar="$2" version
	echo -en "Looking up latest '$ghproject' version..." >&2
	version="$(get_latest_release "$ghproject")"
	if [[ ! "$version" =~ v[0-9]\.[0-9]\.[0-9] ]]; then
		echo "${color_red}failed${color_reset}." >&2
		printerr "malformed version string: \"$version\""
		return 1
	fi
	echo -e "${theme_value}${version}${color_reset}" >&2
	printf -v "$outvar" "$version"
}

# get the latest Ethereum Staking Deposit CLI release version
function get_latest_deposit_cli_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_deposit_cli_version outvar"
		return 2
	fi
	local outvar="$1"
	_get_latest_version "ethereum/staking-deposit-cli" "$outvar"
}

# get the latest prysm release version
function get_latest_prysm_version() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_latest_prysm_version outvar"
		return 2
	fi
	local outvar="$1"
	_get_latest_version "prysmaticlabs/prysm" "$outvar"
}

# download a file silently (except on error) using `curl`
function download_file() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: download_file url"
		return 2
	fi
	local url="$1"
	if ! curl -fLOSs "$url"; then
		printerr "download failed: $url"
		return 1
	fi
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
	local program_bin_url="https://github.com/prysmaticlabs/prysm/releases/download/${version}/${program_bin}"
	local program_bin_sha256="${program}-${version}-linux-amd64.sha256"
	local program_bin_sha256_url="https://github.com/prysmaticlabs/prysm/releases/download/${version}/${program_bin_sha256}"
	download_file "$program_bin_url" || return
	download_file "$program_bin_sha256_url" || return
	shasum -a 256 -cq "$program_bin_sha256" || return
	printf -v "$outvar" "$program_bin"
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

# enable a system service
function enable_service() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: enable_service unit_file"
		return 2
	fi
	local unit_file="$1"
	local service_name="$(basename "$unit_file")"
	sudo systemctl start "$service_name"
	sudo systemctl enable "$service_name"
}

# disable a system service
function disable_service() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: disable_service unit_file"
		return 2
	fi
	local unit_file="$1"
	local service_name="$(basename "$unit_file")"
	sudo systemctl stop "$service_name"
	sudo systemctl disable "$service_name"
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
	printf -v $outvar "${BASH_REMATCH[1]}"
}

function enter_password_and_confirm() {
	if [[ $# -eq 4 ]]; then
		local prompt="$1" failmsg="$2" check_func="$3" outvar="$4"
	elif [[ $# -eq 2 ]]; then
		local prompt="$1" outvar="$2"
	else
		printerr "usage:\n\tenter_password_and_confirm prompt failmsg check_func outvar\n\tenter_password_and_confirm prompt outvar"
		return 2
	fi
	# loop until valid password
	while true; do
		read -sp "$prompt: " password1
		printf '\n'
		if [[ -z $check_func ]]; then
			break # no validator provided
		else
			reset_checks
			"$check_func" "password1"
			if has_failed_checks; then
				printwarn "$failmsg"
				reset_checks
			else
				break # success
			fi
		fi
	done
	# loop until confirmed
	while true; do
		read -sp "Re-enter to confirm: " password2
		printf '\n'
		if [[ $password1 != $password2 ]]; then
			printwarn "confirmation failed, try again"
		else
			break # success
		fi
	done
	printf -v "$outvar" "$password1"
}

# source: https://stackoverflow.com/a/53839433/159570
function join_arr() {
	local IFS="$1"
	shift
	echo "$*"
}

# count the number of files in the given directory (or . if ommitted)
function number_of_files() {
	local dir=${1:-.}
	find "$dir" -maxdepth 1 -type f -printf "." | wc -c
}

# test expression for user existence
function user_exists() {
	id "$1" &>/dev/null
}

# test expression for group existence
function group_exists() {
	getent group "$1" &>/dev/null
}

# test expression for substring existence
function string_contains() {
	[[ "$1" == *"$2"* ]] &>/dev/null
}

# test expression for network connectivity
# source: https://stackoverflow.com/a/14939373/159570
function is_online() {
	for interface in $(ls /sys/class/net/ | grep -v lo); do
		if [[ $(cat /sys/class/net/$interface/carrier 2>/dev/null) == 1 ]]; then
			return 0
		fi
	done
	return 1
}

function is_devmode() {
	[[ -n $tools_dir ]] &>/dev/null
}

# yes-or-no prompt
# 'no' is always falsey (returns 1)
function yes_or_no() {
	local confirm
	if [[ $# -ne 2 || ($1 != '--default-yes' && $1 != '--default-no') ]]; then
		printerr 'usage: yes_or_no {--default-yes|--default-no} prompt'
		exit 2
	fi
	if [[ $1 == '--default-yes' ]]; then
		read -p "$2 (Y/n): " confirm
		if [[ $confirm == [nN] || $confirm == [nN][oO] ]]; then
			return 1
		fi
	else
		read -p "$2 (y/N): " confirm
		if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
			return 1
		fi
	fi
}

# "Continue?" prompt, defaulting to no, exiting on 'no' with given code or 1 by default
function continue_or_exit() {
	local code=1 prompt="Continue?"
	if [[ $# -gt 0 ]]; then
		code=$1
	fi
	if [[ $# -gt 1 ]]; then
		prompt="$2"
	fi
	yes_or_no --default-no "$prompt" || exit $code
}

# pause script execution until user presses a key
function press_any_key_to_continue() {
	read -n 1 -r -s -p $'Press any key to continue...'
	printf "\n\n"
}

# in-place shell selection list
# source: https://askubuntu.com/a/1386907
# (with minor syntax changes to fix vscode syntax highlighting)
function choose_from_menu() {
	local prompt="$1" outvar="$2"
	shift
	shift
	local options=("$@") cur=0 count=${#options[@]} index=0
	local esc=$(echo -en "\e") # cache ESC as test doesn't allow esc codes
	printf "$prompt\n"
	while true; do
		# list all options (option list is zero-based)
		index=0
		for o in "${options[@]}"; do
			if [ "$index" == "$cur" ]; then
				echo -e " >\e[7m$o\e[0m" # mark & highlight the current option
			else
				echo "  $o"
			fi
			index=$(($index + 1))
		done
		read -s -n3 key                 # wait for user to key in arrows or ENTER
		if [[ $key == "$esc[A" ]]; then # up arrow
			cur=$(($cur - 1))
			[ "$cur" -lt 0 ] && cur=0
		elif [[ $key == "$esc[B" ]]; then # down arrow
			cur=$(($cur + 1))
			[ "$cur" -ge $count ] && cur=$(($count - 1))
		elif [[ $key == "" ]]; then # nothing, i.e the read delimiter - ENTER
			break
		fi
		echo -en "\e[${count}A" # go up to the beginning to re-render
	done
	# export the selection to the requested output variable
	printf -v $outvar "${options[$cur]}"
}

# -------------------------- ASSERTIONS ---------------------------------------

# assert sudoer status, and include hostname in prompt
# can prevent auth failures from polluting sudo'd conditional expressions
function assert_sudo() {
	if ! sudo -p "$sudo_prompt_with_hostname" true; then
		printerr "failed to authenticate"
		exit 1
	fi
}

# assert that script process is running on the node server
function assert_on_node_server() {
	if [[ $(hostname) != $node_server_hostname ]]; then
		printerr "script must be run on the node server: $node_server_hostname"
		exit 1
	fi
}

# assert that script process is not running on the node server
function assert_not_on_node_server() {
	if [[ $(hostname) == $node_server_hostname ]]; then
		printerr "script must be run on the client PC, not the node server"
		exit 1
	fi
}

# assert that script process does not have access to the internet
function assert_offline() {
	if is_online; then
		printerr "script must be run on the air-gapped PC"
		exit 1
	fi
}

# -------------------------- CHECKS -------------------------------------------

_check_failures=()

function reset_checks() {
	_check_failures=()
}

function has_failed_checks() {
	[[ ${#_check_failures[@]} -gt 0 ]]
}

# print failed checks with given log-level, return error code if failures
function print_failed_checks() {
	if [[ $# -ne 1 || ($1 != "--warn" && $1 != "--error") ]]; then
		printerr "usage: print_failed_checks {--warn|--error}"
		exit 2
	fi
	local failcount=${#_check_failures[@]}
	local i
	if [[ $failcount -gt 0 ]]; then
		for ((i = 0; i < failcount; i++)); do
			if [[ $1 == "--warn" ]]; then
				printwarn "${_check_failures[i]}"
			else
				printerr "${_check_failures[i]}"
			fi
		done
		reset_checks
		return 1
	fi
}

function check_user_does_not_exist() {
	if _check_is_defined $1; then
		if user_exists "${!1}"; then
			_check_failures+=("user already exists: ${!1}")
		fi
	fi
}

function check_user_exists() {
	if _check_is_defined $1; then
		if ! user_exists "${!1}"; then
			_check_failures+=("user does not exist: ${!1}")
		fi
	fi
}

function check_group_does_not_exist() {
	if _check_is_defined $1; then
		if group_exists "${!1}"; then
			_check_failures+=("group already exists: ${!1}")
		fi
	fi
}

function check_group_exists() {
	if _check_is_defined $1; then
		if ! group_exists "${!1}"; then
			_check_failures+=("group does not exist: ${!1}")
		fi
	fi
}

function check_directory_does_not_exist() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined $1; then
		if $_sudo test -d "${!1}"; then
			_check_failures+=("directory already exists: ${!1}")
		fi
	fi
}

function check_directory_exists() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined $1; then
		if $_sudo test ! -d "${!1}"; then
			_check_failures+=("directory does not exist: ${!1}")
		fi
	fi
}

function check_file_does_not_exist() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined $1; then
		if $_sudo test -f "${!1}"; then
			_check_failures+=("file already exists: ${!1}")
		fi
	fi
}

function check_file_exists() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined $1; then
		if $_sudo test ! -f "${!1}"; then
			_check_failures+=("file does not exist: ${!1}")
		fi
	fi
}

function check_is_valid_ethereum_network() {
	if _check_is_defined $1; then
		if [[ ${!1} != 'mainnet' && ${!1} != 'hoodi' ]]; then
			_check_failures+=("invalid Ethereum network: ${!1}")
		fi
	fi
}

function check_is_valid_port() {
	if _check_is_defined $1; then
		if [[ ${!1} -lt 1 || ${!1} -gt 65535 ]]; then
			_check_failures+=("invalid port: ${!1}")
		fi
	fi
}

function check_command_does_not_exist_on_path() {
	if _check_is_defined $1; then
		if type -P "${!1}" &>/dev/null; then
			_check_failures+=("command already exists: ${!1}")
		fi
	fi
}

function check_command_exists_on_path() {
	if _check_is_defined $1; then
		if ! type -P "${!1}" &>/dev/null; then
			_check_failures+=("command does not exist: ${!1}")
		fi
	fi
}

function check_executable_does_not_exist() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined $1; then
		if $_sudo test -x ${!1}; then
			_check_failures+=("executable already exists: ${!1}")
		fi
	fi
}

function check_executable_exists() {
	local _sudo=''
	if [[ $1 == '--sudo' ]]; then
		_sudo='sudo'
		shift
	fi
	if _check_is_defined $1; then
		if $_sudo test ! -x ${!1}; then
			_check_failures+=("file does not exist or is not executable: ${!1}")
		fi
	fi
}

function check_is_service_installed() {
	if _check_is_defined $1; then
		local service_name="$(basename "${!1}")"
		if ! systemctl list-unit-files --full -all | grep -Fq "$service_name"; then
			_check_failures+=("service is not installed: ${!1}")
		fi
	fi
}

function check_is_service_active() {
	if _check_is_defined $1; then
		local service_name="$(basename "${!1}")"
		if ! systemctl is-active --quiet "$service_name"; then
			_check_failures+=("service is not active: $service_name")
		fi
	fi
}

function check_is_valid_ethereum_address() {
	if _check_is_defined $1; then
		if [[ ! ${!1} =~ $regex_eth_addr ]]; then
			_check_failures+=("invalid Ethereum address: ${!1}")
		fi
	fi
}

function check_string_contains() {
	if _check_is_defined $1; then
		if ! string_contains "${!1}" "$2"; then
			_check_failures+=("$1 does not contain \"$2\"")
		fi
	fi
}

function check_current_directory_is() {
	if _check_is_defined $1; then
		resolved_dir="$(realpath "${!1}")"
		if [[ $(pwd) != $resolved_dir ]]; then
			_check_failures+=("current directory is not $resolved_dir")
		fi
	fi
}

function check_current_directory_is_not() {
	if _check_is_defined $1; then
		resolved_dir="$(realpath "${!1}")"
		if [[ $(pwd) == $resolved_dir ]]; then
			_check_failures+=("current directory is $resolved_dir")
		fi
	fi
}

function check_is_valid_validator_mnemonic() {
	if _check_is_defined $1; then
		if [[ $(printf '%s' "${!1}" | wc -w) -ne 24 ]]; then
			_check_failures+=("$1: expected a 24-word seed phrase")
		fi
	fi
}

function check_is_valid_validator_pubkeys() {
	if _check_is_defined $1; then
		if [[ ! ${!1} =~ $regex_eth_validator_pubkey_csv && ! ${!1} =~ $regex_eth_validator_pubkey_csv_v2 ]]; then
			_check_failures+=("$1: expected a comma-separated list of validator pubkeys")
		fi
	fi
}

function check_is_valid_eip2334_index() {
	if _check_is_defined $1; then
		if [[ ! ${!1} =~ ^[[:digit:]]+$ || ! ${!1} -ge 0 ]]; then
			_check_failures+=("$1: expected a valid EIP-2334 index ≥ 0")
		fi
	fi
}

function check_is_positive_integer() {
	if _check_is_defined $1; then
		if [[ ! ${!1} =~ ^[[:digit:]]+$ || ! ${!1} -gt 0 ]]; then
			_check_failures+=("$1: expected a positive integer")
		fi
	fi
}

function check_is_valid_keystore_password() {
	if _check_is_defined $1; then
		if [[ ! ${!1} =~ $regex_keystore_password ]]; then
			_check_failures+=("$1: $errmsg_keystore_password")
		fi
	fi
}

# predicate (may return non-zero)
function _check_is_defined() {
	if [[ $# -ne 1 ]]; then
		printerr "no argument provided"
		exit 2
	fi
	if [[ -z ${!1} ]]; then
		_check_failures+=("variable is undefined: $1")
		return 1
	fi
}

# non-predicate (avoids triggering errexit)
function check_is_defined() {
	_check_is_defined "$1" && true
}

function check_argument_not_missing() {
	if [[ $# -ne 1 ]]; then
		printerr "no argument name provided"
		exit 2
	fi
	if [[ -z ${!1} ]]; then
		_check_failures+=("missing argument: $1")
	fi
}
