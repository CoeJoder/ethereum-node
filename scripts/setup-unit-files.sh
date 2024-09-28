#!/bin/bash

# TODO tee the output to disk and add a systemctl daemon-reload command

# -------------------------- HEADER -------------------------------------------

scripts_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$scripts_dir/common.sh"

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_magenta}
░█▀▀░█▀▀░█▀█░█▀▀░█▀▄░█▀█░▀█▀░█▀▀░░░░    
░█░█░█▀▀░█░█░█▀▀░█▀▄░█▀█░░█░░█▀▀░▄▄▄    
░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░░░░    
░█░█░█▀█░▀█▀░▀█▀░░░░░█▀▀░▀█▀░█░░░█▀▀░█▀▀
░█░█░█░█░░█░░░█░░▄▄▄░█▀▀░░█░░█░░░█▀▀░▀▀█
░▀▀▀░▀░▀░▀▀▀░░▀░░░░░░▀░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Generates the systemd unit files for the Ethereum EL, CL, and validator
services, and reloads the service daemon.

EOF

press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server

check_is_valid_ethereum_network ethereum_network

check_is_valid_hexadecimal suggested_fee_recipient

check_command_exists_on_path geth_bin

check_executable_exists prysm_beacon_bin
check_executable_exists prysm_validator_bin

check_user_exists geth_user
check_user_exists prysm_beacon_user
check_user_exists prysm_validator_user

check_group_exists geth_group
check_group_exists prysm_beacon_group
check_group_exists prysm_validator_group

check_directory_exists geth_datadir
check_directory_exists geth_datadir_ancient
check_directory_exists prysm_dir
check_directory_exists prysm_beacon_datadir
check_directory_exists prysm_validator_datadir

check_file_exists eth_jwt_file

check_is_valid_port geth_port
check_is_valid_port geth_discovery_port
check_is_valid_port prysm_beacon_p2p_udp_port
check_is_valid_port prysm_beacon_p2p_quic_port
check_is_valid_port prysm_beacon_p2p_tcp_port

exit_if_failed_checks

# -------------------------- RECONNAISSANCE -----------------------------------

# display the env vars used in this script for confirmation
cat <<EOF

Ethereum network: ${color_green}$ethereum_network${color_reset}
Suggested fee recipient: ${color_green}$suggested_fee_recipient${color_reset}
JWT file: ${color_green}$eth_jwt_file${color_reset}

Geth user: ${color_green}$geth_user${color_reset}
Geth group: ${color_green}$geth_group${color_reset}
Geth executable: ${color_green}$geth_bin${color_reset}
Geth data-dir: ${color_green}$geth_datadir${color_reset}
Geth data-dir-ancient: ${color_green}$geth_datadir_ancient${color_reset}
Geth port: ${color_green}$geth_port${color_reset}
Geth discovery port: ${color_green}$geth_discovery_port${color_reset}

Prysm-beacon user: ${color_green}$prysm_beacon_user${color_reset}
Prysm-beacon group: ${color_green}$prysm_beacon_group${color_reset}
Prysm-beacon executable: ${color_green}$prysm_beacon_bin${color_reset}
Prysm-beacon data-dir: ${color_green}$prysm_beacon_datadir${color_reset}
Prysm-beacon P2P max peers: ${color_green}$prysm_beacon_p2p_max_peers${color_reset}
Prysm-beacon P2P UDP port: ${color_green}$prysm_beacon_p2p_udp_port${color_reset}
Prysm-beacon P2P quic port: ${color_green}$prysm_beacon_p2p_quic_port${color_reset}
Prysm-beacon P2P TCP port: ${color_green}$prysm_beacon_p2p_tcp_port${color_reset}
EOF

