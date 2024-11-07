#!/bin/bash

# generate-keys.sh
#
# Generates validator keys, using an existing mnemonic seed or a new one.
#
# Meant to be run on the air-gapped PC.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
source "$this_dir/_staking-deposit-cli.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage:
		  $(basename ${BASH_SOURCE[0]}) [-h|--help] command

		Commands:
		  n, new-mnemonic
		  e, existing-mnemonic
	EOF
}

_mode_new=false
_mode_existing=false

# since we want to parse all arguments, not just '-' and '--' options,
# we omit `getopt` and loop over all arguments:
while (($#)); do
	case $1 in
	n | new-mnemonic=*)
		# _mode_new="${1#*=}"
		# shift 2
		_mode_new=true
		shift 1
		;;
	e | existing-mnemonic=*)
		# _mode_existing="${1#*=}"
		# shift 2
		_mode_existing=true
		shift 1
		;;
	--help | -h)
		show_usage
		exit 0
		;;
	*)
		printerr "unknown argument: $1"
		exit 1
		;;
	esac
done

if [[ $_mode_new == false && $_mode_existing == false ]]; then
	printerr "command missing"
	exit 1
elif [[ $_mode_new == true && $_mode_existing == true ]]; then
	printerr "multiple commands"
	exit 1
fi

# -------------------------- PRECONDITIONS ------------------------------------

reset_checks
check_is_valid_ethereum_network ethereum_network
print_failed_checks --error

staking_deposit_cli__preconditions

validator_keys_parent_dir="$this_dir"
validator_keys_dir="$validator_keys_parent_dir/validator_keys"

# -------------------------- BANNER -------------------------------------------

echo -en "${color_blue}${bold}"
cat <<'EOF'
░█▀▀░█▀▀░█▀█░█▀▀░█▀▄░█▀█░▀█▀░█▀▀░░░░░█░█░█▀▀░█░█░█▀▀
░█░█░█▀▀░█░█░█▀▀░█▀▄░█▀█░░█░░█▀▀░▄▄▄░█▀▄░█▀▀░░█░░▀▀█
░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░░░░░▀░▀░▀▀▀░░▀░░▀▀▀
EOF
echo -en "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

preamble="[${theme_value}New Mnemonic${color_reset}] Generates a new mnemonic and creates validator keys with it on the air-gapped PC."
if [[ $_mode_existing == true ]]; then
	preamble="[${theme_value}Existing Mnemonic${color_reset}] Uses an existing mnemonic and creates validator keys with it on the air-gapped PC."
fi

cat <<EOF
$preamble
See: https://github.com/ethereum/staking-deposit-cli?tab=readme-ov-file#step-2-create-keys-and-deposit_data-json
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

staking_deposit_cli__reconnaissance

# prompt for mnemonic
log_pause "mnemonic entry"
read_no_default "Please enter your mnemonic separated by spaces (\" \"). \
Note: you only need to enter the first 4 letters of each word if you'd prefer" mnemonic
log_resume "mnemonic entry complete"

reset_checks
check_is_valid_validator_mnemonic mnemonic
print_failed_checks --error
printf '\n'

# prompt for num validators to generate
read_default "Number of validator keys to generate" 1 num_validators

reset_checks
check_is_positive_integer num_validators
print_failed_checks --error
printf '\n'

# prompt for validator start index
if [[ $_mode_existing == true ]]; then
	read_default "Validator start index (0-based)" 0 validator_start_index

	reset_checks
	check_is_valid_eip2334_index validator_start_index
	print_failed_checks --error
	printf '\n'
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

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo

# initialize dependencies
staking_deposit_cli__unpack_tarball

if [[ $_mode_new == true ]]; then
	# confirmation message
	cat <<-EOF
		Ready to run the following command:${color_lightgray}
		$deposit_cli_bin --language=English new-mnemonic \\
			--num_validators=$num_validators \\
			--mnemonic_language=English \\
			--chain="$ethereum_network" \\
			--folder="$validator_keys_parent_dir"
		${color_reset}
	EOF
	continue_or_exit 1

	# generate the key(s)
	$deposit_cli_bin --language=English new-mnemonic \
		--num_validators=$num_validators \
		--mnemonic_language=English \
		--chain="$ethereum_network" \
		--folder="$validator_keys_parent_dir"
else
	# confirmation message
	cat <<-EOF
		Ready to run the following command:${color_lightgray}
		$deposit_cli_bin --language=English existing-mnemonic \\
			--mnemonic=<hidden> \\
			--validator_start_index=$validator_start_index \\
			--num_validators=$num_validators \\
			--chain="$ethereum_network" \\
			--folder="$validator_keys_parent_dir"
		${color_reset}
	EOF
	continue_or_exit 1

	# generate the key(s)
	$deposit_cli_bin --language=English existing-mnemonic \
		--mnemonic="$mnemonic" \
		--validator_start_index=$validator_start_index \
		--num_validators=$num_validators \
		--chain="$ethereum_network" \
		--folder="$validator_keys_parent_dir"
fi

# -------------------------- POSTCONDITIONS -----------------------------------

cat <<EOF
You are now ready to import your validator keys to the node server.
EOF
