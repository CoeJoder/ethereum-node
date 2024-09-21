#!/bin/bash

# -------------------------- CONSTANTS ----------------------------------------

prysmvalidator_user='prysmvalidator'

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

# -------------------------- UTILITIES ----------------------------------------

function printerr() {
  echo -e "${color_red}ERROR${color_reset} $@" >&2
}

# `read` but allows a default value
function read_default() {
  if [[ $# -ne 3 ]] ; then
    echo "usage: read_default prompt default_val outvar" >&2
    return 1
  fi
  local prompt="$1" default_val="$2" outvar="$3" val
  echo -e "${prompt}${color_green}"
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
    echo "usage: read_no_default prompt outvar" >&2
    return 1
  fi
  local prompt="$1" outvar="$2" val
  read -p "${prompt}${color_green}" val
  echo -en "${color_reset}"
  printf -v $outvar "$val"
}

# source: https://gist.github.com/lukechilds/a83e1d7127b78fef38c2914c4ececc3c
function get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}
