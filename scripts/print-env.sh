#!/bin/bash

# -------------------------- HEADER -------------------------------------------

scripts_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source "$scripts_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_lightgray}
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

# -------------------------- PRECONDITIONS ------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

cat <<EOF
suggested_fee_recipient=${color_green}$suggested_fee_recipient${color_reset}

ethereum_network=${color_green}$ethereum_network${color_reset}

router_ip_address=${color_green}$router_ip_address${color_reset}

node_server_ip_address=${color_green}$node_server_ip_address${color_reset}
node_server_ssh_port=${color_green}$node_server_ssh_port${color_reset} ${color_lightgray}# TCP${color_reset}
node_server_timezone=${color_green}$node_server_timezone${color_reset}
node_server_hostname=${color_green}$node_server_hostname${color_reset}
node_server_username=${color_green}$node_server_username${color_reset}
node_server_secondary_storage=${color_green}$node_server_secondary_storage${color_reset}

local_secrets_dir=${color_green}$local_secrets_dir${color_reset}
eth_jwt_file=${color_green}$eth_jwt_file${color_reset}

geth_user=${color_green}$geth_user${color_reset}
geth_group=${color_green}$geth_group${color_reset}
geth_bin=${color_green}$geth_bin${color_reset}
geth_datadir=${color_green}$geth_datadir${color_reset}
geth_unit_file=${color_green}$geth_unit_file${color_reset}
geth_port=${color_green}$geth_port${color_reset}           ${color_lightgray}# TCP${color_reset}
geth_discovery_port=${color_green}$geth_discovery_port${color_reset} ${color_lightgray}# UDP${color_reset}

prysm_beacon_user=${color_green}$prysm_beacon_user${color_reset}
prysm_beacon_group=${color_green}$prysm_beacon_group${color_reset}
prysm_beacon_bin=${color_green}$prysm_beacon_bin${color_reset}
prysm_beacon_datadir=${color_green}$prysm_beacon_datadir${color_reset}
prysm_beacon_unit_file=${color_green}$prysm_beacon_unit_file${color_reset}
prysm_beacon_p2p_tcp_port=${color_green}$prysm_beacon_p2p_tcp_port${color_reset}  ${color_lightgray}# TCP${color_reset}
prysm_beacon_p2p_quic_port=${color_green}$prysm_beacon_p2p_quic_port${color_reset} ${color_lightgray}# UDP${color_reset}
prysm_beacon_p2p_udp_port=${color_green}$prysm_beacon_p2p_udp_port${color_reset}  ${color_lightgray}# UDP${color_reset}
prysm_beacon_p2p_max_peers=${color_green}$prysm_beacon_p2p_max_peers${color_reset}

${color_lightgray}# the hard-coded behavior is to use checkpoint-sync only on 'holesky' testnet${color_reset}
prysm_beacon_checkpoint_sync_url=${color_green}$prysm_beacon_checkpoint_sync_url${color_reset}
prysm_beacon_genesis_beacon_api_url=${color_green}$prysm_beacon_genesis_beacon_api_url${color_reset}

prysm_validator_user=${color_green}$prysm_validator_user${color_reset}
prysm_validator_group=${color_green}$prysm_validator_group${color_reset}
prysm_validator_bin=${color_green}$prysm_validator_bin${color_reset}
prysm_validator_datadir=${color_green}$prysm_validator_datadir${color_reset}
prysm_validator_wallet_dir=${color_green}$prysm_validator_wallet_dir${color_reset}
prysm_validator_wallet_password_file=${color_green}$prysm_validator_wallet_password_file${color_reset}
prysm_validator_unit_file=${color_green}$prysm_validator_unit_file${color_reset}

EOF

# -------------------------- EXECUTION ----------------------------------------

# -------------------------- POSTCONDITIONS -----------------------------------
