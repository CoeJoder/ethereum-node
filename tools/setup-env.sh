#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
# don't load env; it hasn't been generated yet
log_start
log_timestamp

# -------------------------- PRECONDITIONS ------------------------------------

check_executable_exists env_base_sh
print_failed_checks --error || exit

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

env_sh_stylized="${theme_filename}$env_sh${color_reset}"
env_sh_basename="${theme_filename}$(basename "$env_sh")${color_reset}"
cat <<EOF
Generates $env_sh_basename, an editable config file.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ -f $env_sh ]]; then
	printwarn "found existing $env_sh_stylized"
	continue_or_exit 1 "Overwrite?"
	printf '\n'
fi

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

# the Ethereum network to use (hoodi or mainnet)
ethereum_network='$ethereum_network'

# the local IP address of your router
router_ip_address='$router_ip_address'

# node server values used during initial setup
node_server_ssh_port=$node_server_ssh_port # TCP
node_server_timezone='$node_server_timezone'
node_server_hostname='$node_server_hostname'
node_server_username='$node_server_username'
node_server_secondary_storage='$node_server_secondary_storage'

# the location of the 'DATA' drive mount point
client_pc_usb_data_drive="/media/$USER/DATA"

# the location of the 'DATA' distribution
usb_dist_dir="$client_pc_usb_data_drive/$dist_dirname"

# the location of the \`bls-to-execution-changes\` signed messages
usb_bls_to_execution_changes_dir="$usb_dist_dir/bls_to_execution_changes"

# the location of the exported validator statuses
validator_statuses_json="$usb_dist_dir/validator_statuses.json"

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

# prysm max external connections
prysm_beacon_p2p_max_peers=$prysm_beacon_p2p_max_peers

# the hard-coded behavior is to use checkpoint-sync only on 'hoodi' testnet 
# these variables are ignored unless \`ethereum_network\` is set to 'hoodi'
prysm_beacon_checkpoint_sync_url='$prysm_beacon_checkpoint_sync_url'
prysm_beacon_genesis_beacon_api_url='$prysm_beacon_genesis_beacon_api_url'

EOF

chmod +x "$env_sh"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_executable_exists env_sh
print_failed_checks --error

cat <<EOF
Success!  Generated ${env_sh_stylized}
Edit the file with your custom values before proceeding to the next step.
EOF
