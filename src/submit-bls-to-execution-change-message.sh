#!/bin/bash

# submit-bls-to-execution-change-message.sh
#
# Submits a signed `bls-to-execution-change` message to the Ethereum network
# via the local beacon-node using `prysmctl`.
#
# Meant to be run on the node server.  Typically called remotely from the
# client PC `withdraw.sh` script but can be run directly.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename ${BASH_SOURCE[0]}) [options]
		  --path value   Path to the signed withdrawal message JSON
		  --help, -h     Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,path:' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

mnemonic=''

while true; do
	case "$1" in
	-h | --help)
		show_usage
		exit 0
		;;
	--path)
		message_path="$2"
		shift 2
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

# validate opts
reset_checks
check_file_exists message_path
print_failed_checks --error

assert_on_node_server
assert_sudo

reset_checks
check_executable_exists --sudo prysmctl_bin
check_is_valid_ethereum_network ethereum_network
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_green}${bold}"
cat <<'EOF'
░█▀▀░█░█░█▀▄░█▄█░▀█▀░▀█▀░░░░░█▀▄░█░░░█▀▀░░░░░▀█▀░█▀█░░░░░█▀▀░█░█░█▀▀░█▀▀░█░█░▀█▀
░▀▀█░█░█░█▀▄░█░█░░█░░░█░░▄▄▄░█▀▄░█░░░▀▀█░▄▄▄░░█░░█░█░▄▄▄░█▀▀░▄▀▄░█▀▀░█░░░█░█░░█░
░▀▀▀░▀▀▀░▀▀░░▀░▀░▀▀▀░░▀░░░░░░▀▀░░▀▀▀░▀▀▀░░░░░░▀░░▀▀▀░░░░░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░░▀░
░▀█▀░█▀█░█▀█░░░░░█▀▀░█░█░█▀█░█▀█░█▀▀░█▀▀░░░░░█▄█░█▀▀░█▀▀░█▀▀░█▀█░█▀▀░█▀▀        
░░█░░█░█░█░█░▄▄▄░█░░░█▀█░█▀█░█░█░█░█░█▀▀░▄▄▄░█░█░█▀▀░▀▀█░▀▀█░█▀█░█░█░█▀▀        
░▀▀▀░▀▀▀░▀░▀░░░░░▀▀▀░▀░▀░▀░▀░▀░▀░▀▀▀░▀▀▀░░░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀▀▀        
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<'EOF'
Submits a signed `bls-to-execution-change` message to the Ethereum network
via the local beacon-node using `prysmctl`.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

message_filename="$(basename "$message_path")"

# -------------------------- EXECUTION ----------------------------------------

assert_sudo
trap 'on_err_retry' ERR

# copy the message into a prysmctl-owned temp dir
temp_dir="$(sudo -u "$prysmctl_user" mktemp -d)"
sudo cp -v "$message_path" "$temp_dir"
message_path="$temp_dir/$message_filename"
sudo chown -c "$prysmctl_user:$prysmctl_group" "$message_path"

function on_exit() {
	printinfo -n "Cleaning up..."
	sudo rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}
trap 'on_exit' EXIT

printinfo "Ready to invoke prysmctl the following way:${theme_command}"
cat <<EOF
sudo -u "$prysmctl_user" "$prysmctl_bin" validator withdraw \\
	--path="$message_path" \\
	--confirm \\
	--accept-terms-of-use
EOF
echo -ne "${color_reset}"
continue_or_exit

sudo -u "$prysmctl_user" "$prysmctl_bin" validator withdraw \
	--path="$message_path" \
	--confirm \
	--accept-terms-of-use

# -------------------------- POSTCONDITIONS -----------------------------------

beaconchain_url_subdomain=''
if [[ $ethereum_network != 'mainnet' ]]; then
	beaconchain_url_subdomain="${ethereum_network}."
fi
beaconchain_validator_url="https://${beaconchain_url_subdomain}beaconcha.in/validator/[pubkey or index]"

cat <<EOF
To confirm on-chain, browse to $beaconchain_validator_url and check that your validator(s) have withdrawal credentials prefixed with \`0x01\`.
EOF
