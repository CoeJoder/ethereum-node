#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_offline_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_offline_dir/../src/common.sh"
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
Runs the Etehereum Staking Deposit CLI on the offline PC.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server
assert_sudo

check_directory_exists --sudo client_pc_usb_data_drive

check_is_defined ethereum_staking_deposit_cli_version
check_is_defined ethereum_staking_deposit_cli_sha256_checksum
check_is_defined ethereum_staking_deposit_cli_url

deposit_cli_basename="$(basename "$ethereum_staking_deposit_cli_url")"
deposit_cli_basename_sha256="${deposit_cli_basename}.sha256"
deposit_cli="$client_pc_usb_data_drive/$deposit_cli_basename"
deposit_cli_sha256="$client_pc_usb_data_drive/$deposit_cli_basename_sha256"

check_file_exists --sudo deposit_cli
check_file_exists --sudo deposit_cli_sha256

print_failed_checks --error || exit 1

# -------------------------- RECONNAISSANCE -----------------------------------

printf '\n'
printf '%s' \
	"Using an online PC, navigate to " \
	"${color_blue}https://github.com/ethereum/staking-deposit-cli/releases/tag/${ethereum_staking_deposit_cli_version}${color_reset} " \
	"and verify the ${color_lightgray}SHA256 Checksum${color_reset} of ${theme_filename}$deposit_cli_basename${color_reset}"
printf '\n'
if ! yes_or_no --default-no "Does it match this? ${theme_value}$ethereum_staking_deposit_cli_sha256_checksum${color_lightgray}"; then
	printerr "unexpected checksum; ensure that ${color_lightgray}ethereum_staking_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
	exit 1
fi

read_default "Number of validator keys to generate" 1 num_validators
if [[ ! $num_validators =~ ^[123456789]+$ ]]; then
	printerr "must choose a positive integer"
	exit 1
fi

# -------------------------- EXECUTION ----------------------------------------

trap 'on_err_noretry' ERR

assert_sudo

# checksum using the included .sha256 file
sha256sum -c "$deposit_cli_sha256" # trapped

# should be here anyways; no need to pushd/popd
cd "$client_pc_usb_data_drive"

# chown the tarball, unpack it
sudo chown -v "$USER:$USER" "$deposit_cli_basename"
sudo tar xvzf "$deposit_cli_basename"
deposit_cli_dir="${deposit_cli_basename%%.*}"
deposit_cli_bin="$deposit_cli_dir/deposit"

# assert that all is well so far
reset_checks
check_directory_exists --sudo "$deposit_cli_dir"
check_executable_exists --sudo "$deposit_cli_bin"
print_failed_checks --error # trapped

# chown to current user so we can run without root perms
sudo chown -R "${USER}:${USER}" "$deposit_cli_dir"

# confirmation message
cat <<EOF
Ready to run the following command:
${color_lightgray}
$deposit_cli_bin new-mnemonic \\
	--num_validators=$num_validators \\
	--mnemonic_language=english \\
	--chain=$ethereum_network
${color_reset}
EOF
continue_or_exit 1

# generate the key(s)
$deposit_cli_bin new-mnemonic \
	--num_validators=$num_validators \
	--mnemonic_language=english \
	--chain=$ethereum_network

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
validator_keys="$deposit_cli_dir/validator_keys"
check_directory_exists --sudo validator_keys
print_failed_checks --error

cat <<EOF

Success!  Generated $num_validators validator keys.
Now you are ready to import your validator keys to the node server.
EOF
