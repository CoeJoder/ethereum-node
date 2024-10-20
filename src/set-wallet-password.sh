#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_cyan}${bold}
          _                     _ _      _                            
 ___  ___| |_    __      ____ _| | | ___| |_      _ __   __ _ ___ ___ 
/ __|/ _ \ __|___\ \ /\ / / _\` | | |/ _ \ __|____| '_ \ / _\` / __/ __|
\__ \  __/ ||_____\ V  V / (_| | | |  __/ ||_____| |_) | (_| \__ \__ \\
|___/\___|\__|     \_/\_/ \__,_|_|_|\___|\__|    | .__/ \__,_|___/___/
                                                 |_|                  
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Saves the wallet password to a file, as required by prysm-validator.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

check_directory_exists --sudo prysm_validator_datadir
check_is_defined prysm_validator_wallet_password_file

# -------------------------- RECONNAISSANCE -----------------------------------

# read and confirm password
read -sp "Validator wallet password: " password1
printf '\n'

read -sp "Confirm password: " password2
printf '\n\n'

if [[ $password1 != $password2 ]]; then
	printerr "confirmation failed, try again"
	exit 1
fi

# if password file already exists, confirm overwrite
reset_checks
check_file_does_not_exist --sudo prysm_validator_wallet_password_file
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
	printf '\n'
	sudo rm -rf --interactive=never "$prysm_validator_wallet_password_file" 
fi

# -------------------------- EXECUTION ----------------------------------------

echo "$password1" | sudo tee "$prysm_validator_wallet_password_file" >/dev/null
sudo chown "${prysm_validator_user}:${prysm_validator_group}" "$prysm_validator_wallet_password_file"
sudo chmod 440 "$prysm_validator_wallet_password_file"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_file_exists --sudo prysm_validator_wallet_password_file
print_failed_checks --error # trapped

cat <<EOF
Password saved to ${theme_filename}$prysm_validator_wallet_password_file${color_reset}
EOF
