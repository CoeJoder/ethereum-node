#!/bin/bash

# get-validator-statuses.sh
#
# Queries the status of imported validator accounts.
#
# Meant to be run on the node server.  Typically called remotely from the
# client PC `export.sh` script but can be run directly.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename ${BASH_SOURCE[0]}) outfile
	EOF
}

if [[ $# -ne 1 ]]; then
	show_usage
	exit 1
fi
_outfile="$1"

# -------------------------- PRECONDITIONS ------------------------------------

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

assert_on_node_server
assert_sudo

check_is_defined ethereum_network
check_is_defined prysm_validator_wallet_dir
check_is_defined prysm_validator_wallet_password_file
check_is_defined prysm_validator_user

for _command in tee awk curl jq; do
	check_command_exists_on_path _command
done

check_executable_exists --sudo prysm_validator_bin

print_failed_checks --error

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

printinfo "Fetching validator indices from prysm-validator wallet..."
validator_indices=$(sudo -u "$prysm_validator_user" "$prysm_validator_bin" accounts list \
	--wallet-dir="$prysm_validator_wallet_dir" \
	--wallet-password-file="$prysm_validator_wallet_password_file" \
	--list-validator-indices \
	--accept-terms-of-use \
	--${ethereum_network} 2>/dev/null |
	tee >(cat 1>&2) |
	awk 'NR>1 {print $2}')
validator_indices_csv="${validator_indices//$'\n'/,}"

printinfo "Querying beacon chain for validator statuses..."
api_url="http://localhost:3500/eth/v1/beacon/states/head/validators?id=$validator_indices_csv"
printinfo "curl -X 'GET' \"$api_url\" -H 'accept: application/json' --no-progress-meter"
curl -X 'GET' "$api_url" -H 'accept: application/json' --no-progress-meter |
	tee >(cat 1>&2) |
	jq '.data' >"$_outfile"

# -------------------------- POSTCONDITIONS -----------------------------------
