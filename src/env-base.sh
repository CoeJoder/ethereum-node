#!/bin/bash

# Environment Variables - Base
#
# DO NOT EDIT THIS FILE!
# Run `setup-env.sh` to generate an editable `env.sh` file.

# the Ethereum network to use (holesky or mainnet)
ethereum_network='holesky'

# the local IP address of your router
router_ip_address='192.168.1.1'

# node server values used during initial setup
node_server_ssh_port=55522 # TCP
node_server_timezone='America/Los_Angeles'
node_server_hostname='eth-node-mainnet'
node_server_username='coejoder'
node_server_secondary_storage='/mnt/secondary'

# the location of the JWT secret shared between EL and CL
eth_jwt_file='/usr/local/secrets/eth_jwt.hex'

# the location of the 'DATA' drive mount point
client_pc_usb_data_drive="/media/$USER/DATA"

# the location of the 'DATA' distribution
usb_dist_dir="$client_pc_usb_data_drive/$dist_dirname"

# the location of the exported validator statuses
validator_statuses_json="$usb_dist_dir/validator_statuses.json"

# geth values
geth_user='goeth'
geth_group='goeth'
geth_bin='geth'
geth_datadir='/var/lib/goeth'
geth_unit_file='/etc/systemd/system/eth1.service'
geth_port=30303           # TCP
geth_discovery_port=30303 # UDP
geth_datadir_secondary="$node_server_secondary_storage/geth"
geth_datadir_secondary_ancient="$geth_datadir_secondary/chaindata/ancient"

# prysm-beacon values
prysm_beacon_user='prysmbeacon'
prysm_beacon_group='prysmbeacon'
prysm_beacon_bin='/usr/local/bin/beacon-chain'
prysm_beacon_datadir='/var/lib/prysm/beacon'
prysm_beacon_unit_file='/etc/systemd/system/eth2-beacon.service'
prysm_beacon_p2p_tcp_port=13000  # TCP
prysm_beacon_p2p_quic_port=13000 # UDP
prysm_beacon_p2p_udp_port=12000  # UDP
prysm_beacon_p2p_max_peers=30

# the hard-coded behavior is to use checkpoint-sync only on 'holesky' testnet 
# these variables are ignored unless `ethereum_network` is set to 'holesky'
prysm_beacon_checkpoint_sync_url='https://holesky.beaconstate.info'
prysm_beacon_genesis_beacon_api_url='https://holesky.beaconstate.info'

# prysm-validator values
prysm_validator_user='prysmvalidator'
prysm_validator_group='prysmvalidator'
prysm_validator_bin='/usr/local/bin/validator'
prysm_validator_datadir='/var/lib/prysm/validator'
prysm_validator_keys_dir='/var/lib/prysm/validator/validator_keys'
prysm_validator_wallet_dir='/var/lib/prysm/validator/prysm-wallet-v2'
prysm_validator_wallet_password_file='/var/lib/prysm/validator/wallet-password.txt'
prysm_validator_unit_file='/etc/systemd/system/eth2-validator.service'

# Ethereum Staking Deposit CLI values
ethereum_staking_deposit_cli_version='v2.7.0'
ethereum_staking_deposit_cli_sha256_checksum='ac3151843d681c92ae75567a88fbe0e040d53c21368cc1ed1a8c3d9fb29f2a3a'
ethereum_staking_deposit_cli_basename='staking_deposit-cli-fdab65d-linux-amd64.tar.gz'
ethereum_staking_deposit_cli_basename_sha256="${deposit_cli_basename}.sha256"
ethereum_staking_deposit_cli_url="https://github.com/ethereum/staking-deposit-cli/releases/download/v2.7.0/${ethereum_staking_deposit_cli_basename}"

# Portable `jq` values
jq_version='jq-1.7.1'
jq_bin='jq-linux-amd64'
jq_bin_sha256='jq-linux-amd64.sha256'
jq_bin_dist="$usb_dist_dir/$jq_bin"
jq_bin_sha256_dist="$usb_dist_dir/$jq_bin_sha256"
