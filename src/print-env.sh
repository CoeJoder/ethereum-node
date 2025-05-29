#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_lightgray}${bold}
 _______ _______ _______ _______ _______     _______ _______ _______ 
|\     /|\     /|\     /|\     /|\     /|   |\     /|\     /|\     /|
| +---+ | +---+ | +---+ | +---+ | +---+ |   | +---+ | +---+ | +---+ |
| |   | | |   | | |   | | |   | | |   | |   | |   | | |   | | |   | |
| |p  | | |r  | | |i  | | |n  | | |t  | |   | |e  | | |n  | | |v  | |
| +---+ | +---+ | +---+ | +---+ | +---+ |   | +---+ | +---+ | +---+ |
|/_____\|/_____\|/_____\|/_____\|/_____\|   |/_____\|/_____\|/_____\|
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Prints the project environment variables to the terminal.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

cat <<EOF
suggested_fee_recipient=${color_green}$suggested_fee_recipient${color_reset}
withdrawal=${color_green}$withdrawal${color_reset}

ethereum_network=${color_green}$ethereum_network${color_reset}

node_server_ssh_port=${color_green}$node_server_ssh_port${color_reset} ${color_lightgray}# TCP${color_reset}
node_server_timezone=${color_green}$node_server_timezone${color_reset}
node_server_hostname=${color_green}$node_server_hostname${color_reset}
node_server_username=${color_green}$node_server_username${color_reset}
node_server_secondary_storage=${color_green}$node_server_secondary_storage${color_reset}

eth_jwt_file=${color_green}$eth_jwt_file${color_reset}
client_pc_usb_data_drive=${color_green}$client_pc_usb_data_drive${color_reset}
usb_dist_dir=${color_green}$usb_dist_dir${color_reset}
usb_bls_to_execution_changes_dir=${color_green}$usb_bls_to_execution_changes_dir${color_reset}
validator_statuses_json=${color_green}$validator_statuses_json${color_reset}

geth_user=${color_green}$geth_user${color_reset}
geth_group=${color_green}$geth_group${color_reset}
geth_bin=${color_green}$geth_bin${color_reset}
geth_datadir=${color_green}$geth_datadir${color_reset}
geth_datadir_secondary=${color_green}$geth_datadir_secondary${color_reset}
geth_datadir_secondary_ancient=${color_green}$geth_datadir_secondary_ancient${color_reset}
geth_unit_file=${color_green}$geth_unit_file${color_reset}
geth_port=${color_green}$geth_port${color_reset}           ${color_lightgray}# TCP${color_reset}
geth_discovery_port=${color_green}$geth_discovery_port${color_reset} ${color_lightgray}# UDP${color_reset}

prysm_beacon_user=${color_green}$prysm_beacon_user${color_reset}
prysm_beacon_group=${color_green}$prysm_beacon_group${color_reset}
prysm_beacon_bin=${color_green}$prysm_beacon_bin${color_reset}
prysm_beacon_datadir=${color_green}$prysm_beacon_datadir${color_reset}
prysm_beacon_unit_file=${color_green}$prysm_beacon_unit_file${color_reset}
prysm_beacon_http_port=${color_green}$prysm_beacon_http_port${color_reset}      ${color_lightgray}# TCP${color_reset}
prysm_beacon_p2p_tcp_port=${color_green}$prysm_beacon_p2p_tcp_port${color_reset}  ${color_lightgray}# TCP${color_reset}
prysm_beacon_p2p_quic_port=${color_green}$prysm_beacon_p2p_quic_port${color_reset} ${color_lightgray}# UDP${color_reset}
prysm_beacon_p2p_udp_port=${color_green}$prysm_beacon_p2p_udp_port${color_reset}  ${color_lightgray}# UDP${color_reset}
prysm_beacon_p2p_max_peers=${color_green}$prysm_beacon_p2p_max_peers${color_reset}

${color_lightgray}# the hard-coded behavior is to use checkpoint-sync only on testnet${color_reset}
${color_lightgray}# these variables are ignored unless \`ethereum_network\` is set to testnet${color_reset}
prysm_beacon_checkpoint_sync_url=${color_green}$prysm_beacon_checkpoint_sync_url${color_reset}
prysm_beacon_genesis_beacon_api_url=${color_green}$prysm_beacon_genesis_beacon_api_url${color_reset}

prysm_validator_user=${color_green}$prysm_validator_user${color_reset}
prysm_validator_group=${color_green}$prysm_validator_group${color_reset}
prysm_validator_bin=${color_green}$prysm_validator_bin${color_reset}
prysm_validator_datadir=${color_green}$prysm_validator_datadir${color_reset}
prysm_validator_keys_dir=${color_green}$prysm_validator_keys_dir${color_reset}
prysm_validator_wallet_dir=${color_green}$prysm_validator_wallet_dir${color_reset}
prysm_validator_wallet_password_file=${color_green}$prysm_validator_wallet_password_file${color_reset}
prysm_validator_unit_file=${color_green}$prysm_validator_unit_file${color_reset}
prysm_validator_beacon_rest_api_endpoint=${color_green}$prysm_validator_beacon_rest_api_endpoint${color_reset}

prysmctl_user=${color_green}$prysmctl_user${color_reset}
prysmctl_group=${color_green}$prysmctl_group${color_reset}
prysmctl_bin=${color_green}$prysmctl_bin${color_reset}
prysmctl_datadir=${color_green}$prysmctl_datadir${color_reset}

ethdo_user=${color_green}$ethdo_user${color_reset}
ethdo_group=${color_green}$ethdo_group${color_reset}
ethdo_version=${color_green}$ethdo_version${color_reset}
ethdo_sha256_checksum=${color_green}$ethdo_sha256_checksum${color_reset}
ethdo_bin=${color_green}$ethdo_bin${color_reset}
ethereal_version=${color_green}$ethereal_version${color_reset}
ethereal_sha256_checksum=${color_green}$ethereal_sha256_checksum${color_reset}
ethereal_bin=${color_green}$ethereal_bin${color_reset}

ethstaker_deposit_cli_version=${color_green}$ethstaker_deposit_cli_version${color_reset}
ethstaker_deposit_cli_sha256_checksum=${color_green}$ethstaker_deposit_cli_sha256_checksum${color_reset}
ethstaker_deposit_cli_basename=${color_green}$ethstaker_deposit_cli_basename${color_reset}
ethstaker_deposit_cli_basename_sha256=${color_green}$ethstaker_deposit_cli_basename_sha256${color_reset}
ethstaker_deposit_cli_url=${color_green}$ethstaker_deposit_cli_url${color_reset}
ethstaker_deposit_cli_sha256_url=${color_green}$ethstaker_deposit_cli_sha256_url${color_reset}

jq_version=${color_green}$jq_version${color_reset}
jq_bin=${color_green}$jq_bin${color_reset}
jq_bin_sha256=${color_green}$jq_bin_sha256${color_reset}
jq_bin_dist=${color_green}$jq_bin_dist${color_reset}
jq_bin_sha256_dist=${color_green}$jq_bin_sha256_dist${color_reset}
EOF

# -------------------------- EXECUTION ----------------------------------------

# -------------------------- POSTCONDITIONS -----------------------------------
