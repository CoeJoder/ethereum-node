#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_green}
            _____                                         
______________  /____  _________                          
__  ___/  _ \  __/  / / /__  __ \_______                  
_(__  )/  __/ /_ / /_/ /__  /_/ //_____/                  
/____/ \___/\__/ \__,_/ _  .___/                          
                        /_/                               
              ___________________      _____              
___   _______ ___  /__(_)_____  /_____ __  /______________
__ | / /  __ \`/_  /__  /_  __  /_  __ \`/  __/  __ \_  ___/
__ |/ // /_/ /_  / _  / / /_/ / / /_/ // /_ / /_/ /  /    
_____/ \__,_/ /_/  /_/  \__,_/  \__,_/ \__/ \____//_/     
${color_reset}
EOF

exit 0

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Installs prysm-validator and configures it to run as a service.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

check_is_service_active geth_unit_file
check_is_service_active prysm_beacon_unit_file

check_executable_does_not_exist --sudo prysm_validator_bin

check_is_valid_ethereum_network ethereum_network
check_is_valid_ethereum_address suggested_fee_recipient

check_user_exists prysm_validator_user
check_group_exists prysm_validator_group
check_directory_exists --sudo prysm_validator_datadir

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

get_latest_prysm_version latest_prysm_version || exit 1

# display the env vars used in this script for confirmation
cat <<EOF
Ethereum network: ${color_green}$ethereum_network${color_reset}
Suggested fee recipient: ${color_green}$suggested_fee_recipient${color_reset}

Latest Prysm version: ${color_green}$latest_prysm_version${color_reset}
Prysm-validator user: ${color_green}$prysm_validator_user${color_reset}
Prysm-validator group: ${color_green}$prysm_validator_group${color_reset}
Prysm-validator executable: ${color_green}$prysm_validator_bin${color_reset}
Prysm-validator data-dir: ${color_green}$prysm_validator_datadir${color_reset}
Prysm-validator wallet-dir: ${color_green}$prysm_validator_wallet_dir${color_reset}
Prysm-validator wallet password file: ${color_green}$prysm_validator_wallet_password_file${color_reset}
EOF
continue_or_exit 1

# if unit file already exists, confirm overwrite
reset_checks
check_file_does_not_exist prysm_validator_unit_file
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
sudo apt-get -y update
sudo apt-get -y upgrade

# prysm-validator
printinfo "Downloading prysm-validator..."
download_prysm validator "$latest_prysm_version" latest_validator_bin
sudo chown -v ${prysm_validator_user}:${prysm_validator_group} "$latest_validator_bin"
sudo chmod -v 550 "$latest_validator_bin"
sudo mv -vf "$latest_validator_bin" "$prysm_validator_bin"
sudo "$prysm_validator_bin" --version

# prysm-validator unit file
echo -e "\n${theme_filename}$prysm_validator_unit_file${color_reset}"
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
check_file_exists prysm_validator_unit_file

print_failed_checks --error

cat <<EOF

Success!  You are now ready to enable the validator service.
EOF
