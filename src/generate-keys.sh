#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
source "$this_dir/_staking-deposit-cli.sh"
housekeeping

function _show_usage() {
	cat >&2 <<-EOF 
	usage:
	generate-keys.sh [-h|--help] {--new-mnemonic|--existing-mnemonic}
	EOF
}

_mode_new=false
_mode_existing=false

function _parse_arg() {
	if [[ $1 == '-h' || $1 == '--help' ]]; then
		_show_usage
		exit 0
	elif [[ $1 == '--new-mnemonic' ]]; then
		_mode_new=true
	elif [[ $1 == '--existing-mnemonic' ]]; then
		_mode_existing=true
	else
		printerr "unknown argument: $1"
		_show_usage
		exit 1
	fi
}

function _validate() {
	[[ $_mode_new == true || $_mode_existing == true ]]
}

if [[ $# -gt 0 ]]; then
	_parse_arg "$1"
	shift
	if ! _validate && [[ $# -gt 0 ]]; then
		_parse_arg "$1"
		shift
	fi
fi

if ! _validate; then
	_show_usage
	exit 1
fi

# -------------------------- BANNER -------------------------------------------

echo -n "${color_blue}${bold}"
cat <<EOF
░█▀▀░█▀▀░█▀█░█▀▀░█▀▄░█▀█░▀█▀░█▀▀░░░░░█░█░█▀▀░█░█░█▀▀
░█░█░█▀▀░█░█░█▀▀░█▀▄░█▀█░░█░░█▀▀░▄▄▄░█▀▄░█▀▀░░█░░▀▀█
░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░░░░░▀░▀░▀▀▀░░▀░░▀▀▀
${color_reset}
EOF

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

# -------------------------- PRECONDITIONS ------------------------------------

staking_deposit_cli__preconditions || exit

validator_keys_parent_dir="$this_dir"
validator_keys_dir="$validator_keys_parent_dir/validator_keys"

# -------------------------- RECONNAISSANCE -----------------------------------

staking_deposit_cli__reconnaissance || exit

read_default "Number of validator keys to generate" 1 num_validators
if [[ ! $num_validators =~ ^[[:digit:]]+$ || ! $num_validators -gt 0 ]]; then
	printerr "must choose a positive integer"
	exit 1
fi
printf '\n'

if [[ $_mode_existing == true ]]; then
	read_default "Validator start index (0-based)" 0 validator_start_index
	if [[ ! $validator_start_index =~ ^[[:digit:]]+$ || ! $validator_start_index -ge 0 ]]; then
		printerr "must choose an integer ≥ 0"
		exit 1
	fi
	printf '\n'
fi

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

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo
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
		--validator_start_index=$validator_start_index \\
		--num_validators=$num_validators \\
		--chain="$ethereum_network" \\
		--folder="$validator_keys_parent_dir"
	${color_reset}
	EOF
	continue_or_exit 1

	# generate the key(s)
	$deposit_cli_bin --language=English existing-mnemonic \
		--validator_start_index=$validator_start_index \
		--num_validators=$num_validators \
		--chain="$ethereum_network" \
		--folder="$validator_keys_parent_dir"
fi

# -------------------------- POSTCONDITIONS -----------------------------------

cat <<EOF
You are now ready to import your validator keys to the node server.
EOF
