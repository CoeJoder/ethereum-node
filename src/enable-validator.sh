#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks
check_is_defined prysm_validator_unit_file
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

enable_service "$prysm_validator_unit_file"

# -------------------------- POSTCONDITIONS -----------------------------------

sudo journalctl -fu "$(basename "$prysm_validator_unit_file")"
