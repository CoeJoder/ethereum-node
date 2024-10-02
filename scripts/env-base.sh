#!/bin/bash

# Environment Variables - Base
#
# DO NOT EDIT THIS FILE!
# Run `setup-env.sh` to generate an editable `env.sh` file.

ethereum_network='holesky'

router_ip_address='192.168.1.1'

node_server_ip_address='192.168.1.25'
node_server_ssh_port=55522 # TCP
node_server_timezone='America/Los_Angeles'
node_server_hostname='eth-node-mainnet'
node_server_username='coejoder'
node_server_secondary_storage='/mnt/secondary'

eth_jwt_file="/usr/local/secrets/eth_jwt.hex"

geth_user='goeth'
geth_group='goeth'
geth_bin='geth'
geth_datadir='/var/lib/goeth'
geth_unit_file="/etc/systemd/system/eth1.service"
geth_port=30303           # TCP
geth_discovery_port=30303 # UDP
geth_datadir_secondary="$node_server_secondary_storage/geth"
geth_datadir_secondary_ancient="$geth_datadir_secondary/chaindata/ancient"

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
# these variables are ignored unless `ethereum_network` is set to 'holesky'
prysm_beacon_checkpoint_sync_url='https://holesky.beaconstate.info'
prysm_beacon_genesis_beacon_api_url='https://holesky.beaconstate.info'

prysm_validator_user='prysmvalidator'
prysm_validator_group='prysmvalidator'
prysm_validator_bin='/usr/local/bin/validator'
prysm_validator_datadir="/var/lib/prysm/validator"
prysm_validator_wallet_dir="/var/lib/prysm/validator/prysm-wallet-v2"
prysm_validator_wallet_password_file="/var/lib/prysm/validator/wallet-password.txt"
prysm_validator_unit_file="/etc/systemd/system/eth2-validator.service"