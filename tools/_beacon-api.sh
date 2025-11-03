#!/bin/bash

# _beacon-api.sh
#
# A function library for querying the Beacon Node API.
# Not meant to be run as a top-level script.

# externs; suppress unassigned
declare -g node_server_ssh_port
declare -g node_server_username
declare -g node_server_hostname
declare -g prysm_validator_beacon_rest_api_endpoint

function beacon_api__preconditions() {
	functrace
	reset_checks
	check_is_valid_port node_server_ssh_port
	check_is_defined node_server_username
	check_is_defined node_server_hostname
	check_is_defined prysm_validator_beacon_rest_api_endpoint
	print_failed_checks --error || return
}

function beacon_api__reconnaissance() {
	functrace
	declare -g node_server_ssh_endpoint
	export node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"
}

function beacon_api__get() {
	functrace "$@"
	if (($# != 1)); then
		log error "usage: beacon_api__get query"
		return 1
	fi
	local query="$1"
	ssh -p "$node_server_ssh_port" "$node_server_ssh_endpoint" "
		curl -LSsX 'GET' -H 'Accept: application/json' \
			${prysm_validator_beacon_rest_api_endpoint}${query}
	"
}

# shellcheck disable=SC2120  # optional args
function beacon_api__get_validators() {
	functrace "$@"
	local query_string=""
	[[ -n $1 ]] && query_string="?$1"
	beacon_api__get "/eth/v1/beacon/states/head/validators$query_string"
}

function beacon_api__get_latest_block() {
	functrace
	beacon_api__get "/eth/v2/beacon/blocks/head"
}

function beacon_api__get_sync_status() {
	functrace
	beacon_api__get "/eth/v1/node/syncing"
}
