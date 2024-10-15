#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

echo -n "${color_blue}${bold}"
cat <<EOF
██████╗ ██╗   ██╗███╗   ██╗                                                
██╔══██╗██║   ██║████╗  ██║                                                
██████╔╝██║   ██║██╔██╗ ██║█████╗                                          
██╔══██╗██║   ██║██║╚██╗██║╚════╝                                          
██║  ██║╚██████╔╝██║ ╚████║                                                
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝                                                
                                                                           
██████╗ ███████╗██████╗  ██████╗ ███████╗██╗████████╗    ██████╗██╗     ██╗
██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔════╝██║╚══██╔══╝   ██╔════╝██║     ██║
██║  ██║█████╗  ██████╔╝██║   ██║███████╗██║   ██║█████╗██║     ██║     ██║
██║  ██║██╔══╝  ██╔═══╝ ██║   ██║╚════██║██║   ██║╚════╝██║     ██║     ██║
██████╔╝███████╗██║     ╚██████╔╝███████║██║   ██║      ╚██████╗███████╗██║
╚═════╝ ╚══════╝╚═╝      ╚═════╝ ╚══════╝╚═╝   ╚═╝       ╚═════╝╚══════╝╚═╝
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Runs the Ethereum Staking Deposit CLI on the air-gapped PC.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_offline
assert_not_on_node_server
assert_sudo

check_is_defined ethereum_staking_deposit_cli_version
check_is_defined ethereum_staking_deposit_cli_sha256_checksum
check_is_defined ethereum_staking_deposit_cli_url

deposit_cli_basename="$(basename "$ethereum_staking_deposit_cli_url")"
deposit_cli_basename_sha256="${deposit_cli_basename}.sha256"
deposit_cli="$this_dir/$deposit_cli_basename"
deposit_cli_sha256="$this_dir/$deposit_cli_basename_sha256"

check_file_exists --sudo deposit_cli
check_file_exists --sudo deposit_cli_sha256

print_failed_checks --error || exit 1

validator_keys_parent_dir="$this_dir"
validator_keys_dir="$validator_keys_parent_dir/validator_keys"

# if validator_keys directory already exists, confirm overwrite
reset_checks
check_directory_does_not_exist --sudo validator_keys_dir
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
	printf '\n'
fi

# -------------------------- RECONNAISSANCE -----------------------------------

printf '%s' \
	"Using an online PC, navigate to " \
	"${color_blue}https://github.com/ethereum/staking-deposit-cli/releases/tag/${ethereum_staking_deposit_cli_version}${color_reset} " \
	"and verify the ${color_lightgray}SHA256 Checksum${color_reset} of ${theme_filename}$deposit_cli_basename${color_reset}"
printf '\n'
if ! yes_or_no --default-no "Does it match this? ${theme_value}$ethereum_staking_deposit_cli_sha256_checksum${color_reset}"; then
	printerr "unexpected checksum; ensure that ${color_lightgray}ethereum_staking_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
	exit 1
fi
printf '\n'

read_default "Number of validator keys to generate" 1 num_validators
if [[ ! $num_validators =~ ^[[:digit:]]+$ || ! $num_validators -gt 0 ]]; then
	printerr "must choose a positive integer"
	exit 1
fi
printf '\n'

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo

# # change to the dist directory and chown it
# cd "$this_dir"
# copy to the temp dir and chown it all
cp -f "$deposit_cli" ./
cp -f "$deposit_cli_sha256" ./
sudo chown -R "$USER:$USER" ./

# checksum using the included .sha256 file
printinfo "Verifying SHA256 checksum..."
sha256sum -c "$deposit_cli_sha256" # trapped
printf '\n'

# unpack tarball
printinfo "Unpacking tarball..."
tar xvzf "$deposit_cli_basename"
printf '\n'

deposit_cli_dir="${deposit_cli_basename%%.*}"
deposit_cli_bin="$deposit_cli_dir/deposit"

# assert that all is well so far
reset_checks
check_directory_exists --sudo deposit_cli_dir
check_executable_exists --sudo deposit_cli_bin
print_failed_checks --error # trapped

# confirmation message
cat <<EOF
Ready to run the following command:${color_lightgray}
$deposit_cli_bin --language=English new-mnemonic \\
	--num_validators=$num_validators \\
	--mnemonic_language=English \\
	--chain="$ethereum_network" \\
	--folder="$validator_keys_parent_dir"
${color_reset}
EOF
continue_or_exit 1

# remove any existing keystore
rm -rfv "$validator_keys_dir" &>/dev/null

# generate the key(s)
$deposit_cli_bin --language=English new-mnemonic \
	--num_validators=$num_validators \
	--mnemonic_language=English \
	--chain="$ethereum_network" \
	--folder="$validator_keys_parent_dir"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_directory_exists --sudo validator_keys_dir
print_failed_checks --error

cat <<EOF
Now you are ready to import your validator keys to the node server.
EOF
