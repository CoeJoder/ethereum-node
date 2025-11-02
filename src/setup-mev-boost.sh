#!/bin/bash

# setup-mev-boost.sh
#
# Installs & configures the flashbots MEV-Boost client to run as a service.
#
# Meant to be run on the node server.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
source "$this_dir/mev-boost-relays.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename "${BASH_SOURCE[0]}") [options]
		  --unit-file-only   If present, only the unit files are generated
		  --no-banner        If present, banner is not displayed
		  --help, -h         Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,unit-file-only,no-banner' \
	--name "$(basename "${BASH_SOURCE[0]}")" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

unit_file_only=false
no_banner=false

while true; do
	case "$1" in
	-h | --help)
		show_usage
		exit 0
		;;
	--unit-file-only)
		unit_file_only=true
		shift
		;;
	--no-banner)
		no_banner=true
		shift
		;;
	--)
		shift
		break
		;;
	*)
		log error "unknown argument: $1"
		exit 1
		;;
	esac
done

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

reset_checks

if [[ $unit_file_only == true ]]; then
	check_executable_exists --sudo mevboost_bin
	check_user_exists mevboost_user
	check_group_exists mevboost_group
else
	check_executable_does_not_exist --sudo mevboost_bin
	check_user_does_not_exist mevboost_user
	check_group_does_not_exist mevboost_group
fi

check_is_defined mevboost_version
check_is_defined mevboost_sha256_checksum
check_is_defined mevboost_unit_file
check_is_defined mevboost_addr
check_is_defined mevboost_min_bid
check_is_boolean mevboost_enable

check_is_defined mainnet
check_is_defined testnet
check_is_valid_ethereum_network ethereum_network

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

if [[ $no_banner == false ]]; then
	show_banner "${color_green}${bold}" <<'EOF'
                       /$$                                                                          /$$                                      /$$    
                      | $$                                                                         | $$                                     | $$    
  /$$$$$$$  /$$$$$$  /$$$$$$   /$$   /$$  /$$$$$$          /$$$$$$/$$$$   /$$$$$$  /$$    /$$      | $$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$$/$$$$$$  
 /$$_____/ /$$__  $$|_  $$_/  | $$  | $$ /$$__  $$ /$$$$$$| $$_  $$_  $$ /$$__  $$|  $$  /$$/$$$$$$| $$__  $$ /$$__  $$ /$$__  $$ /$$_____/_  $$_/  
|  $$$$$$ | $$$$$$$$  | $$    | $$  | $$| $$  \ $$|______/| $$ \ $$ \ $$| $$$$$$$$ \  $$/$$/______/| $$  \ $$| $$  \ $$| $$  \ $$|  $$$$$$  | $$    
 \____  $$| $$_____/  | $$ /$$| $$  | $$| $$  | $$        | $$ | $$ | $$| $$_____/  \  $$$/        | $$  | $$| $$  | $$| $$  | $$ \____  $$ | $$ /$$
 /$$$$$$$/|  $$$$$$$  |  $$$$/|  $$$$$$/| $$$$$$$/        | $$ | $$ | $$|  $$$$$$$   \  $/         | $$$$$$$/|  $$$$$$/|  $$$$$$/ /$$$$$$$/ |  $$$$/
|_______/  \_______/   \___/   \______/ | $$____/         |__/ |__/ |__/ \_______/    \_/          |_______/  \______/  \______/ |_______/   \___/  
                                        | $$                                                                                                        
                                        | $$                                                                                                        
                                        |__/                                                                                                        
EOF
	
	# -------------------------- PREAMBLE -----------------------------------------

	cat <<-EOF
	Installs MEV-Boost on the node server.
	EOF
	press_any_key_to_continue
fi

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $mevboost_enable == false ]]; then
	log error "Env var ${theme_value}mevboost_enable${color_reset} must be set to ${theme_value}true${color_reset} to run this script."
	log warn "The beacon-chain and validator unit files must be regenerated after toggling ${theme_command}mevboost_enable${color_reset}!"
	exit 1
fi

# check for latest versions
declare latest_mevboost_version
get_latest_mevboost_version latest_mevboost_version

if [[ $mevboost_version != "$latest_mevboost_version" ]]; then
	log warn "New version of MEV-Boost detected: ${theme_value}$latest_mevboost_version${color_reset}"
	log warn "Update the env vars with the latest version and checksums, and then restart this script."
	exit 1
fi

mevboost_network_opt=""
mevboost_relay_opts=""

function build_relay_opts() {
	local relays=("$@")
	for i in "${!relays[@]}"; do
		mevboost_relay_opts="${mevboost_relay_opts}-relay ${relays[i]}"
		if ((i < ${#relays[@]} - 1)); then
			mevboost_relay_opts="${mevboost_relay_opts} \\"$'\n'$'\t'
		fi
	done
}

if [[ $ethereum_network == "$mainnet" ]]; then
	mevboost_network_opt="-$mainnet"
	build_relay_opts "${mevboost_relays_mainnet[@]}"
else
	mevboost_network_opt="-$testnet"
	build_relay_opts "${mevboost_relays_testnet[@]}"
fi

# if unit file already exist, confirm overwrite
reset_checks
check_file_does_not_exist --sudo mevboost_unit_file
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
	stderr
fi

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	log info "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
}

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo

if [[ $unit_file_only == false ]]; then
	# mevboost filesystem
	log warn "Setting up MEV-Boost user and group..."
	sudo useradd --no-create-home --shell /bin/false "$mevboost_user"

	# mevboost install
	log warn "Installing MEV-Boost..."
	install_mevboost \
		"$mevboost_version" "$mevboost_sha256_checksum" "$mevboost_bin" "$mevboost_user" "$mevboost_group"
fi

# mevboost unit file
log warn "Generating ${theme_filename}$mevboost_unit_file${color_reset}:"
cat <<EOF | sudo tee "$mevboost_unit_file"
[Unit]
Description=MEV-Boost Service for Ethereum ($ethereum_network)
Wants=network-online.target
After=network-online.target
StartLimitInterval=120
StartLimitBurst=10

[Service]
User=$mevboost_user
Group=$mevboost_group
Type=simple
Restart=always
RestartSec=5
ExecStart=$mevboost_bin \\
	$mevboost_network_opt \\
	-min-bid $mevboost_min_bid \\
	-relay-check \\
	-addr $mevboost_addr \\
	$mevboost_relay_opts

[Install]
WantedBy=multi-user.target
EOF

# reload system services
stderr "Reloading services daemon..."
sudo systemctl daemon-reload

# -------------------------- POSTCONDITIONS -----------------------------------

assert_sudo

reset_checks

if [[ $unit_file_only == false ]]; then
	check_executable_exists --sudo mevboost_bin
	check_user_exists mevboost_user
	check_group_exists mevboost_group
fi

check_file_exists --sudo mevboost_unit_file

print_failed_checks --error

if [[ $unit_file_only == false ]]; then
	cat <<-EOF

	Success!  You are now ready to enable the MEV-Boost service.
	EOF
else
	cat <<-EOF

	Unit file has been successfully updated.
	EOF
fi
