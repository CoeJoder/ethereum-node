#!/bin/bash

# disable.sh
#
# Stops & disables all node services (geth, prysm-beacon, prysm-validator, MEV-Boost).
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
check_is_defined mevboost_unit_file

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_red}${bold}" <<'EOF'
       ___            __    __   
  ____/ (_)________ _/ /_  / /__ 
 / __  / / ___/ __ `/ __ \/ / _ \
/ /_/ / (__  ) /_/ / /_/ / /  __/
\__,_/_/____/\__,_/_.___/_/\___/ 
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Stops & disables all node services (geth, prysm-beacon, prysm-validator, MEV-Boost).
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

assert_sudo

sudo systemctl daemon-reload

_stop_geth=false
_stop_prysmbeacon=false
_stop_prysmvalidator=false
_stop_mevboost=false

reset_checks
check_file_exists --sudo geth_unit_file
check_is_service_installed geth_unit_file
if ! has_failed_checks; then
	_stop_geth=true
fi

reset_checks
check_file_exists --sudo prysm_beacon_unit_file
check_is_service_installed prysm_beacon_unit_file
if ! has_failed_checks; then
	_stop_prysmbeacon=true
fi

reset_checks
check_file_exists --sudo prysm_validator_unit_file
check_is_service_installed prysm_validator_unit_file
if ! has_failed_checks; then
	_stop_prysmvalidator=true
fi

reset_checks
check_file_exists --sudo mevboost_unit_file
check_is_service_installed mevboost_unit_file
if ! has_failed_checks; then
	_stop_mevboost=true
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

if [[ $_stop_mevboost == true ]]; then
	disable_service "$mevboost_unit_file"
fi

# -------------------------- POSTCONDITIONS -----------------------------------
