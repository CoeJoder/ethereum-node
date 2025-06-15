#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename ${BASH_SOURCE[0]}) [options]
		  --unit-files-only   If present, only the unit files are generated
		  --help, -h          Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,unit-files-only' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
(($? != 0)) && exit 1
eval set -- "$_parsed_args"
unset _parsed_args

unit_files_only=false

while true; do
	case "$1" in
	-h | --help)
		show_usage
		exit 0
		;;
	--unit-files-only)
		unit_files_only=true
		shift
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown argument: $1"
		exit 1
		;;
	esac
done

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

reset_checks

# geth
check_command_does_not_exist_on_path geth_bin
check_user_does_not_exist geth_user
check_group_does_not_exist geth_group
check_directory_does_not_exist --sudo geth_datadir
check_directory_does_not_exist --sudo geth_datadir_secondary
check_directory_does_not_exist --sudo geth_datadir_secondary_ancient

# prysm-beacon
check_executable_does_not_exist --sudo prysm_beacon_bin
check_user_does_not_exist prysm_beacon_user
check_group_does_not_exist prysm_beacon_group
check_directory_does_not_exist --sudo prysm_beacon_datadir
check_is_defined prysm_beacon_enable_checkpoint_sync

if [[ $prysm_beacon_enable_checkpoint_sync == true ]]; then
	check_is_defined prysm_beacon_checkpoint_sync_url
	check_is_defined prysm_beacon_genesis_beacon_api_url
fi

# ports
check_is_valid_port geth_port
check_is_valid_port geth_discovery_port
check_is_valid_port prysm_beacon_http_port
check_is_valid_port prysm_beacon_p2p_udp_port
check_is_valid_port prysm_beacon_p2p_quic_port
check_is_valid_port prysm_beacon_p2p_tcp_port

