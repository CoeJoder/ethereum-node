#!/bin/bash

# estimate-withdrawal-sweep.sh
# 
# Given a validator, estimate the time since & until the previous & next
# automatic withdrawals, respectively, as if it were eligible.
#
# See: https://beaconcha.in/validators/withdrawals

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage:
		  $(basename ${BASH_SOURCE[0]}) [options] validator
		Options:
		  --no-banner   Do not show banner
		  --help, -h    Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='no-banner,help' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
(($? != 0)) && exit 1
eval set -- "$_parsed_args"
unset _parsed_args

validator=''
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
	printerr "must specify validator index or pubkey"
	exit 1
fi
validator="$1"
shift

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks

for _command in jq python3; do
	check_command_exists_on_path _command
done

check_is_valid_validator_index_or_pubkey validator
check_is_valid_port node_server_ssh_port
check_is_defined node_server_username
check_is_defined node_server_hostname
check_is_valid_port prysm_beacon_http_port

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

if [[ $no_banner == false ]]; then
	cat <<-EOF
	${color_green}${bold}
	┌─┐┌─┐┌┬┐┬┌┬┐┌─┐┌┬┐┌─┐  ┬ ┬┬┌┬┐┬ ┬┌┬┐┬─┐┌─┐┬ ┬┌─┐┬   ┌─┐┬ ┬┌─┐┌─┐┌─┐
	├┤ └─┐ │ ││││├─┤ │ ├┤───││││ │ ├─┤ ││├┬┘├─┤│││├─┤│───└─┐│││├┤ ├┤ ├─┘
	└─┘└─┘ ┴ ┴┴ ┴┴ ┴ ┴ └─┘  └┴┘┴ ┴ ┴ ┴─┴┘┴└─┴ ┴└┴┘┴ ┴┴─┘ └─┘└┴┘└─┘└─┘┴  
	${color_reset}
	EOF

	# -------------------------- PREAMBLE -----------------------------------------

	cat <<-EOF
	Given a validator, estimate the time since & until the previous & next
	automatic withdrawals, respectively, as if it were eligible.

	See: ${theme_url}https://beaconcha.in/validators/withdrawals${color_reset}

	EOF
	press_any_key_to_continue
fi

# -------------------------- RECONNAISSANCE -----------------------------------

# withdrawal sweep rate calculation:
#   16 withdrawals / slot
#   1 slot / 12 seconds
#   :. 4/3 withdrawals / second
withdrawals_per_second='(4/3)'  # valid Python number expression

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"

function beacon_api_get() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: beacon_api_get query"
		return 1
	fi
	local query="$1"
	ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
		curl -LSsX 'GET' --fail-with-body -H 'Accept: application/json' \
			"http://127.0.0.1:${prysm_beacon_http_port}${query}"
	"
}

function get_validators() {
	if [[ $# -ne 1 ]]; then
		printerr "usage: get_validators query-params"
		return 1
	fi
	local query_params="$1"
	beacon_api_get "/eth/v1/beacon/states/head/validators?$query_params"
}

function get_latest_block() {
	beacon_api_get "/eth/v2/beacon/blocks/head"
}

target_validator="$validator"

# if a pubkey was provided, convert to an index
if [[ $target_validator =~ $regex_eth_validator_pubkey ]]; then
	printinfo "Converting validator pubkey to index..."
	target_validator="$(get_validators "id=$validator" | 
		jq -r '.data |
		map(.index) |
		map(tonumber) |
		first'
	)"
	if [[ $target_validator == 'null' ]]; then
		printerr "Validator index not found: ${theme_value}$validator${color_reset}"
		exit 1
	fi
fi

# -------------------------- EXECUTION ----------------------------------------

printinfo "Searching for all validators eligible for withdrawal..."

# active and ((0x01 creds with > 32 ETH) or (0x02 creds with > 2048 ETH))
active="$(get_validators "status=active" | 
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
exited="$(get_validators "status=exited" |
	jq -r '.data |
	map(.balance |= tonumber) |
	map(select(.balance > 0)) |
	map(.index) |
	map(tonumber)'
)"

latest_withdrawn_validator="$(get_latest_block |
	jq -r '.data.message.body.execution_payload.withdrawals |
	map(.validator_index) |
	map(tonumber) |
	sort |
	last'
)"

if [[ $latest_withdrawn_validator == 'null' ]]; then
	printwarn "Latest withdraw not found.  Sparse block payload?"
	printwarn "Try again later."
	exit 1
fi

cat <<EOF
  Number of eligible (active): $(jq -r '. | length' <<<"$active")
  Number of eligible (exited): $(jq -r '. | length' <<<"$exited")
  Latest withdrawn validator: $latest_withdrawn_validator
  Target validator: ${theme_value}$target_validator${color_reset}
EOF

# create an ascending sorted-set of all eligible validators, including the
# target validator and the latest withdrawn validator
sorted_indexes="$(jq -sr "add | unique | sort" <<<"$active $exited [$target_validator, $latest_withdrawn_validator]")"

# calculate time since & until target validator's previous & next withdrawals, respectively
readarray -t time_since_until < <(python3 <<EOF
from datetime import timedelta
import json

queue = json.loads('''
	$sorted_indexes
''')

latest = queue.index($latest_withdrawn_validator)
target = queue.index($target_validator)
rate = $withdrawals_per_second

if latest < target:
	seconds_since = (len(queue) - target + latest) / rate
	seconds_until = (target - latest) / rate
elif latest > target:
	seconds_since = (latest - target) / rate
	seconds_until = (len(queue) - latest + target) / rate
else:
	seconds_since = 0
	seconds_until = 0

print(str(timedelta(seconds=round(seconds_since))))
print(str(timedelta(seconds=round(seconds_until))))

EOF
)

if ((${#time_since_until[@]} == 2)); then
	cat <<-EOF
	  Approx. time since last withdrawal: ${theme_value}${time_since_until[0]}${color_reset}
	  Approx. time until next withdrawal: ${theme_value}${time_since_until[1]}${color_reset}
	EOF
fi

# -------------------------- POSTCONDITIONS -----------------------------------
