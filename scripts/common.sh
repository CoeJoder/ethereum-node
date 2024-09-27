#!/bin/bash

# -------------------------- HEADER -------------------------------------------

# propagate top-level ERR traps to subcontexts
set -E

# project directories
proj_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
scripts_dir="$proj_dir/scripts"
tools_dir="$proj_dir/tools"
test_dir="$proj_dir/test"

# project environment variables
source "$proj_dir/scripts/env.sh"

# -------------------------- CONSTANTS ----------------------------------------

# e.g. "0xAbC123,0xdEf456"
# unit tests: test_regex_hex_list()
regex_hex_csv='^0x[[:xdigit:]]+(,0x[[:xdigit:]]+)*$'

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
fi

# generic error messages to display on ERR trap
errmsg_noretry="\nSomething went wrong.  Send screenshots of the terminal to the HGiC (Head Geek-in-Charge)"
errmsg_retry="$errmsg_noretry, or just try it again and don't screw it up this time ;)"

# -------------------------- UTILITIES ----------------------------------------

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
  if [[ $# -ne 3 ]] ; then
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
  if [[ $# -ne 2 ]] ; then
    echo "usage: read_no_default description outvar" >&2
    return 1
  fi
  local description="$1" outvar="$2" val
  read -p "${description}: ${color_green}" val
  echo -en "${color_reset}"
  printf -v $outvar "$val"
}

# source: https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
function get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

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
