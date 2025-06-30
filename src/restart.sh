#!/bin/bash

# restart.sh
#
# Restarts all node services (geth, prysm-beacon, prysm-validator, MEV-Boost).
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

echo -en "${color_red}${bold}"
cat <<'EOF'
                   __             __ 
   ________  _____/ /_____ ______/ /_
  / ___/ _ \/ ___/ __/ __ `/ ___/ __/
 / /  /  __(__  ) /_/ /_/ / /  / /_  
/_/   \___/____/\__/\__,_/_/   \__/  
EOF
echo -en "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Restarts all node services (geth, prysm-beacon, prysm-validator, MEV-Boost).
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

sudo systemctl daemon-reload

_restart_geth=false
_restart_prysmbeacon=false
_restart_prysmvalidator=false
_restart_mevboost=false

reset_checks
check_file_exists --sudo geth_unit_file
check_is_service_installed geth_unit_file
check_is_service_active geth_unit_file
if ! has_failed_checks; then
	_restart_geth=true
else
	printwarn "Skipping geth (not installed or inactive)..."
fi

reset_checks
check_file_exists --sudo prysm_beacon_unit_file
check_is_service_installed prysm_beacon_unit_file
check_is_service_active prysm_beacon_unit_file
if ! has_failed_checks; then
	_restart_prysmbeacon=true
else
	printwarn "Skipping beacon (not installed or inactive)..."
fi

reset_checks
check_file_exists --sudo prysm_validator_unit_file
check_is_service_installed prysm_validator_unit_file
check_is_service_active prysm_validator_unit_file
if ! has_failed_checks; then
	_restart_prysmvalidator=true
else
	printwarn "Skipping validator (not installed or inactive)..."
fi

reset_checks
check_file_exists --sudo mevboost_unit_file
check_is_service_installed mevboost_unit_file
check_is_service_active mevboost_unit_file
if ! has_failed_checks; then
	_restart_mevboost=true
else
	printwarn "Skipping MEV-Boost (not installed or inactive)..."
fi

if [[ $_restart_geth == false || 
	$_restart_prysmbeacon == false ||
	$_restart_prysmvalidator == false ||
	$_restart_mevboost == false ]]; then
	continue_or_exit
fi

# -------------------------- EXECUTION ----------------------------------------

if [[ $_restart_mevboost == true ]]; then
	restart_service "$mevboost_unit_file"
fi

if [[ $_restart_geth == true ]]; then
	restart_service "$geth_unit_file"
fi

if [[ $_restart_prysmbeacon == true ]]; then
	restart_service "$prysm_beacon_unit_file"
fi

if [[ $_restart_prysmvalidator == true ]]; then
	restart_service "$prysm_validator_unit_file"
fi

# -------------------------- POSTCONDITIONS -----------------------------------
