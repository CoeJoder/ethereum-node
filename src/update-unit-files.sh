#!/bin/bash

# update-unit-files.sh
#
# Regenerates the unit files of installed services according to the current
# project enviornment variables.
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

script_mevboost="$this_dir/setup-mev-boost.sh"
script_node="$this_dir/setup-node.sh"
script_validator="$this_dir/setup-validator.sh"

reset_checks

check_executable_exists script_mevboost
check_executable_exists script_node
check_executable_exists script_validator

check_is_defined mevboost_unit_file
check_is_defined geth_unit_file
check_is_defined prysm_beacon_unit_file
check_is_defined prysm_validator_unit_file

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_yellow}${bold}" <<'EOF'
░█░█░█▀█░█▀▄░█▀█░▀█▀░█▀▀░░░░░█░█░█▀█░▀█▀░▀█▀░░░░░█▀▀░▀█▀░█░░░█▀▀░█▀▀
░█░█░█▀▀░█░█░█▀█░░█░░█▀▀░▄▄▄░█░█░█░█░░█░░░█░░▄▄▄░█▀▀░░█░░█░░░█▀▀░▀▀█
░▀▀▀░▀░░░▀▀░░▀░▀░░▀░░▀▀▀░░░░░▀▀▀░▀░▀░▀▀▀░░▀░░░░░░▀░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF

Regenerates the unit files of installed services according to the current project enviornment variables.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

assert_sudo

if sudo test -f "$mevboost_unit_file"; then
	printinfo "Updating ${theme_filename}MEV-Boost${color_reset} unit file..."
	"$script_mevboost" --unit-file-only --no-banner
fi

if sudo test -f "$geth_unit_file" && sudo test -f "$prysm_beacon_unit_file"; then
	printinfo "Updating ${theme_filename}geth${color_reset} and ${theme_filename}prysm-beacon${color_reset} unit files..."
	"$script_node" --unit-files-only --no-banner
fi

if sudo test -f "$prysm_validator_unit_file"; then
	printinfo "Updating ${theme_filename}prysm-validator${color_reset} unit file..."
	"$script_validator" --unit-file-only --no-banner
fi

# -------------------------- POSTCONDITIONS -----------------------------------
