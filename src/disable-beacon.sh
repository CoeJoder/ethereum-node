#!/bin/bash

# disable-beacon.sh
#
# Stops & disables the prysm-beacon (CL) service.
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
check_file_exists --sudo prysm_beacon_unit_file
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

disable_service "$prysm_beacon_unit_file"

# -------------------------- POSTCONDITIONS -----------------------------------
