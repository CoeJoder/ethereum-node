#!/bin/bash

# -------------------------- HEADER -------------------------------------------

# propagate top-level ERR traps to subcontexts
set -E

# project directories
proj_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
scripts_dir="$proj_dir/scripts"
tools_dir="$proj_dir/tools"
test_dir="$proj_dir/test"

# project files
log_file="log.txt"
env_base_sh="$scripts_dir/env-base.sh"
env_sh="$scripts_dir/env.sh"

# -------------------------- CONSTANTS ----------------------------------------

# e.g. "0xAbC123"
regex_eth_addr='^0x[[:xdigit:]]{40}$'

# e.g. "0xAbC123,0xdEf456"
regex_eth_addr_csv='^0x[[:xdigit:]]{40}(,0x[[:xdigit:]]{40})*$'

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
	color_filename="${color_green}"
fi

# generic error messages to display on ERR trap
errmsg_noretry="\nSomething went wrong.  Send ${color_filename}log.txt${color_reset} to the HGiC (Head Geek-in-Charge)"
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
	check_executable_exists env_base_sh
	exit_if_failed_checks
	source "$env_base_sh"
	
	# warn if private env is missing but don't exit
	check_executable_exists env_sh
	if print_failed_checks --warn; then
		source "$env_sh"
	fi
}

# append to log file
function log_timestamp() {
	echo -en "\n$(date "+%m-%d-%Y, %r")" >> "$log_file"
}

# tee stdout & stderr to log file
function log_start() {
	exec &> >(tee -a "$log_file")
}

# logs a warning message to terminal
function printwarn() {
	echo -e "${color_yellow}WARN ${color_reset}$@" >&2
}

# terminal error logger that propagates and optionally overrides exit code
# examples:
#   `printerr 2 "failed to launch"`
#   `printerr "failed to launch"`
function printerr() {
	local code="$?" msg
	if [[ $# -eq 2 ]]; then
		code="$1" msg="$2"
		echo -e "${color_red}ERROR ${code}${color_reset} $msg" >&2
	elif [[ $# -eq 1 ]]; then
		msg="$1"
		echo -e "${color_red}ERROR${color_reset} $msg" >&2
	else
		echo "usage: printerr [code] msg" >&2
		return 1
	fi
	return "$code"
}

# logger for ERR trap that propagates and optionally overrides exit code
# examples:
#   `trap 'printerr_trap; exit $?' ERR
#   `trap 'printerr_trap $? "failed to launch"; exit 1' ERR`
function printerr_trap() {
	local code="$?"
	local msg="at line $(caller)"
	if [[ $# -eq 2 ]]; then
		code="$1"
		msg="$msg: $2"
	elif [[ $# -eq 1 ]]; then
		code="$1"
	fi
	printerr "$code" "$msg"
	return "$code"
}

# `read` but allows a default value
function read_default() {
	if [[ $# -ne 3 ]]; then
		echo "usage: read_default description default_val outvar" >&2
		return 1
	fi
	local description="$1" default_val="$2" outvar="$3" val
	echo -e "${description} (default: ${color_lightgray}$default_val${color_reset}):${color_green}"
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
	read -p "${description}: ${color_green}" val
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

# test expression for user existence
function user_exists() {
	id "$1" &>/dev/null
}

# test expression for group existence
function group_exists() {
	getent group "$1" &>/dev/null
}

# yes-or-no prompt, defaulting to no, exiting on 'no' with given code or 0 by default
function continue_or_exit() {
	local code=0 question="Continue?" confirm
	if [[ $# -gt 0 ]]; then
		code="$1"
	fi
	if [[ $# -gt 1 ]]; then
		question="$2"
	fi
	read -p "$question (y/N): " confirm &&
		[[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit "$code"
	printf '\n'
}

# pause script execution until user presses a key
function press_any_key_to_continue() {
	read -n 1 -r -s -p $'Press any key to continue...'
	printf "\n\n"
}

# -------------------------- ASSERTIONS ---------------------------------------

# assert sudoer status
# can prevent auth failures from polluting sudo'd conditional expressions
function assert_sudo() {
	if ! sudo true; then
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

# -------------------------- CHECKS -------------------------------------------

_check_failures=()

function reset_checks() {
	_check_failures=()
}

# print failed checks with given log-level, with error code if failures
function print_failed_checks() {
	if [[ $# -ne 1 || ( $1 != "--warn" && $1 != "--error" ) ]]; then
		printerr "usage: _print_failed_checks [--warn|--error]"
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

function exit_if_failed_checks() {
	print_failed_checks --error || exit
}

function check_user_does_not_exist() {
	if check_is_defined $1; then
		if user_exists "${!1}"; then
			_check_failures+=("user already exists: ${!1}")
		fi
	fi
}

function check_user_exists() {
	if check_is_defined $1; then
		if ! user_exists "${!1}"; then
			_check_failures+=("user does not exist: ${!1}")
		fi
	fi
}

function check_group_does_not_exist() {
	if check_is_defined $1; then
		if group_exists "${!1}"; then
			_check_failures+=("group already exists: ${!1}")
		fi
	fi
}

function check_group_exists() {
	if check_is_defined $1; then
		if ! group_exists "${!1}"; then
			_check_failures+=("group does not exist: ${!1}")
		fi
	fi
}

function check_directory_does_not_exist() {
	if check_is_defined $1; then
		if [[ -d "${!1}" ]]; then
			_check_failures+=("directory already exists: ${color_filename}${!1}${color_reset}")
		fi
	fi
}

function check_directory_exists() {
	if check_is_defined $1; then
		if [[ ! -d "${!1}" ]]; then
			_check_failures+=("directory does not exist: ${color_filename}${!1}${color_reset}")
		fi
	fi
}

function check_file_does_not_exist() {
	if check_is_defined $1; then
		if [[ -f "${!1}" ]]; then
			_check_failures+=("file already exists: ${color_filename}${!1}${color_reset}")
		fi
	fi
}

function check_file_exists() {
	if check_is_defined $1; then
		if [[ ! -f "${!1}" ]]; then
			_check_failures+=("file does not exist: ${color_filename}${!1}${color_reset}")
		fi
	fi
}

function check_is_valid_ethereum_network() {
	if check_is_defined $1; then
		if [[ ${!1} != 'mainnet' && ${!1} != 'holesky' ]]; then
			_check_failures+=("invalid Ethereum network: ${!1}")
		fi
	fi
}

function check_is_valid_port() {
	if check_is_defined $1; then
		if [[ ${!1} -lt 1 || ${!1} -gt 65535 ]]; then
			_check_failures+=("invalid port: ${!1}")
		fi
	fi
}

function check_command_exists_on_path() {
	if check_is_defined $1; then
		if ! type -P "${!1}" &>/dev/null; then
			_check_failures+=("command does not exist: ${!1}")
		fi
	fi
}

function check_executable_exists() {
	if check_is_defined $1; then
		if [[ ! -x ${!1} ]]; then
			_check_failures+=("file does not exist or is not executable: ${color_filename}${!1}${color_reset}")
		fi
	fi
}

function check_is_valid_ethereum_address() {
	if check_is_defined $1; then
		if [[ ! ${!1} =~ $regex_eth_addr ]]; then
			_check_failures+=("invalid hexadecimal: ${!1}")
		fi
	fi
}

function check_is_defined() {
	if [[ $# -ne 1 ]]; then
		printerr "no argument provided"
		exit 2
	fi
	if [[ -z ${!1} ]]; then
		_check_failures+=("variable is undefined: $1")
		return 1
	fi
}
