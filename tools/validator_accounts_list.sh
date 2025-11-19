#!/bin/bash

# validator_accounts_list.sh
#
# Lists the validator account pubkeys and their on-chain indices.

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server

reset_checks
check_is_defined node_server_username
check_is_defined node_server_hostname
check_is_valid_port node_server_ssh_port
check_is_valid_ethereum_network ethereum_network
check_is_defined prysm_validator_bin
check_is_defined prysm_validator_wallet_dir
check_is_defined prysm_validator_wallet_password_file
check_is_defined prysm_validator_user
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"

# -------------------------- EXECUTION ----------------------------------------

ssh -p "$node_server_ssh_port" "$node_server_ssh_endpoint" -t "
	# list the full pubkeys
	sudo -u '$prysm_validator_user' '$prysm_validator_bin' accounts list --accept-terms-of-use --${ethereum_network} --wallet-dir='$prysm_validator_wallet_dir' --wallet-password-file='$prysm_validator_wallet_password_file' 2>/dev/null

	# list the indices on chain
	sudo -u '$prysm_validator_user' '$prysm_validator_bin' accounts list --accept-terms-of-use --${ethereum_network} --wallet-dir='$prysm_validator_wallet_dir' --wallet-password-file='$prysm_validator_wallet_password_file' --list-validator-indices 2>/dev/null
"

# -------------------------- POSTCONDITIONS -----------------------------------
