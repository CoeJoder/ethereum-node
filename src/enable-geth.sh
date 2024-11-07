#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks
check_is_defined geth_unit_file
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

enable_service "$geth_unit_file"

# -------------------------- POSTCONDITIONS -----------------------------------

sudo journalctl -fu "$(basename "$geth_unit_file")"
