#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
source "$this_dir/_portable_jq.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

portable_jq__preconditions

reset_checks
check_is_valid_ethereum_network ethereum_network
check_user_exists prysmctl_user
check_group_exists prysmctl_group
check_executable_exists --sudo prysmctl_bin
check_directory_exists --sudo prysm_validator_wallet_dir
check_file_exists --sudo prysm_validator_wallet_password_file
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_green}${bold}"
cat <<'EOF'
                    $$\   $$\     
                    \__|  $$ |    
 $$$$$$\  $$\   $$\ $$\ $$$$$$\   
$$  __$$\ \$$\ $$  |$$ |\_$$  _|  
$$$$$$$$ | \$$$$  / $$ |  $$ |    
$$   ____| $$  $$<  $$ |  $$ |$$\ 
\$$$$$$$\ $$  /\$$\ $$ |  \$$$$  |
 \_______|\__/  \__|\__|   \____/ 
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<'EOF'
Performs a voluntary exit of one or more validators.
EOF

# -------------------------- RECONNAISSANCE -----------------------------------

portable_jq__reconnaissaince

# variables set in jq recon
reset_checks
check_is_defined filter_active
print_failed_checks --error

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
temp_validator_statuses_json="$(mktemp)"
pushd "$temp_dir" >/dev/null

function on_exit() {
	echo -en "\nCleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
	rm -f --interactive=never "$temp_validator_statuses_json" >/dev/null
	echo -e "${color_green}OK${color_reset}"
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

# display active validators
"$this_dir/get-validator-statuses.sh" "$temp_validator_statuses_json"
active_validators="$(jq -C "$filter_active" "$temp_validator_statuses_json")"
if [[ -z $active_validators ]]; then
	printerr "No active validators found:"
	jq -C "$filter_all" "$temp_validator_statuses_json"
	exit 1
fi
printinfo "Active validators:"
echo "$active_validators" >&2

# ask for comma-separated list of the public hex keys of the validators to exit
echo -e "\nEnter a comma-separated list of validator public keys (e.g. ${theme_example}0xABC123,0xDEF456${color_reset}) or ${theme_example}all${color_reset}."
read_default "Validators to exit" "all" chosen_pubkeys_csv
if [[ $chosen_pubkeys_csv == "all" ]]; then
	prysm_param_validators="--exit-all"
elif [[ $chosen_pubkeys_csv =~ $regex_eth_addr_csv ]]; then
	prysm_param_validators="--public-keys $chosen_pubkeys_csv"
else
	printerr 'expected "all" or a comma-separated list of hexadecimal numbers'
	exit 1
fi
printf '\n'

# TODO keep this section as reference until script tests OK

# # need to invoke prysmctl as `prysmvalidator`, in a directory where both
# # the current user and `prysmvalidator` have read/write/execute permissions
# install_dir="/var/lib/prysm/prysmctl"
# assert_sudo
# sudo mkdir -p "$install_dir"
# sudo mv -f "$prysmctl_bin" "$install_dir"
# sudo chown -R "${USER}:${prysm_validator_user}" "$install_dir"
# sudo chmod -R 770 "$install_dir"
# popd >/dev/null
# pushd "$install_dir" >/dev/null

cat <<EOF
Ready to invoke prysmctl the following way:${theme_command}
sudo -u "$prysmctl_user" "$prysmctl_bin" validator exit \\
	--wallet-dir "$prysm_validator_wallet_dir" \\
	--wallet-password-file "$prysm_validator_wallet_password_file" \\
	--accept-terms-of-use \\
	--force-exit \\
	--${ethereum_network} \\
	$prysm_param_validators
${color_reset}
EOF

continue_or_exit

# TODO verify this works; original was invoked as `prysmvalidator` user
sudo -u "$prysmctl_user" "$prysmctl_bin" validator exit \
	--wallet-dir "$prysm_validator_wallet_dir" \
	--wallet-password-file "$prysm_validator_wallet_password_file" \
	--accept-terms-of-use \
	--force-exit \
	--${ethereum_network} \
	$prysm_param_validators

# -------------------------- POSTCONDITIONS -----------------------------------
