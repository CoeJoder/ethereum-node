#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
# don't load env; it hasn't been generated yet
log_start
log_timestamp

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks
check_executable_exists env_base_sh
check_directory_exists src_dir
check_is_valid_ethereum_network testnet
check_is_valid_ethereum_network mainnet
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -n "${color_blue}${bold}"
cat <<EOF
              __                                   
   ________  / /___  ______        ___  ____ _   __
  / ___/ _ \/ __/ / / / __ \______/ _ \/ __ \ | / /
 (__  )  __/ /_/ /_/ / /_/ /_____/  __/ / / / |/ / 
/____/\___/\__/\__,_/ .___/      \___/_/ /_/|___/  
                   /_/                             
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Generates an editable file containing the project's environment variables.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

function find_available_env_filename() {
	if (($# != 2)); then
		printerr "usage: find_available_env_filename network outvar"
		return 2
	fi
	local network="$1" outvar="$2" curfile i
	curfile="env.${network}.sh"
	for i in {1..9}; do
		if [[ ! -f "$src_dir/$curfile" ]]; then
			printf -v $outvar "$curfile"
			return 0
		fi
		curfile="env.${network}.${i}.sh"
	done
	return 1
}

function shorten_path() {
	if (($# != 2)); then
		printerr "usage: shorten_path filepath outvar"
		return 2
	fi
	local filepath="$1" outvar="$2"
	printf -v $outvar "$(basename "$(dirname "$filepath")")/$(basename "$filepath")"
}

# generate an env based on network
choose_from_menu "Select network:" chosen_network "$testnet" "$mainnet"
env_sh_basename="env.sh"
env_sh="$src_dir/$env_sh_basename"
shorten_path "$env_sh" env_sh_shortened

# if filename exists and user rejects overwrite, suggest alt filename
while [[ -f $env_sh ]]; do
	printwarn "found existing ${theme_filename}$env_sh_shortened${color_reset}"
	if yes_or_no --default-no "Overwrite?"; then
		break
	else
		if find_available_env_filename "$chosen_network" env_sh_basename; then
			read_default "Choose filename" "$env_sh_basename" env_sh_basename
		else
			read_no_default "Choose filename" env_sh_basename
		fi
		env_sh="$src_dir/$env_sh_basename"
		shorten_path "$env_sh" env_sh_shortened
	fi
done
printf '\n'

# -------------------------- EXECUTION ----------------------------------------

trap 'on_err_noretry' ERR

source "$env_base_sh"
cat <<EOF >"$env_sh"
#!/bin/bash

# Environment Variables
#
# Custom variable values which will override the defaults in $(basename "$env_base_sh")

# your Ethereum wallet addresses
suggested_fee_recipient=''
withdrawal=''

# the Ethereum network to use
ethereum_network='$chosen_network'

# node server values used during initial setup
node_server_ssh_port=$node_server_ssh_port # TCP
node_server_timezone='$node_server_timezone'
node_server_hostname='$node_server_hostname'
node_server_username='$node_server_username'
node_server_secondary_storage='$node_server_secondary_storage'

# the location of the 'DATA' drive mount point
client_pc_usb_data_drive="/media/\$USER/DATA"

# the location of the 'DATA' distribution
usb_dist_dir="\$client_pc_usb_data_drive/\$dist_dirname"

# the location of the \`bls-to-execution-changes\` signed messages
usb_bls_to_execution_changes_dir="\$usb_dist_dir/bls_to_execution_changes"

# the location of the exported validator statuses
validator_statuses_json="\$usb_dist_dir/validator_statuses.json"

# external geth ports
geth_port=$geth_port           # TCP
geth_discovery_port=$geth_discovery_port # UDP

# geth ancient chaindata location
geth_datadir_secondary="\$node_server_secondary_storage/geth"
geth_datadir_secondary_ancient="\$geth_datadir_secondary/chaindata/ancient"

# external prysm ports
prysm_beacon_p2p_tcp_port=$prysm_beacon_p2p_tcp_port  # TCP
prysm_beacon_p2p_quic_port=$prysm_beacon_p2p_quic_port # UDP
prysm_beacon_p2p_udp_port=$prysm_beacon_p2p_udp_port  # UDP

# prysm beacon API port & endpoint
prysm_beacon_http_port=$prysm_beacon_http_port      # TCP
prysm_validator_beacon_rest_api_endpoint="http://127.0.0.1:\$prysm_beacon_http_port"

# prysm max external connections
prysm_beacon_p2p_max_peers=$prysm_beacon_p2p_max_peers

# the hard-coded behavior is to use checkpoint-sync only on testnet 
# these variables are ignored unless \`ethereum_network\` is set to testnet
prysm_beacon_checkpoint_sync_url='$prysm_beacon_checkpoint_sync_url'
prysm_beacon_genesis_beacon_api_url='$prysm_beacon_genesis_beacon_api_url'

EOF

chmod +x "$env_sh"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_executable_exists env_sh
print_failed_checks --error

cat <<EOF
Success!  Generated ${theme_filename}$env_sh_shortened${color_reset}
Edit the file with your custom values before proceeding to the next step.
EOF
