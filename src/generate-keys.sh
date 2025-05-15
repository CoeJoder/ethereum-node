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
source "$this_dir/_portable_jq.sh"
set_env
# whether to enable logging depends on the opts

function show_usage() {
	cat >&2 <<-EOF
		Usage:
		  $(basename ${BASH_SOURCE[0]}) [options] command
		Options:
		  --keystore_password value       Keystore password.  Used to decrypt keystores when during validator import
		  --num_validators value          Number of validator keys to generate
		  --validator_start_index value   [existing-mnemonic] Validator start index, 0-based.  Omit to be prompted for it instead
		  --mnemonic value                [existing-mnemonic] Mnemonic used to generate the validator keys.  Omit to be prompted for it instead
		  --deposit_cli value             Path to the extracted deposit-cli binary (optional)
		  --no_logging                    Prevent logging terminal output to logfile
		  --no_banner                     Prevent banner display
		  --help, -h                      Show this message
		Commands:
		  n, new-mnemonic                 Generate a new mnemonic and from it, the validator keys
		  e, existing-mnemonic            Use an existing mnemonic to generate the validator keys
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='keystore_password:,num_validators:,validator_start_index:,mnemonic:,deposit_cli:,no_logging,no_banner,help' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
(($? != 0)) && exit 1
eval set -- "$_parsed_args"
unset _parsed_args

keystore_password=''
num_validators=''
validator_start_index=''
mnemonic=''
deposit_cli_bin=''
no_logging=false
no_banner=false
mode_new=false
mode_existing=false

while true; do
	case "$1" in
	--keystore_password)
		keystore_password="$2"
		shift 2
		;;
	--num_validators)
		num_validators="$2"
		shift 2
		;;
	--validator_start_index)
		validator_start_index="$2"
		shift 2
		;;
	--mnemonic)
		mnemonic="$2"
		shift 2
		;;
	--deposit_cli)
		deposit_cli_bin="$2"
		shift 2
		;;
	--no_logging)
		no_logging=true
		shift
		;;
	--no_banner)
		no_banner=true
		shift
		;;
	-h | --help)
		show_usage
		exit 0
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown option: $1"
		exit 1
		;;
	esac
done

if [[ $no_logging == false ]]; then
	log_start
	log_timestamp
fi

# parse command
while (($#)); do
	case $1 in
	n | new-mnemonic)
		mode_new=true
		shift 1
		;;
	e | existing-mnemonic)
		mode_existing=true
		shift 1
		;;
	--help | -h)
		show_usage
		exit 0
		;;
	*)
		printerr "unknown command: $1"
		exit 1
		;;
	esac
done

if [[ $mode_new == false && $mode_existing == false ]]; then
	printerr "command missing"
	exit 1
elif [[ $mode_new == true && $mode_existing == true ]]; then
	printerr "multiple commands"
	exit 1
fi

# -------------------------- PRECONDITIONS ------------------------------------

assert_offline
assert_sudo

# validate opts and params
reset_checks
[[ -n $keystore_password ]] && check_is_valid_keystore_password keystore_password
[[ -n $num_validators ]] && check_is_positive_integer num_validators
[[ -n $mnemonic ]] && check_is_valid_validator_mnemonic mnemonic
[[ -n $validator_start_index ]] && check_is_valid_eip2334_index validator_start_index
[[ -n $deposit_cli_bin ]] && check_executable_exists deposit_cli_bin
check_is_valid_ethereum_network ethereum_network
print_failed_checks --error

[[ -z $deposit_cli_bin ]] && staking_deposit_cli__preconditions
portable_jq__preconditions

validator_keys_parent_dir="$this_dir"
validator_keys_dir="$validator_keys_parent_dir/validator_keys"

# -------------------------- BANNER -------------------------------------------

if [[ $no_banner == false ]]; then
	echo "${color_blue}${bold}"
	cat <<-'EOF'
		░█▀▀░█▀▀░█▀█░█▀▀░█▀▄░█▀█░▀█▀░█▀▀░░░░░█░█░█▀▀░█░█░█▀▀
		░█░█░█▀▀░█░█░█▀▀░█▀▄░█▀█░░█░░█▀▀░▄▄▄░█▀▄░█▀▀░░█░░▀▀█
		░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░░░░░▀░▀░▀▀▀░░▀░░▀▀▀
	EOF
	echo -n "${color_reset}"

	# -------------------------- PREAMBLE -----------------------------------------

	preamble="[${theme_value}New Mnemonic${color_reset}] Generates a new mnemonic and validator keys on the air-gapped PC."
	if [[ $mode_existing == true ]]; then
		preamble="[${theme_value}Existing Mnemonic${color_reset}] Uses an existing mnemonic to create validator keys on the air-gapped PC."
	fi

	cat <<-EOF
		$preamble
		See: https://deposit-cli.ethstaker.cc/quick_setup.html#step-3-usage
	EOF
	press_any_key_to_continue
