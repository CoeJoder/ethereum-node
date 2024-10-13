#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_green}${bold}
              __                                                 __            
             /\ \__                                             /\ \           
  ____     __\ \ ,_\  __  __  _____              ___     ___    \_\ \     __   
 /',__\  /'__\`\ \ \/ /\ \/\ \/\ '__\`\  _______ /' _ \`\  / __\`\  /'_\` \  /'__\`\ 
/\__, \`\/\  __/\ \ \_\ \ \_\ \ \ \L\ \/\______\/\ \/\ \/\ \L\ \/\ \L\ \/\  __/ 
\/\____/\ \____\\\ \__\\\ \____/\ \ ,__/\/______/\ \_\ \_\ \____/\ \___,_\ \____\\
 \/___/  \/____/ \/__/ \/___/  \ \ \/           \/_/\/_/\/___/  \/__,_ /\/____/
                                \ \_\                                          
                                 \/_/                                          
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Installs geth (EL), prysm-beacon (CL), and generates the JWT secret shared between them.  Also configures the EL and CL to run as services.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

check_command_does_not_exist_on_path geth_bin
check_executable_does_not_exist --sudo prysm_beacon_bin
check_file_does_not_exist --sudo eth_jwt_file

check_is_valid_ethereum_network ethereum_network
check_is_valid_ethereum_address suggested_fee_recipient

check_user_exists geth_user
check_user_exists prysm_beacon_user
check_group_exists geth_group
check_group_exists prysm_beacon_group
check_directory_exists --sudo geth_datadir
check_directory_exists --sudo geth_datadir_secondary_ancient
check_directory_exists --sudo prysm_beacon_datadir

check_is_valid_port geth_port
check_is_valid_port geth_discovery_port
check_is_valid_port prysm_beacon_p2p_udp_port
check_is_valid_port prysm_beacon_p2p_quic_port
check_is_valid_port prysm_beacon_p2p_tcp_port

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

get_latest_prysm_version latest_prysm_version || exit

# display the env vars used in this script for confirmation
cat <<EOF

Ethereum network: ${color_green}$ethereum_network${color_reset}
Suggested fee recipient: ${color_green}$suggested_fee_recipient${color_reset}

Geth user: ${color_green}$geth_user${color_reset}
Geth group: ${color_green}$geth_group${color_reset}
Geth executable: ${color_green}$geth_bin${color_reset}
Geth data-dir: ${color_green}$geth_datadir${color_reset}
Geth data-dir-ancient: ${color_green}$geth_datadir_secondary_ancient${color_reset}
Geth port: ${color_green}$geth_port${color_reset}
Geth discovery port: ${color_green}$geth_discovery_port${color_reset}
JWT secret: ${color_green}$eth_jwt_file${color_reset}

Latest Prysm version: ${color_green}$latest_prysm_version${color_reset}
Prysm-beacon user: ${color_green}$prysm_beacon_user${color_reset}
Prysm-beacon group: ${color_green}$prysm_beacon_group${color_reset}
Prysm-beacon executable: ${color_green}$prysm_beacon_bin${color_reset}
Prysm-beacon data-dir: ${color_green}$prysm_beacon_datadir${color_reset}
Prysm-beacon P2P max peers: ${color_green}$prysm_beacon_p2p_max_peers${color_reset}
Prysm-beacon P2P UDP port: ${color_green}$prysm_beacon_p2p_udp_port${color_reset}
Prysm-beacon P2P quic port: ${color_green}$prysm_beacon_p2p_quic_port${color_reset}
Prysm-beacon P2P TCP port: ${color_green}$prysm_beacon_p2p_tcp_port${color_reset}
EOF
continue_or_exit 1

# only use checkpoint-sync on 'holesky' testnet, due to trust required
# see: https://docs.prylabs.network/docs/prysm-usage/checkpoint-sync
prysm_beacon_cpsync_opts=""
if [[ $ethereum_network == 'holesky' ]]; then
	printinfo "holesky network detected: checkpoint-sync enabled"
	prysm_beacon_cpsync_opts="--checkpoint-sync-url=\"$prysm_beacon_checkpoint_sync_url\" \\
	--genesis-beacon-api-url=\"$prysm_beacon_genesis_beacon_api_url\""

	cat <<-EOF
	Prysm-beacon checkpoint-sync URL: ${color_green}$prysm_beacon_checkpoint_sync_url${color_reset}
	Prysm-beacon genesis beacon API URL: ${color_green}$prysm_beacon_genesis_beacon_api_url${color_reset}
EOF
else
	printinfo "non-holesky network detected: checkpoint-sync disabled"
	prysm_beacon_checkpoint_sync_url=""
	prysm_beacon_genesis_beacon_api_url=""
fi
continue_or_exit 1

# if unit files already exist, confirm overwrite
reset_checks
check_file_does_not_exist --sudo geth_unit_file
check_file_does_not_exist --sudo prysm_beacon_unit_file
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
fi

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo

# system and app list updates
printinfo Running APT update and upgrade...
sudo apt-get -y update
sudo apt-get -y upgrade

# JWT secret
printinfo "Generating JWT secret..."
openssl rand -hex 32 | tr -d "\n" > "jwt.hex"
sudo mkdir -p "$(dirname "$eth_jwt_file")"
sudo mv -vf jwt.hex "$eth_jwt_file"
sudo chmod 644 "$eth_jwt_file"

# geth
printinfo "Installing geth..."
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get -y update
sudo apt-get -y install ethereum

# geth unit file
printinfo "Generating ${theme_filename}$geth_unit_file${color_reset}:"
cat <<EOF | sudo tee "$geth_unit_file"
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
	--$ethereum_network \\
	--authrpc.jwtsecret "$eth_jwt_file" \\
	--datadir "$geth_datadir" \\
	--datadir.ancient "$geth_datadir_secondary_ancient" \\
	--port $geth_port \\
	--discovery.port $geth_discovery_port \\
	--http \\
	--http.api eth,net,engine,admin
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# prysm-beacon
printinfo "Downloading prysm-beacon..."
download_prysm beacon-chain "$latest_prysm_version" latest_beacon_chain_bin
sudo chown -v ${prysm_beacon_user}:${prysm_beacon_group} "$latest_beacon_chain_bin"
sudo chmod -v 550 "$latest_beacon_chain_bin"
sudo mv -vf "$latest_beacon_chain_bin" "$prysm_beacon_bin"
sudo "$prysm_beacon_bin" --version

# prysm-beacon unit file
printinfo "Generating ${theme_filename}$prysm_beacon_unit_file${color_reset}:"
cat <<EOF | sudo tee "$prysm_beacon_unit_file"
[Unit]
Description=prysm beacon CL service
Wants=network-online.target $(basename "$geth_unit_file")
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
	--execution-endpoint="http://localhost:8551" \\
	$prysm_beacon_cpsync_opts \\
	--p2p-udp-port=$prysm_beacon_p2p_udp_port \\
	--p2p-quic-port=$prysm_beacon_p2p_quic_port \\
	--p2p-tcp-port=$prysm_beacon_p2p_tcp_port
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# reload system services
echo "Reloading services daemon..."
sudo systemctl daemon-reload

# -------------------------- POSTCONDITIONS -----------------------------------

assert_sudo

reset_checks
check_file_exists --sudo eth_jwt_file
check_file_exists --sudo geth_unit_file
check_file_exists --sudo prysm_beacon_unit_file
check_command_exists_on_path geth_bin
check_executable_exists --sudo prysm_beacon_bin

print_failed_checks --error

cat <<EOF

Success!  You are now ready to enable EL and CL services.
EOF
