#!/bin/bash

# status.sh
#
# Checks the status of all node services.
#
# Meant to be run on the node server.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server

reset_checks

check_is_defined geth_unit_file
check_is_defined prysm_beacon_unit_file
check_is_defined prysm_validator_unit_file
check_is_defined mevboost_unit_file

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_yellow}${bold}" <<'EOF'
         __        __            
   _____/ /_____ _/ /___  _______
  / ___/ __/ __ `/ __/ / / / ___/
 (__  ) /_/ /_/ / /_/ /_/ (__  ) 
/____/\__/\__,_/\__/\__,_/____/  
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Checks the status of all node services.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

geth_service_name="$(basename "$geth_unit_file")"
prysm_beacon_service_name="$(basename "$prysm_beacon_unit_file")"
prysm_validator_service_name="$(basename "$prysm_validator_unit_file")"
mevboost_service_name="$(basename "$mevboost_unit_file")"

# -------------------------- EXECUTION ----------------------------------------

geth_status="inactive"
beacon_status="inactive"
validator_status="inactive"
mevboost_status="inactive"

systemctl --quiet is-active "$geth_service_name" && geth_status="active"
systemctl --quiet is-active "$prysm_beacon_service_name" && beacon_status="active"
systemctl --quiet is-active "$prysm_validator_service_name" && validator_status="active"
systemctl --quiet is-active "$mevboost_service_name" && mevboost_status="active"

cat <<EOF
Geth:             $geth_status
Prysm-beacon:     $beacon_status
Prysm-validator:  $validator_status
MEV-Boost:        $mevboost_status
EOF

# -------------------------- POSTCONDITIONS -----------------------------------
