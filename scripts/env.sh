#!/bin/bash

# Environment Variables
#
# These values are configurable, but should be set only once at initial setup.
#
# If `env-private.sh` exists as a sibling, it will override the values in this file.

# -------------------------- START OF ENVIRONMENT VARIABLES -------------------

ethereum_network='mainnet'

router_ip_address='192.168.1.1'

client_pc_username='coejoder' # unneeded?

node_server_ssh_port=55522 # TCP
node_server_ip_address='192.168.1.25'
node_server_timezone='America/Los_Angeles'
node_server_hostname='eth-node-mainnet'
node_server_username='coejoder'

unit_file_dir=/etc/systemd/system

geth_user='goeth'
geth_group='goeth'
geth_dir=/var/lib/goeth
geth_unit_file="$unit_file_dir/eth1.service"
geth_port=30303           # TCP
geth_discovery_port=30303 # UDP

prysm_dir=/var/lib/prysm

prysm_beacon_user='prysmbeacon'
prysm_beacon_group='prysmbeacon'
prysm_beacon_dir="$prysm_dir/beacon"
prysm_beacon_unit_file="$unit_file_dir/eth2-beacon.service"
prysm_beacon_p2p_tcp_port=13000  # TCP
prysm_beacon_p2p_quic_port=13000 # UDP
prysm_beacon_p2p_udp_port=12000  # UDP
prysm_beacon_p2p_max_peers=30

prysm_validator_user='prysmvalidator'
prysm_validator_group='prysmvalidator'
prysm_validator_dir="$prysm_dir/validator"
prysm_validator_unit_file="$unit_file_dir/eth2-validator.service"

# -------------------------- END OF ENVIRONMENT VARIABLES ---------------------

this_dir="$(dirname "$(realpath "$0")")"
env_private_sh="$this_dir/env-private.sh"
if [[ -x $env_private_sh ]]; then
	source "$env_private_sh"
fi
