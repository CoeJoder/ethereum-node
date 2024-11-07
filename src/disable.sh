#!/bin/bash

# disable.sh
# Stops & disables all node services (geth, prysm-beacon, prysm-validator).
#
# Meant to be run on the node server.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

reset_checks

check_is_defined geth_unit_file
check_is_defined prysm_beacon_unit_file
check_is_defined prysm_validator_unit_file

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -en "${color_red}${bold}"
cat <<'EOF'
       ___            __    __   
  ____/ (_)________ _/ /_  / /__ 
 / __  / / ___/ __ `/ __ \/ / _ \
/ /_/ / (__  ) /_/ / /_/ / /  __/
\__,_/_/____/\__,_/_.___/_/\___/ 
EOF
echo -en "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Stops & disables all node services (geth, prysm-beacon, prysm-validator).
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

sudo systemctl daemon-reload

_stop_geth=false
_stop_prysmbeacon=false
_stop_prysmvalidator=false

reset_checks
check_is_service_installed geth_unit_file
if ! has_failed_checks; then
	_stop_geth=true
fi

reset_checks
check_is_service_installed prysm_beacon_unit_file
if ! has_failed_checks; then
	_stop_prysmbeacon=true
fi

reset_checks
check_is_service_installed prysm_validator_unit_file
if ! has_failed_checks; then
	_stop_prysmvalidator=true
fi

# -------------------------- EXECUTION ----------------------------------------

if [[ $_stop_geth == true ]]; then
	disable_service "$geth_unit_file"
fi

if [[ $_stop_prysmbeacon == true ]]; then
	disable_service "$prysm_beacon_unit_file"
fi

if [[ $_stop_prysmvalidator == true ]]; then
	disable_service "$prysm_validator_unit_file"
fi

# -------------------------- POSTCONDITIONS -----------------------------------
