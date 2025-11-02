#!/bin/bash

# exit.sh
#
# Performs a voluntary exit of one or more validators.
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
check_is_defined filter_active
check_is_valid_ethereum_network ethereum_network
check_executable_exists --sudo prysmctl_bin
check_directory_exists --sudo prysm_validator_wallet_dir
check_file_exists --sudo prysm_validator_wallet_password_file
# shellcheck disable=SC2043  # single-iteration loop
for _command in jq; do
	check_command_exists_on_path _command
done
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_green}${bold}" <<'EOF'
                    $$\   $$\     
                    \__|  $$ |    
 $$$$$$\  $$\   $$\ $$\ $$$$$$\   
$$  __$$\ \$$\ $$  |$$ |\_$$  _|  
$$$$$$$$ | \$$$$  / $$ |  $$ |    
$$   ____| $$  $$<  $$ |  $$ |$$\ 
\$$$$$$$\ $$  /\$$\ $$ |  \$$$$  |
 \_______|\__/  \__|\__|   \____/ 
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<'EOF'
Performs a voluntary exit of one or more validators.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
temp_validator_statuses_json="$(mktemp)"
pushd "$temp_dir" >/dev/null

function on_exit() {
	log info "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
	rm -f --interactive=never "$temp_validator_statuses_json" >/dev/null
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

# display active validators
"$this_dir/get-validator-statuses.sh" "$temp_validator_statuses_json"
active_validators="$(jq -C "$filter_active" "$temp_validator_statuses_json")"
if [[ -z $active_validators ]]; then
	log error "No active validators found:"
	jq -C "$filter_all" "$temp_validator_statuses_json"
	exit 1
fi
log info "Active validators:"
echo "$active_validators" >&2

# ask for comma-separated list of the public hex keys of the validators to exit
echo -e "\nEnter a comma-separated list of validator public keys (e.g., ${theme_example}0xABC123,0xDEF456${color_reset}) or ${theme_example}all${color_reset}."
declare chosen_pubkeys_csv
read_default "Validators to exit" "all" chosen_pubkeys_csv
if [[ $chosen_pubkeys_csv == "all" ]]; then
	prysm_param_validators="--exit-all"
elif [[ $chosen_pubkeys_csv =~ $regex_eth_validator_pubkey_csv ]]; then
	prysm_param_validators="--public-keys $chosen_pubkeys_csv"
else
	log error 'expected "all" or a comma-separated list of hexadecimal numbers'
	exit 1
fi
stderr

# need to invoke prysmctl as validator user, in a directory where both
# current user and validator user have read/write/execute permissions
sudo chown -R "${USER}:${prysm_validator_user}" "$temp_dir"
sudo chmod -R 770 "$temp_dir"

cat <<EOF
Ready to invoke prysmctl the following way:${theme_command}
sudo -u "$prysm_validator_user" "$prysmctl_bin" validator exit \\
	--wallet-dir "$prysm_validator_wallet_dir" \\
	--wallet-password-file "$prysm_validator_wallet_password_file" \\
	--accept-terms-of-use \\
	--force-exit \\
	--${ethereum_network} \\
	$prysm_param_validators
${color_reset}
EOF

continue_or_exit

sudo -u "$prysm_validator_user" "$prysmctl_bin" validator exit \
	--wallet-dir "$prysm_validator_wallet_dir" \
	--wallet-password-file "$prysm_validator_wallet_password_file" \
	--accept-terms-of-use \
	--force-exit \
	--${ethereum_network} \
	"$prysm_param_validators"

# -------------------------- POSTCONDITIONS -----------------------------------
