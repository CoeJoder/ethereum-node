#!/bin/bash

# -------------------------- HEADER -------------------------------------------

scripts_dir="$(realpath $(dirname ${BASH_SOURCE[0]}))"
source "$scripts_dir/common.sh"
# don't load env; it hasn't been generated yet
log_start
log_timestamp

# -------------------------- BANNER -------------------------------------------

echo -n "${color_blue}"
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

env_sh_stylized="${color_filename}$env_sh${color_reset}"
env_sh_basename="${color_filename}$(basename "$env_sh")${color_reset}"
cat <<EOF
Generates $env_sh_basename, an editable config file.
EOF

press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

check_executable_exists env_base_sh
exit_if_failed_checks

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ -f $env_sh ]]; then
	printwarn "found existing $env_sh_stylized"
	continue_or_exit 1 "Overwrite?"
fi

# -------------------------- EXECUTION ----------------------------------------

source "$env_base_sh"
cat <<EOF >"$env_sh"
#!/bin/bash

# Environment Variables
#
# Custom variable values which will override the defaults in $(basename "$env_base_sh")

# your Ethereum wallet address
suggested_fee_recipient=''

# the ethereum network to use (holesky or mainnet)
ethereum_network='$ethereum_network'

# the local IP address of your router
router_ip_address='$router_ip_address'

# node server values used during initial setup
node_server_ip_address='$node_server_ip_address'
node_server_ssh_port=$node_server_ssh_port # TCP
node_server_timezone='$node_server_timezone'
node_server_hostname='$node_server_hostname'
node_server_username='$node_server_username'
node_server_secondary_storage='$node_server_secondary_storage'

# external geth ports
geth_port=$geth_port           # TCP
geth_discovery_port=$geth_discovery_port # UDP
geth_datadir_secondary="\$node_server_secondary_storage/geth"
geth_datadir_secondary_ancient="\$geth_datadir_secondary/chaindata/ancient"

# external prysm ports
prysm_beacon_p2p_tcp_port=$prysm_beacon_p2p_tcp_port  # TCP
prysm_beacon_p2p_quic_port=$prysm_beacon_p2p_quic_port # UDP
prysm_beacon_p2p_udp_port=$prysm_beacon_p2p_udp_port  # UDP

# prysm max external connections
prysm_beacon_p2p_max_peers=$prysm_beacon_p2p_max_peers

# the hard-coded behavior is to use checkpoint-sync only on 'holesky' testnet 
# these variables are ignored unless \`ethereum_network\` is set to 'holesky'
prysm_beacon_checkpoint_sync_url='$prysm_beacon_checkpoint_sync_url'
prysm_beacon_genesis_beacon_api_url='$prysm_beacon_genesis_beacon_api_url'

EOF

chmod +x "$env_sh"

# -------------------------- POSTCONDITIONS -----------------------------------

cat <<EOF

Success!  Generated ${env_sh_stylized}
Edit the file with your custom values before proceeding to the next step.

EOF
