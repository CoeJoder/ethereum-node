#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename ${BASH_SOURCE[0]}) [options]
		  --unit-file-only   If present, only generate the unit file
		  --help, -h         Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,unit-file-only' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
(($? != 0)) && exit 1
eval set -- "$_parsed_args"
unset _parsed_args

unit_file_only=false

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

if [[ $unit_file_only == true ]]; then
	check_executable_exists --sudo prysm_validator_bin

	check_user_exists prysm_validator_user
	check_group_exists prysm_validator_group
	check_directory_exists --sudo prysm_validator_datadir
	check_group_exists prysmctl_group
else
	check_executable_does_not_exist --sudo prysm_validator_bin

	check_user_does_not_exist prysm_validator_user
	check_group_does_not_exist prysm_validator_group
	check_directory_does_not_exist --sudo prysm_validator_datadir
	check_group_exists prysmctl_group
fi

check_is_valid_ethereum_network ethereum_network
check_is_valid_ethereum_address suggested_fee_recipient

check_is_defined prysm_validator_unit_file
check_is_service_active geth_unit_file
check_is_service_active prysm_beacon_unit_file

check_is_valid_port prysm_beacon_http_port

check_is_boolean mevboost_enable

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_green}${bold}"
cat <<'EOF'
            _____                                         
______________  /____  _________                          
__  ___/  _ \  __/  / / /__  __ \_______                  
_(__  )/  __/ /_ / /_/ /__  /_/ //_____/                  
/____/ \___/\__/ \__,_/ _  .___/                          
                        /_/                               
              ___________________      _____              
___   _______ ___  /__(_)_____  /_____ __  /______________
__ | / /  __ `/_  /__  /_  __  /_  __ `/  __/  __ \_  ___/
__ |/ // /_/ /_  / _  / / /_/ / / /_/ // /_ / /_/ /  /    
_____/ \__,_/ /_/  /_/  \__,_/  \__,_/ \__/ \____//_/     
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

if [[ $unit_file_only == true ]]; then
	echo "${theme_value}[UNIT FILE ONLY]${color_reset}"
fi
cat <<EOF
Installs prysm-validator and configures it to run as a service.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

get_latest_prysm_version latest_prysm_version

prysm_validator_mevboost_opt=""
if [[ $mevboost_enable == true ]]; then
	prysm_validator_mevboost_opt="--enable-builder"
fi

# if unit file already exists, confirm overwrite
reset_checks
check_file_does_not_exist prysm_validator_unit_file
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

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo

if [[ $unit_file_only == false ]]; then
	# system and app list updates
	printinfo Running APT update and upgrade...
	sudo apt-get -y update
	sudo apt-get -y upgrade

	# prysm-validator filesystem
	printinfo "Setting up prysm-validator user, group, datadir..."
	sudo useradd --no-create-home --shell /bin/false "$prysm_validator_user"
	sudo mkdir -p "$prysm_validator_datadir"
	sudo chown -R "${prysm_validator_user}:${prysm_validator_group}" "$prysm_validator_datadir"
	sudo chmod -R 700 "$prysm_validator_datadir"
	sudo usermod -a -G "$prysmctl_group" "$prysm_validator_user"

	# prysm-validator install
	printinfo "Downloading prysm-validator..."
	install_prysm validator \
		"$latest_prysm_version" "$prysm_validator_bin" "$prysm_validator_user" "$prysm_validator_group"
fi

# prysm-validator unit file
printinfo "Generating ${theme_filename}$prysm_validator_unit_file${color_reset}:"
cat <<EOF | sudo tee "$prysm_validator_unit_file"
[Unit]
Description=prysm validator service
Wants=network-online.target $(basename "$prysm_beacon_unit_file")
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
	--beacon-rest-api-provider "$prysm_validator_beacon_rest_api_endpoint" \\
	$prysm_validator_mevboost_opt \\
	--accept-terms-of-use
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# reload system services
echo "Reloading services daemon..."
sudo systemctl daemon-reload

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks

check_executable_exists --sudo prysm_validator_bin
check_user_exists prysm_validator_user
check_group_exists prysm_validator_group
check_directory_exists --sudo prysm_validator_datadir
check_file_exists --sudo prysm_validator_unit_file

print_failed_checks --error

cat <<EOF

Success!  You are now ready to enable the validator service.
EOF
