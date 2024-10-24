#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
source "$this_dir/_staking-deposit-cli.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
"${color_green}${bold}"
░█▀█░█▀█░█▀▄░▀█▀░▀█▀░█▀█░█░░░░░░        
░█▀▀░█▀█░█▀▄░░█░░░█░░█▀█░█░░░▄▄▄        
░▀░░░▀░▀░▀░▀░░▀░░▀▀▀░▀░▀░▀▀▀░░░░        
░█░█░▀█▀░▀█▀░█░█░█▀▄░█▀▄░█▀█░█░█░█▀█░█░░
░█▄█░░█░░░█░░█▀█░█░█░█▀▄░█▀█░█▄█░█▀█░█░░
░▀░▀░▀▀▀░░▀░░▀░▀░▀▀░░▀░▀░▀░▀░▀░▀░▀░▀░▀▀▀
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Uses your validator's mnemonic to generate a ${theme_value}bls-to-execution-change${color_reset} message on the air-gapped PC.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

staking_deposit_cli__preconditions || exit

bls_to_execution_changes_parent_dir="$this_dir"
bls_to_execution_changes_dir="$bls_to_execution_changes_parent_dir/bls_to_execution_changes"

reset_checks
check_is_valid_ethereum_address withdrawal
check_file_exists validator_statuses_json
print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

staking_deposit_cli__reconnaissance || exit

reset_checks
check_file_exists validator_statuses_json
if ! print_failed_checks --warn; then
	printwarn "unable to display validator account info"
else
	# TODO do something meaningful with the json rather than just display it
	printinfo "Validator accounts found on the node server:"
	cat "$validator_statuses_json"
	printf '\n'
	printinfo "Use the above info to fill out the following fields."
fi

read_default "Validator start index (0-based)" 0 validator_start_index
if [[ ! $validator_start_index =~ ^[[:digit:]]+$ || ! $validator_start_index -ge 0 ]]; then
	printerr "must choose an integer ≥ 0"
	exit 1
fi
printf '\n'

read_no_default "Validator indices (csv list of beacon-chain validator indices)" validator_indices
printf '\n'

read_no_default "BLS Withdrawal Credentials (csv list)" bls_withdrawal_credentials_list
printf '\n'

# -------------------------- EXECUTION ----------------------------------------

set -e
temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

set -e
trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo
staking_deposit_cli__unpack_tarball

# confirmation message
cat <<EOF
Ready to run the following command:${color_lightgray}
$deposit_cli_bin --language=English generate-bls-to-execution-change \\
	--bls_to_execution_changes_folder="$bls_to_execution_changes_parent_dir" \\
	--bls_withdrawal_credentials_list="$bls_withdrawal_credentials_list" \\
	--validator_start_index=$validator_start_index \\
	--validator_indices="$validator_indices" \\
	--chain="$ethereum_network" \\
	--bls_to_execution_changes_folder="$bls_to_execution_changes_parent_dir"
${color_reset}
EOF
continue_or_exit 1

# generate the message
$deposit_cli_bin --language=English generate-bls-to-execution-change \
	--bls_to_execution_changes_folder="$bls_to_execution_changes_parent_dir" \
	--bls_withdrawal_credentials_list="$bls_withdrawal_credentials_list" \
	--validator_start_index=$validator_start_index \
	--validator_indices="$validator_indices" \
	--chain="$ethereum_network"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_directory_exists --sudo bls_to_execution_changes_dir
print_failed_checks --error

cat <<EOF
You are now ready to broadcast the generated message through a beacon node.
EOF
