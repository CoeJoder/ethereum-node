#!/bin/bash

# set-wallet-password.sh
#
# Sets the validator wallet password.
#
# Meant to be run on the node server.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

reset_checks
check_user_exists prysm_validator_user
check_group_exists prysm_validator_group
check_directory_exists --sudo prysm_validator_datadir
check_is_defined prysm_validator_wallet_password_file
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_cyan}${bold}"
cat <<'EOF'
          _                     _ _      _                            
 ___  ___| |_    __      ____ _| | | ___| |_      _ __   __ _ ___ ___ 
/ __|/ _ \ __|___\ \ /\ / / _` | | |/ _ \ __|____| '_ \ / _` / __/ __|
\__ \  __/ ||_____\ V  V / (_| | | |  __/ ||_____| |_) | (_| \__ \__ \
|___/\___|\__|     \_/\_/ \__,_|_|_|\___|\__|    | .__/ \__,_|___/___/
                                                 |_|                  
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Saves the wallet password to a file, as required by prysm-validator.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

enter_password_and_confirm "Validator wallet password" password1

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
print_failed_checks --error

cat <<EOF
Password saved to ${theme_filename}$prysm_validator_wallet_password_file${color_reset}
EOF
