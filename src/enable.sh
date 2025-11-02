#!/bin/bash

# enable.sh
#
# Starts & enables all node services (geth, prysm-beacon, prysm-validator, MEV-Boost).
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
                    __    __   
  ___  ____  ____ _/ /_  / /__ 
 / _ \/ __ \/ __ `/ __ \/ / _ \
/  __/ / / / /_/ / /_/ / /  __/
\___/_/ /_/\__,_/_.___/_/\___/ 
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Starts & enables all node services (geth, prysm-beacon, prysm-validator, MEV-Boost).
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

sudo systemctl daemon-reload

_start_geth=false
_start_prysmbeacon=false
_start_prysmvalidator=false
_start_mevboost=false

reset_checks
check_file_exists --sudo geth_unit_file
check_is_service_installed geth_unit_file
if ! has_failed_checks; then
	_start_geth=true
else
	log warn "Skipping geth (not installed)..."
fi

reset_checks
check_file_exists --sudo prysm_beacon_unit_file
check_is_service_installed prysm_beacon_unit_file
if ! has_failed_checks; then
	_start_prysmbeacon=true
else
	log warn "Skipping beacon (not installed)..."
fi

reset_checks
check_file_exists --sudo prysm_validator_unit_file
check_is_service_installed prysm_validator_unit_file
if ! has_failed_checks; then
	_start_prysmvalidator=true
else
	log warn "Skipping validator (not installed)..."
fi

reset_checks
check_file_exists --sudo mevboost_unit_file
check_is_service_installed mevboost_unit_file
if ! has_failed_checks; then
	_start_mevboost=true
else
	log warn "Skipping MEV-Boost (not installed)..."
fi

if [[ $_start_geth == false || 
	$_start_prysmbeacon == false ||
	$_start_prysmvalidator == false ||
	$_start_mevboost == false ]]; then
	continue_or_exit
fi

# -------------------------- EXECUTION ----------------------------------------

if [[ $_start_mevboost == true ]]; then
	enable_service "$mevboost_unit_file"
fi

if [[ $_start_geth == true ]]; then
	enable_service "$geth_unit_file"
fi

if [[ $_start_prysmbeacon == true ]]; then
	enable_service "$prysm_beacon_unit_file"
fi

if [[ $_start_prysmvalidator == true ]]; then
	enable_service "$prysm_validator_unit_file"
fi

# -------------------------- POSTCONDITIONS -----------------------------------
