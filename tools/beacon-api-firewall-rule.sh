#!/bin/bash

# beacon-api-firewall-rule.sh
#
# Adds or deletes a firewall rule allowing access to the Beacon API.
#
# Meant to be run on the client PC.

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage:
		  $(basename "${BASH_SOURCE[0]}") [options] command
		Options:
		  --address value   Target IP address.  Omit to use local interface address
		  --help, -h        Show this message
		Commands:
		  a, add            Add a rule allowing the target IP address
		  d, delete         Delete the rule allowing the target IP address
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='address:,help' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

address=''
command_add=false
command_delete=false

while true; do
	case "$1" in
	--address)
		address="$2"
		shift 2
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown option: $1"
		exit 1
		;;
	esac
done

# parse command
while (($#)); do
	case $1 in
	a | add)
		command_add=true
		shift 1
		;;
	d | delete)
		command_delete=true
		shift 1
		;;
	*)
		[[ -n $1 ]] && printerr "unknown command: $1"
		exit 1
		;;
	esac
done

if [[ $command_add == false && $command_delete == false ]]; then
	printerr "command missing"
	exit 1
elif [[ $command_add == true && $command_delete == true ]]; then
	printerr "multiple commands"
	exit 1
fi

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks

for _command in dig ip jq; do
	check_command_exists_on_path _command
done

[[ -n $address ]] && check_is_valid_ipv4_address address
check_is_valid_port prysm_beacon_http_port
check_is_valid_port node_server_ssh_port
check_is_defined node_server_username
check_is_defined node_server_hostname

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_red}${bold}" <<'EOF'
 _                                                  _        __ _                        _ _                  _      
| |__   ___  __ _  ___ ___  _ __         __ _ _ __ (_)      / _(_)_ __ _____      ____ _| | |      _ __ _   _| | ___ 
| '_ \ / _ \/ _` |/ __/ _ \| '_ \ _____ / _` | '_ \| |_____| |_| | '__/ _ \ \ /\ / / _` | | |_____| '__| | | | |/ _ \
| |_) |  __/ (_| | (_| (_) | | | |_____| (_| | |_) | |_____|  _| | | |  __/\ V  V / (_| | | |_____| |  | |_| | |  __/
|_.__/ \___|\__,_|\___\___/|_| |_|      \__,_| .__/|_|     |_| |_|_|  \___| \_/\_/ \__,_|_|_|     |_|   \__,_|_|\___|
                                             |_|                                                                     
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<-EOF

	Adds or deletes a firewall rule allowing access to the Beacon API.
	Meant to be run on the client PC.

	${color_red}${bold}DON'T USE THIS IN PRODUCTION.  USE SSH TUNNELING INSTEAD.${color_reset}

EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"

node_server_ip_address="$(dig +short "$node_server_hostname")"
reset_checks
check_is_valid_ipv4_address node_server_ip_address
print_failed_checks --error

printinfo "$node_server_hostname has address ${color_yellow}$node_server_ip_address${color_reset}"

# use the commandline option if provided
client_pc_ip_address="$address"
if [[ -z $address ]]; then
	# detect the IPv4 address of the local interface which connects to the node server
	client_pc_ip_address="$(ip -4 -j route get "$node_server_ip_address" | jq -r '.[0].prefsrc')"
	reset_checks
	check_is_valid_ipv4_address client_pc_ip_address
	print_failed_checks --error

	printinfo "Local interface connects to node server from address ${theme_value}${bold}$client_pc_ip_address${color_reset}\n"
fi

if [[ $command_add == true ]]; then
	continue_or_exit 1 "Add firewall rule to allow ${theme_value}${bold}$client_pc_ip_address${color_reset} access to Beacon API (${color_yellow}http://$node_server_ip_address:$prysm_beacon_http_port${color_reset})?"
else
	continue_or_exit 1 "Delete firewall rule allowing ${theme_value}${bold}$client_pc_ip_address${color_reset} access to Beacon API (${color_yellow}http://$node_server_ip_address:$prysm_beacon_http_port${color_reset})?"
fi

# -------------------------- EXECUTION ----------------------------------------

ssh -p $node_server_ssh_port $node_server_ssh_endpoint -t "
	set -e
	source \"\$HOME/$dist_dirname/common.sh\"
	printinfo \"Logged into node server.\"

	assert_sudo

	if [[ '$command_add' == true ]]; then
		sudo ufw allow proto tcp from $client_pc_ip_address to any port $prysm_beacon_http_port comment 'Allow $client_pc_ip_address access to Beacon API (TCP)'
	else
		sudo ufw delete allow proto tcp from $client_pc_ip_address to any port $prysm_beacon_http_port comment 'Allow $client_pc_ip_address access to Beacon API (TCP)'
	fi

	sudo ufw status
"

# -------------------------- POSTCONDITIONS -----------------------------------

printinfo "Check that the above firewall rules are correct."