# only use checkpoint-sync on 'holesky' testnet, due to trust required
# see: https://docs.prylabs.network/docs/prysm-usage/checkpoint-sync
prysm_beacon_cpsync_opts=""
if [[ $ethereum_network == 'holesky' ]]; then
	printwarn "holesky network: checkpoint-sync enabled"
	prysm_beacon_cpsync_opts="--checkpoint-sync-url='$prysm_beacon_checkpoint_sync_url \\'
	--genesis-beacon-api-url='$prysm_beacon_genesis_beacon_api_url'"

	cat <<-EOF
	Prysm-beacon checkpoint-sync URL: ${color_green}$prysm_beacon_checkpoint_sync_url${color_reset}
	Prysm-beacon genesis beacon API URL: ${color_green}$prysm_beacon_genesis_beacon_api_url${color_reset}
EOF
else
	printwarn "non-holesky network: checkpoint-sync disabled"
	prysm_beacon_checkpoint_sync_url=""
	prysm_beacon_genesis_beacon_api_url=""
fi

cat <<EOF

Prysm-validator user: ${color_green}$prysm_validator_user${color_reset}
Prysm-validator group: ${color_green}$prysm_validator_group${color_reset}
Prysm-validator executable: ${color_green}$prysm_validator_bin${color_reset}
Prysm-validator data-dir: ${color_green}$prysm_validator_datadir${color_reset}
Prysm-validator wallet-dir: ${color_green}$prysm_validator_wallet_dir${color_reset}
Prysm-validator wallet password file: ${color_green}$prysm_validator_wallet_password_file${color_reset}

EOF

continue_or_exit 1

# -------------------------- EXECUTION ----------------------------------------

trap 'printerr_trap $? "$errmsg_retry"; exit $?' ERR

# writing `eth1.service`
cat <<EOF
[Unit]
Description=geth EL service
Wants=network-online.target
After=network-online.target
StartLimitInterval=120
StartLimitBurst=10

[Service]
User=$geth_user
Group=$geth_group
Type=simple
ExecStart=$geth_bin \\
	--$ethereum_network
	--authrpc.jwtsecret "$eth_jwt_file" \\
	--datadir "$geth_datadir" \\
	--datadir.ancient "$geth_datadir_ancient" \\
	--port $geth_port \\
	--discovery.port $geth_discovery_port
	--http \\
	--http.api eth,net,engine,admin \\
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF


# writing `eth2-beacon.service`
cat <<EOF
[Unit]
Description=prysm beacon CL service
Wants=network-online.target eth1.service
After=network-online.target
StartLimitInterval=120
StartLimitBurst=10

[Service]
User=$prysm_beacon_user
Group=$prysm_beacon_group
Type=simple
ExecStart=$prysm_beacon_bin \\
	--$ethereum_network \\
	--datadir="$prysm_beacon_datadir" \\
	--p2p-max-peers=$prysm_beacon_p2p_max_peers \\
	--suggested-fee-recipient=$suggested_fee_recipient \\
	--jwt-secret="$eth_jwt_file" \\
	--monitoring-host="0.0.0.0" \\
	--accept-terms-of-use \\
	--execution-endpoint=http://localhost:8551 \\
	$prysm_beacon_cpsync_opts \\
	--p2p-udp-port=$prysm_beacon_p2p_udp_port \\
	--p2p-quic-port=$prysm_beacon_p2p_quic_port \\
	--p2p-tcp-port=$prysm_beacon_p2p_tcp_port
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF

# writing `eth2-validator.service`
cat <<EOF
[Unit]
Description=prysm validator service
Wants=network-online.target eth2-beacon.service
After=network-online.target
StartLimitInterval=120
StartLimitBurst=10

[Service]
User=$prysm_validator_user
Group=$prysm_validator_group
Type=simple
ExecStart=$prysm_validator_bin \\
	--$ethereum_network \\
	--datadir "$prysm_validator_datadir" \\
	--wallet-dir "$prysm_validator_wallet_dir" \\
	--wallet-password-file "$prysm_validator_wallet_password_file" \\
	--suggested-fee-recipient "$suggested_fee_recipient" \\
	--accept-terms-of-use \\
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF

# -------------------------- POSTCONDITIONS -----------------------------------

cat <<EOF

Success!  The Ethereum node services are ready to be enabled.

EOF
