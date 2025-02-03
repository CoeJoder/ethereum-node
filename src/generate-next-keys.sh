#!/bin/bash

# generate-next-keys.sh
#
# Generates validator keys using an existing mnemonic seed and the exported
# validator statuses, starting at `index + 1` of the existing validators.
#
# Meant to be run on the air-gapped PC.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
source "$this_dir/_staking-deposit-cli.sh"
source "$this_dir/_portable_jq.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename ${BASH_SOURCE[0]}) [options]
		  --mnemonic value   Mnemonic used to generate the validator keys. Omit to be prompted for it instead
		  --help, -h         Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,mnemonic:' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

mnemonic=''

while true; do
	case "$1" in
	-h | --help)
		show_usage
		exit 0
		;;
	--mnemonic)
		mnemonic="$2"
		shift 2
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown argument: $1"
		exit 1
		;;
	esac
done

# -------------------------- PRECONDITIONS ------------------------------------

assert_offline
assert_sudo

# validate opts
reset_checks
[[ -n $mnemonic ]] && check_is_valid_validator_mnemonic mnemonic
print_failed_checks --error

staking_deposit_cli__preconditions
portable_jq__preconditions

usb_bls_to_execution_changes_parent_dir="$(dirname "$usb_bls_to_execution_changes_dir")"

reset_checks
check_is_valid_ethereum_network ethereum_network
check_is_defined usb_bls_to_execution_changes_dir
check_directory_exists --sudo usb_bls_to_execution_changes_parent_dir
check_is_valid_ethereum_address withdrawal
check_file_exists --sudo validator_statuses_json
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_green}${bold}"
cat <<'EOF'
░█▀▀░█▀▀░█▀█░█▀▀░█▀▄░█▀█░▀█▀░█▀▀░░░░
░█░█░█▀▀░█░█░█▀▀░█▀▄░█▀█░░█░░█▀▀░▄▄▄
░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░░░░
░█▀█░█▀▀░█░█░▀█▀░░░░░█░█░█▀▀░█░█░█▀▀
░█░█░█▀▀░▄▀▄░░█░░▄▄▄░█▀▄░█▀▀░░█░░▀▀█
░▀░▀░▀▀▀░▀░▀░░▀░░░░░░▀░▀░▀▀▀░░▀░░▀▀▀
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Generates validator keys using an existing mnemonic seed and the exported validator statuses, starting at ${theme_command}index + 1${color_reset} of the existing validators.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

staking_deposit_cli__reconnaissance

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

# -------------------------- EXECUTION ----------------------------------------

temp_files_to_delete=()
temp_dir=$(mktemp -d)

pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
	for temp_file in "${temp_files_to_delete[@]}"; do
		rm -f --interactive=never "$temp_file" >/dev/null
	done
	print_ok
}

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

# initialize dependencies
staking_deposit_cli__unpack_tarball

# search for all imported validators
all_validators="$(jq -C "$filter_all" "$validator_statuses_json")"
if [[ -z $all_validators ]]; then
	printerr "No validators found:"
	jq -C "$filter_all" "$validator_statuses_json"
	exit 1
fi
printinfo "All validators:"
echo "$all_validators" >&2

# collect the pubkeys
readarray -t pubkeys < <(jq -r "$filter_all_pubkeys" "$validator_statuses_json")
pubkeys_csv="$(join_arr ',' "${pubkeys[@]}")"

function find_failed_exit() {
	printerr "Failed to find EIP-2334 start index.  Try running the find-script yourself, adjusting params as needed:"
	echo -en "$theme_command" >&2
	cat >&2 <<-EOF
		./find-validator-key-indices.sh \\
			--validator_pubkeys="$pubkeys_csv"
	EOF
	echo -e "$color_reset" >&2
	exit 1
}

printinfo "Need to find the highest EIP-2334 key index of the existing validators..."
find_validator_key_indices_outfile=$(mktemp)
temp_files_to_delete+=("$find_validator_key_indices_outfile")
if ! "$this_dir/find-validator-key-indices.sh" \
	--no_logging \
	--no_banner \
	--mnemonic="$mnemonic" \
	--validator_pubkeys="$pubkeys_csv" \
	--deposit_cli="$deposit_cli_bin" \
	--outfile="$find_validator_key_indices_outfile"; then
	find_failed_exit
fi
# read the sorted lines, which should be of the format: <index> <pubkey>
# and populate the final arrays
final_pubkeys=()
final_beacon_indices=()
final_bls=()
highest_validator_index=''
highest_validator_pubkey=''
while read -r index pubkey; do
	if [[ -n $index && -n $pubkey ]]; then
		highest_validator_index="$index"
		highest_validator_pubkey="$pubkey"
	fi
done <"$find_validator_key_indices_outfile"
if [[ -z $highest_validator_index ]]; then
	find_failed_exit
fi
printf '\n'

printinfo "Highest index validator found:\n\tindex: ${theme_value}${highest_validator_index}${color_reset}\n\tpubkey: ${theme_value}${highest_validator_pubkey}${color_reset}"
next_validator_index=$((highest_validator_index + 1))
printinfo "Next index: ${theme_value}${next_validator_index}${color_reset}"
printf '\n'

cat <<EOF
Ready to run the following command:${theme_command}
"$this_dir/generate-keys.sh" \\
	--mnemonic=<hidden> \\
	--validator_start_index="$next_validator_index" \\
	--deposit_cli="$deposit_cli_bin" \\
	--no_logging \\
	--no_banner \\
	existing-mnemonic
${color_reset}
EOF
continue_or_exit

# generate the signed message
"$this_dir/generate-keys.sh" \
	--mnemonic="$mnemonic" \
	--validator_start_index="$next_validator_index" \
	--deposit_cli="$deposit_cli_bin" \
	--no_logging \
	--no_banner \
	existing-mnemonic

# -------------------------- POSTCONDITIONS -----------------------------------
