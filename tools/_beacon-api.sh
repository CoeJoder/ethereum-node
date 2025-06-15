#!/bin/bash

# _beacon-api.sh
#
# A function library for querying the Beacon Node API.
# Not meant to be run as a top-level script.

function beacon_api__preconditions() {
	reset_checks
	check_is_valid_port node_server_ssh_port
	check_is_defined node_server_username
	check_is_defined node_server_hostname
	check_is_defined prysm_validator_beacon_rest_api_endpoint
	print_failed_checks --error || return
}

function beacon_api__reconnaissance() {
	node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"
}

function beacon_api__get() {
	if (($# != 1)); then
		printerr "usage: beacon_api__get query"
		return 1
	fi
	local query="$1"
	ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
		curl -LSsX 'GET' -H 'Accept: application/json' \
			"${prysm_validator_beacon_rest_api_endpoint}${query}"
	"
}

function beacon_api__get_validators() {
	if (($# != 1)); then
		printerr "usage: beacon_api__get_validators query-params"
		return 1
	fi
	local query_params="$1"
	beacon_api__get "/eth/v1/beacon/states/head/validators?$query_params"
}

function beacon_api__get_latest_block() {
	beacon_api__get "/eth/v2/beacon/blocks/head"
}

function beacon_api__get_sync_status() {
	beacon_api__get "/eth/v1/node/syncing"
}
