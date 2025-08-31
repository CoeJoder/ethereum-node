#!/bin/bash

# estimate-bp-frequency.sh
# 
# For each given validator, estimate the frequency of block proposals
# that can be expected, with respect to the current total EB of the blockchain.

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
source "$tools_dir/_beacon-api.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage:
		  $(basename "${BASH_SOURCE[0]}") [options] validator1 [validator2 ...]
		Options:
		  --no-banner   Do not show banner
		  --help, -h    Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='no-banner,help' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

no_banner=false

while true; do
	case "$1" in
	--no-banner)
		no_banner=true
		shift
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown option: $1"
		exit 1
		;;
	esac
done

if (($# < 1)); then
	printerr "must specify a list of validators by index or pubkey"
	exit 1
fi

validators=( "$@" )
shift $#

# -------------------------- PRECONDITIONS ------------------------------------

beacon_api__preconditions

reset_checks
for _command in jq python3; do
	check_command_exists_on_path _command
done
for _validator in "${validators[@]}"; do
	check_is_valid_validator_index_or_pubkey _validator
done
check_is_valid_ethereum_network ethereum_network
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

if [[ $no_banner == false ]]; then
	show_banner "${color_green}${bold}" <<'EOF'
┌─┐┌─┐┌┬┐┬┌┬┐┌─┐┌┬┐┌─┐  ┌┐ ┌─┐   ┌─┐┬─┐┌─┐┌─┐ ┬ ┬┌─┐┌┐┌┌─┐┬ ┬
├┤ └─┐ │ ││││├─┤ │ ├┤───├┴┐├─┘───├┤ ├┬┘├┤ │─┼┐│ │├┤ ││││  └┬┘
└─┘└─┘ ┴ ┴┴ ┴┴ ┴ ┴ └─┘  └─┘┴     └  ┴└─└─┘└─┘└└─┘└─┘┘└┘└─┘ ┴ 
EOF

	# -------------------------- PREAMBLE -----------------------------------------

	cat <<-EOF
	For each given validator, estimate the frequency of block proposals that can be expected, with respect to the current total EB of the blockchain.
	EOF
	press_any_key_to_continue
fi

# -------------------------- RECONNAISSANCE -----------------------------------

beacon_api__reconnaissance

validators_csv="$(join_arr ',' "${validators[@]}")"

# -------------------------- EXECUTION ----------------------------------------

printinfo "Finding EBs of given validators..."
validator_ebs_json="$(beacon_api__get_validators "id=${validators_csv}" | jq '.data | 
	map({
		(.index): .validator.effective_balance | tonumber
	}) |
	add')"

printinfo "Finding total EB of all $ethereum_network validators..."
total_eb="$(beacon_api__get_validators | jq '
	[
		.data[] | 
		select(.status | startswith("active")) |
		.validator.effective_balance | 
		tonumber
	] | add')"

# calculate expected time between proposals per given validator
readarray -t expected_time_between_proposals < <(python3 <<EOF

import json

validator_ebs = json.loads('''
	$validator_ebs_json
''')
total_eb = $total_eb
slots_per_day = 7200

for validator in validator_ebs:
	validator_eb = validator_ebs[validator]
	per_slot_probability = validator_eb / total_eb
	expected_proposals_per_day = slots_per_day * per_slot_probability
	expected_time_between_proposals = (
		1 / expected_proposals_per_day
		if expected_proposals_per_day > 0
		else 0
	)
	print(f"{validator}")
	print(f"{round(expected_time_between_proposals, 1):g} days")

EOF
)

if ((${#expected_time_between_proposals[@]} % 2 != 0)); then
	printerr "Expected output chunks of length = 2 but found:\n${expected_time_between_proposals[*]}"
	exit 1
fi
for ((i = 0; i < ${#expected_time_between_proposals[@]}; i += 2)); do
	cat <<-EOF

		Validator: ${theme_value}${expected_time_between_proposals[i]}${color_reset}
		Average time between block proposals: ${theme_value}${expected_time_between_proposals[i+1]}${color_reset}
	EOF
done

# -------------------------- POSTCONDITIONS -----------------------------------
