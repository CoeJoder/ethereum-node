#!/bin/bash

# Environment Variables
#
# These values are configurable, but should be set only once at initial setup.
#
# If `env-private.sh` exists as a sibling, it will override the values in this file.

# -------------------------- START OF ENVIRONMENT VARIABLES -------------------

suggested_fee_recipient=''

ethereum_network='mainnet'

client_pc_username='coejoder' # unneeded?

router_ip_address='192.168.1.1'

node_server_ip_address='192.168.1.25'
node_server_ssh_port=55522 # TCP
node_server_timezone='America/Los_Angeles'
node_server_hostname='eth-node-mainnet'
node_server_username='coejoder'
node_server_secondary_storage='/mnt/secondary-drive'

local_secrets_dir='/usr/local/secrets'
eth_jwt_file="$local_secrets_dir/eth_jwt.hex"

geth_user='goeth'
geth_group='goeth'
geth_bin='geth'
geth_datadir='/var/lib/goeth'
geth_datadir_ancient="$node_server_secondary_storage/geth/chaindata/ancient"
geth_unit_file="/etc/systemd/system/eth1.service"
geth_port=30303           # TCP
geth_discovery_port=30303 # UDP

prysm_beacon_user='prysmbeacon'
prysm_beacon_group='prysmbeacon'
prysm_beacon_bin='/usr/local/bin/beacon-chain'
prysm_beacon_datadir="/var/lib/prysm/beacon"
prysm_beacon_unit_file="/etc/systemd/system/eth2-beacon.service"
prysm_beacon_p2p_tcp_port=13000  # TCP
prysm_beacon_p2p_quic_port=13000 # UDP
prysm_beacon_p2p_udp_port=12000  # UDP
prysm_beacon_p2p_max_peers=30

# the hard-coded behavior is to use checkpoint-sync only on 'holesky' testnet 
prysm_beacon_checkpoint_sync_url='https://holesky.beaconstate.info'
prysm_beacon_genesis_beacon_api_url='https://holesky.beaconstate.info'

prysm_validator_user='prysmvalidator'
prysm_validator_group='prysmvalidator'
prysm_validator_bin='/usr/local/bin/validator'
prysm_validator_datadir="/var/lib/prysm/validator"
prysm_validator_wallet_dir="/var/lib/prysm/validator/prysm-wallet-v2"
prysm_validator_wallet_password_file="/var/lib/prysm/validator/wallet-password.txt"
prysm_validator_unit_file="/etc/systemd/system/eth2-validator.service"

# -------------------------- END OF ENVIRONMENT VARIABLES ---------------------

this_dir="$(dirname "$(realpath "$0")")"
env_private_sh="$this_dir/env-private.sh"
if [[ -x $env_private_sh ]]; then
	source "$env_private_sh"
fi