#!/bin/bash

# estimate-withdrawal-sweep.sh
# 
# For each given validator, estimate the time since & until the previous &
# next automatic withdrawals, respectively, as if it were eligible.
#
# See: https://beaconcha.in/validators/withdrawals

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
		log error "unknown option: $1"
		exit 1
		;;
	esac
done

if (($# < 1)); then
	log error "must specify a list of validators by index or pubkey"
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
┌─┐┌─┐┌┬┐┬┌┬┐┌─┐┌┬┐┌─┐  ┬ ┬┬┌┬┐┬ ┬┌┬┐┬─┐┌─┐┬ ┬┌─┐┬   ┌─┐┬ ┬┌─┐┌─┐┌─┐
├┤ └─┐ │ ││││├─┤ │ ├┤───││││ │ ├─┤ ││├┬┘├─┤│││├─┤│───└─┐│││├┤ ├┤ ├─┘
└─┘└─┘ ┴ ┴┴ ┴┴ ┴ ┴ └─┘  └┴┘┴ ┴ ┴ ┴─┴┘┴└─┴ ┴└┴┘┴ ┴┴─┘ └─┘└┴┘└─┘└─┘┴  
EOF

	# -------------------------- PREAMBLE -----------------------------------------

	declare base_url
	beaconchain_base_url "$ethereum_network" base_url

	cat <<-EOF
	For each given validator, estimate the time since & until the previous &
	next automatic withdrawals, respectively, as if it were eligible.

	See: ${theme_url}${base_url}/validators/withdrawals${color_reset}

	EOF
	press_any_key_to_continue
fi

# -------------------------- RECONNAISSANCE -----------------------------------

beacon_api__reconnaissance

# withdrawal sweep rate calculation:
#   16 withdrawals / slot
#   1 slot / 12 seconds
#   :. 4/3 withdrawals / second
withdrawals_per_second='(4/3)'  # valid Python number expression

log info "Converting any validator pubkeys to indexes..."
target_validators=()
has_lookup_errors=false
for _validator in "${validators[@]}"; do
	if [[ $_validator =~ $regex_eth_validator_pubkey ]]; then
		_target_validator="$(beacon_api__get_validators "id=$_validator" | 
			jq -r '.data |
			map(.index) |
			map(tonumber) |
			first'
		)"
		if [[ $_target_validator != 'null' ]]; then
			target_validators+=("$_target_validator")
		else
			log error "Validator index not found: ${theme_value}$_validator${color_reset}"
			has_lookup_errors=true
		fi
	else
		# treat as valid index, as the estimate is given for hypothetical validators too
		target_validators+=("$_validator")
	fi
done
[[ $has_lookup_errors == true ]] && exit 1

target_validators_csv="$(join_arr ',' "${target_validators[@]}")"

# -------------------------- EXECUTION ----------------------------------------

log info "Searching for all validators eligible for withdrawal..."

# active and ((0x01 creds with > 32 ETH) or (0x02 creds with > 2048 ETH))
active="$(beacon_api__get_validators "status=active" | 
	jq -r '.data |
	map(.balance |= tonumber) |
	map(select(
		((.validator.withdrawal_credentials | startswith("0x01")) and (.balance > 32)) or
		((.validator.withdrawal_credentials | startswith("0x02")) and (.balance > 2048))
	)) |
	map(.index) |
	map(tonumber)'
)"

# exited with > 0 ETH
exited="$(beacon_api__get_validators "status=exited" |
	jq -r '.data |
	map(.balance |= tonumber) |
	map(select(.balance > 0)) |
	map(.index) |
	map(tonumber)'
)"

latest_withdrawn_validator="$(beacon_api__get_latest_block |
	jq -r '.data.message.body.execution_payload.withdrawals |
	map(.validator_index) |
	map(tonumber) |
	sort |
	last'
)"

if [[ $latest_withdrawn_validator == 'null' ]]; then
	log warn "Latest withdraw not found.  Sparse block payload?"
	log warn "Try again later."
	exit 1
fi

cat <<EOF
  Number of eligible (active): $(jq -r '. | length' <<<"$active")
  Number of eligible (exited): $(jq -r '. | length' <<<"$exited")
  Latest withdrawn validator: $latest_withdrawn_validator
EOF

# create an ascending sorted-set of all eligible validators, including the
# target validators and the latest withdrawn validator
sorted_indexes="$(jq -sr "add | unique | sort" <<<"$active $exited [$target_validators_csv,$latest_withdrawn_validator]")"

# calculate time since & until target validators' previous & next withdrawals, respectively
readarray -t time_since_until < <(python3 <<EOF

from datetime import timedelta
import json

queue = json.loads('''
	$sorted_indexes
''')
rate = $withdrawals_per_second
target_validators = [$target_validators_csv]
latest = queue.index($latest_withdrawn_validator)

for target_validator in target_validators:
	target = queue.index(target_validator)

	if latest < target:
		seconds_since = (len(queue) - target + latest) / rate
		seconds_until = (target - latest) / rate
	elif latest > target:
		seconds_since = (latest - target) / rate
		seconds_until = (len(queue) - latest + target) / rate
	else:
		seconds_since = 0
		seconds_until = 0

	print(f"{target_validator}")
	print(f"-{timedelta(seconds=round(seconds_since))}")
	print(f"{timedelta(seconds=round(seconds_until))}")

EOF
)

if ((${#time_since_until[@]} % 3 != 0)); then
	log error "Expected output chunks of length = 3 but found:\n${time_since_until[*]}"
	exit 1
fi
for ((i = 0; i < ${#time_since_until[@]}; i += 3)); do
	cat <<-EOF

		Target validator: ${theme_value}${time_since_until[i]}${color_reset}
		Approx. time since last withdrawal: ${theme_value}${time_since_until[i+1]}${color_reset}
		Approx. time until next withdrawal: ${theme_value}${time_since_until[i+2]}${color_reset}
	EOF
done

# -------------------------- POSTCONDITIONS -----------------------------------
