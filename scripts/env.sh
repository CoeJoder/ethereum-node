#!/bin/bash

# Environment Variables
#
# These values are configurable, but should be set only once at initial setup.
#
# If `env-private.sh` exists as a sibling, it will override the values in this file.

# -------------------------- START OF ENVIRONMENT VARIABLES -------------------

router_ip_address='192.168.1.1'

node_server_ssh_port=55522
node_server_ip_address='192.168.1.25'
node_server_timezone='America/Los_Angeles'
node_server_hostname='eth-node-mainnet'
node_server_username='coejoder'

client_pc_username='coejoder'

eth_network='mainnet'

geth_port=30303                       # TCP
geth_discovery_port=30303             # UDP
geth_user='goeth'

prysm_beacon_p2p_tcp_port=13000           # TCP
prysm_beacon_p2p_quic_port=13000          # UDP
prysm_beacon_p2p_udp_port=12000           # UDP
prysm_beacon_p2p_max_peers=30
prysm_beacon_user='prysmbeacon'

prysm_validator_user='prysmvalidator'

# -------------------------- END OF ENVIRONMENT VARIABLES ---------------------

this_dir="$(dirname "$(realpath "$0")")"
env_private_sh="$this_dir/env-private.sh"
if [[ -x $env_private_sh ]]; then
  source "$env_private_sh"
fi