check_file_does_not_exist --sudo eth_jwt_file
check_is_valid_ethereum_network ethereum_network
[[ -n $suggested_fee_recipient ]] && check_is_valid_ethereum_address suggested_fee_recipient

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_green}${bold}"
cat <<EOF
              __                                                 __            
             /\ \__                                             /\ \           
  ____     __\ \ ,_\  __  __  _____              ___     ___    \_\ \     __   
 /',__\  /'__\`\ \ \/ /\ \/\ \/\ '__\`\  _______ /' _ \`\  / __\`\  /'_\` \  /'__\`\ 
/\__, \`\/\  __/\ \ \_\ \ \_\ \ \ \L\ \/\______\/\ \/\ \/\ \L\ \/\ \L\ \/\  __/ 
\/\____/\ \____\\\ \__\\\ \____/\ \ ,__/\/______/\ \_\ \_\ \____/\ \___,_\ \____\\
 \/___/  \/____/ \/__/ \/___/  \ \ \/           \/_/\/_/\/___/  \/__,_ /\/____/
                                \ \_\                                          
                                 \/_/                                          
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

if [[ $unit_files_only == true ]]; then
	echo "${theme_value}[UNIT FILES ONLY]${color_reset}"
fi
cat <<EOF
Installs geth (EL), prysm-beacon (CL), and generates the JWT secret shared between them.  Also configures the EL and CL to run as services.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

get_latest_prysm_version latest_prysm_version

prysm_beacon_cpsync_opts=""
if [[ $prysm_beacon_enable_checkpoint_sync == true ]]; then
	printinfo "checkpoint-sync enabled"
	prysm_beacon_cpsync_opts="--checkpoint-sync-url=\"$prysm_beacon_checkpoint_sync_url\" \\
	--genesis-beacon-api-url=\"$prysm_beacon_genesis_beacon_api_url\""

	cat <<-EOF
		Prysm-beacon checkpoint-sync URL: ${color_green}$prysm_beacon_checkpoint_sync_url${color_reset}
		Prysm-beacon genesis beacon API URL: ${color_green}$prysm_beacon_genesis_beacon_api_url${color_reset}
	EOF
else
	printinfo "checkpoint-sync disabled"
	prysm_beacon_checkpoint_sync_url=""
	prysm_beacon_genesis_beacon_api_url=""
fi

suggested_fee_recipient_opt=""
if [[ -n $suggested_fee_recipient ]]; then
	suggested_fee_recipient_opt="--suggested-fee-recipient=\"$suggested_fee_recipient\""
fi
continue_or_exit
printf '\n'

# if unit files already exist, confirm overwrite
reset_checks
check_file_does_not_exist --sudo geth_unit_file
check_file_does_not_exist --sudo prysm_beacon_unit_file
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
	printf '\n'
fi

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo

if [[ $unit_files_only == false ]]; then
	# system and app list updates
	printinfo Running APT update and upgrade...
	sudo apt-get -y update
	sudo apt-get -y upgrade

	# JWT secret
	printinfo "Generating JWT secret..."
	openssl rand -hex 32 | tr -d "\n" >"jwt.hex"
	sudo mkdir -p "$(dirname "$eth_jwt_file")"
	sudo mv -vf jwt.hex "$eth_jwt_file"
	sudo chmod 644 "$eth_jwt_file"

	# geth filesystem
	printinfo "Setting up geth user, group, datadir..."
	sudo useradd --no-create-home --shell /bin/false "$geth_user"
	sudo mkdir -p "$geth_datadir"
	sudo mkdir -p "$geth_datadir_secondary_ancient"
	sudo chown -R "${geth_user}:${geth_group}" ${geth_datadir}
	sudo chown -R "${geth_user}:${geth_group}" ${geth_datadir_secondary}
	sudo chmod -R 700 "${geth_datadir}"
	sudo chmod -R 700 "${geth_datadir_secondary}"

	# geth install
	printinfo "Installing geth..."
	sudo add-apt-repository -y ppa:ethereum/ethereum
	sudo apt-get -y update
	sudo apt-get -y install ethereum

	# prysm-beacon filesystem
	printinfo "Setting up prysm-beacon user, group, datadir..."
	sudo useradd --no-create-home --shell /bin/false "$prysm_beacon_user"
	sudo mkdir -p "$prysm_beacon_datadir"
	sudo chown -R "${prysm_beacon_user}:${prysm_beacon_group}" "$prysm_beacon_datadir"
	sudo chmod -R 700 "$prysm_beacon_datadir"

	# prysm-beacon install
	printinfo "Installing prysm-beacon..."
	install_prysm beacon-chain \
		"$latest_prysm_version" "$prysm_beacon_bin" "$prysm_beacon_user" "$prysm_beacon_group"
fi

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
	--http.api eth,net,engine,admin \\
	--db-engine pebble \\
	--state.scheme path 
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

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
	$suggested_fee_recipient_opt \\
	--jwt-secret="$eth_jwt_file" \\
	--monitoring-host="0.0.0.0" \\
	--accept-terms-of-use \\
	--execution-endpoint="http://localhost:8551" \\
	$prysm_beacon_cpsync_opts \\
	--http-port=$prysm_beacon_http_port \\
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

if [[ $unit_files_only == false ]]; then
	check_command_exists_on_path geth_bin
	check_user_exists geth_user
	check_group_exists geth_group
	check_directory_exists --sudo geth_datadir
	check_directory_exists --sudo geth_datadir_secondary
	check_directory_exists --sudo geth_datadir_secondary_ancient

	check_executable_exists --sudo prysm_beacon_bin
	check_user_exists prysm_beacon_user
	check_group_exists prysm_beacon_group
	check_directory_exists --sudo prysm_beacon_datadir

	check_file_exists --sudo eth_jwt_file
fi

check_file_exists --sudo geth_unit_file
check_file_exists --sudo prysm_beacon_unit_file

print_failed_checks --error

if [[ $unit_files_only == false ]]; then
	cat <<-EOF

	Success!  You are now ready to enable EL and CL services.
	EOF
else
	cat <<-EOF

	Unit files have been successfully updated.
	EOF
fi