fi

# -------------------------- RECONNAISSANCE -----------------------------------

[[ -z $deposit_cli_bin ]] && staking_deposit_cli__reconnaissance

# prompt to delete destination directory if present
assert_sudo
if sudo test -d "$validator_keys_dir"; then
	printwarn "Destination already exists: $validator_keys_dir"
	continue_or_exit 1 "Overwrite?"
	sudo rm -rfv --interactive=never "$validator_keys_dir"
fi

# prompt for keystore password if not passed as script arg
if [[ -z $keystore_password ]]; then
	log_pause "keystore password entry"
	echo "Create a password that secures your validator keystore(s). You will need to re-enter this to decrypt them when you setup your Ethereum validators"
	enter_password_and_confirm "Choose a keystore password" \
		"$errmsg_keystore_password" \
		check_is_valid_keystore_password \
		keystore_password
	log_resume "keystore password entry complete"

	reset_checks
	check_is_valid_keystore_password keystore_password
	print_failed_checks --error
	printf '\n'
fi

# prompt for num validators to generate if not passed as script arg
if [[ -z $num_validators ]]; then
	read_default "Number of validator keys to generate" 1 num_validators

	reset_checks
	check_is_positive_integer num_validators
	print_failed_checks --error
	printf '\n'
fi

if [[ $mode_existing == true ]]; then
	# prompt for validator start index if not passed as script arg
	if [[ -z $validator_start_index ]]; then
		read_default "Validator start index (0-based)" 0 validator_start_index

		reset_checks
		check_is_valid_eip2334_index validator_start_index
		print_failed_checks --error
		printf '\n'
	fi

	# prompt for mnemonic if not passed as script arg
	if [[ -z $mnemonic ]]; then
		log_pause "mnemonic entry"
		read_no_default "Please enter your mnemonic separated by spaces (\" \"). \
		Note: you only need to enter the first 4 letters of each word if you'd prefer" mnemonic
		log_resume "mnemonic entry complete"

		reset_checks
		check_is_valid_validator_mnemonic mnemonic
		print_failed_checks --error
		printf '\n'
	fi
fi

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

assert_sudo

# initialize dependencies
[[ -z $deposit_cli_bin ]] && staking_deposit_cli__unpack_tarball

if [[ $mode_new == true ]]; then
	# confirmation message
	cat <<-EOF
		Ready to run the following command:${color_lightgray}
		"$deposit_cli_bin" --language=English --non_interactive new-mnemonic \\
			--keystore_password=<hidden> \\
			--num_validators=$num_validators \\
			--mnemonic_language=English \\
			--chain="$ethereum_network" \\
			--folder="$validator_keys_parent_dir"
		${color_reset}
	EOF
	continue_or_exit

	# if logging isn't paused, ethstaker-deposit-cli glitches when showing the mnemonic
	log_pause "new mnemonic generation"

	# generate the key(s)
	"$deposit_cli_bin" --language=English --non_interactive new-mnemonic \
		--keystore_password="$keystore_password" \
		--num_validators=$num_validators \
		--mnemonic_language=English \
		--chain="$ethereum_network" \
		--folder="$validator_keys_parent_dir"
	
	log_resume "new mnemonic generation"

else
	# confirmation message
	cat <<-EOF
		Ready to run the following command:${color_lightgray}
		"$deposit_cli_bin" --language=English --non_interactive existing-mnemonic \\
			--keystore_password=<hidden> \\
			--num_validators=$num_validators \\
			--validator_start_index=$validator_start_index \\
			--mnemonic=<hidden> \\
			--chain="$ethereum_network" \\
			--folder="$validator_keys_parent_dir"
		${color_reset}
	EOF
	continue_or_exit

	# generate the key(s)
	"$deposit_cli_bin" --language=English --non_interactive existing-mnemonic \
		--keystore_password="$keystore_password" \
		--num_validators=$num_validators \
		--validator_start_index=$validator_start_index \
		--mnemonic="$mnemonic" \
		--chain="$ethereum_network" \
		--folder="$validator_keys_parent_dir"
fi

# -------------------------- POSTCONDITIONS -----------------------------------

cat <<EOF
You are now ready to import your validator keys to the node server.
EOF
