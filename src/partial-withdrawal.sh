#!/bin/bash

# partial-withdrawal.sh
#
# Uses your mnemonic seed and exported validator status to generate a
# `bls-to-execution-change` signed message, which will trigger partial-
# withdrawals after submission to a beacon node.
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

# validate opts
reset_checks
[[ -n $mnemonic ]] && check_is_valid_validator_mnemonic mnemonic
print_failed_checks --error

staking_deposit_cli__preconditions
portable_jq__preconditions

bls_to_execution_changes_parent_dir="$this_dir"
bls_to_execution_changes_dir="$bls_to_execution_changes_parent_dir/bls_to_execution_changes"

reset_checks
check_is_valid_ethereum_address withdrawal
check_file_exists --sudo validator_statuses_json
print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_green}${bold}
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
Uses your mnemonic seed and exported validator status to generate a ${theme_value}bls-to-execution-change${color_reset} message on the air-gapped PC.
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

filter_all='.[] | {
	index,
	status,
	balance,
	pubkey: .validator.pubkey,
	bls_withdrawal_credentials: .validator.withdrawal_credentials
}'
filter_active='.[] | select(.status == "active_ongoing") | {
	index,
	status,
	balance,
	pubkey: .validator.pubkey,
	bls_withdrawal_credentials: .validator.withdrawal_credentials
}'
filter_indices='.[] | select(.status == "active_ongoing") |
	.index'
filter_pubkeys='.[] | select(.status == "active_ongoing") |
	.validator.pubkey'
filter_bls_withdrawal_credentials='.[] | select(.status == "active_ongoing") |
	.validator.withdrawal_credentials'

# -------------------------- EXECUTION ----------------------------------------

temp_files_to_delete=()
temp_dir=$(mktemp -d)

pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
	for temp_file in "${temp_files_to_delete[@]}"; do
		[[ -f $temp_file ]] && rm -f --interactive=never "$temp_file" >/dev/null
	done
	print_ok
}

trap 'on_err_noretry' ERR
trap 'on_exit' EXIT

# initialize dependencies
staking_deposit_cli__unpack_tarball

# search for active validators
active_validators="$(jq -C "$filter_active" "$validator_statuses_json")"
if [[ -z $active_validators ]]; then
	printerr "No active validators found:"
	jq -C "$filter_all" "$validator_statuses_json"
	exit 1
fi
printinfo "Active validators:"
echo "$active_validators" >&2

# create parallel arrays to hold validator info
readarray -t indices < <(jq -r "$filter_indices" "$validator_statuses_json")
readarray -t pubkeys < <(jq -r "$filter_pubkeys" "$validator_statuses_json")
readarray -t bls_withdrawal_credentials < <(jq -r "$filter_bls_withdrawal_credentials" "$validator_statuses_json")

# map the validators by pubkey
declare -A pubkey_map
for i in "${!pubkeys[@]}"; do
	pubkey="${pubkeys[i]}"
	pubkey_map["$pubkey"]="${indices[i]} ${bls_withdrawal_credentials[i]}"
done

# prompt for validators to withdraw
echo -e "\nEnter a comma-separated list of validator indices (e.g. ${theme_example}1833689,1833692${color_reset}) or ${theme_example}all${color_reset}."
read_default "Validators to withdraw" "all" chosen_indices_csv
if [[ $chosen_indices_csv == "all" ]]; then
	chosen_indices=("${indices[@]}")
	chosen_indices_csv="$(join_arr ',' "${chosen_indices[@]}")"
elif [[ $chosen_indices_csv =~ $regex_eth_validator_indices_csv ]]; then
	readarray -td ',' chosen_indices < <(printf '%s' "$chosen_indices_csv")
else
	printerr 'expected "all" or a comma-separated list of validator indices'
	exit 1
fi
printf '\n'

# determine the parallel array indexes based on the chosen indices
arr_indexes=()
for i in "${!chosen_indices[@]}"; do
	arr_index=''
	for j in "${!indices[@]}"; do
		if [[ ${chosen_indices[i]} == ${indices[j]} ]]; then
			arr_index="$j"
			break
		fi
	done
	if [[ -z $arr_index ]]; then
		printerr "invalid validator index: ${chosen_indices[i]}"
		exit 1
	fi
	arr_indexes+=("$arr_index")
	arr_index=''
done

# collect the pubkeys of the chosen validators
chosen_pubkeys=()
for i in "${arr_indexes[@]}"; do
	if [[ -z "${pubkeys[i]}" ]]; then
		printerr "expected pubkey at index $i"
		exit 1
	fi
	chosen_pubkeys+=("${pubkeys[i]}")
done
chosen_pubkeys_csv="$(join_arr ',' "${chosen_pubkeys[@]}")"

function find_failed_exit() {
	printerr "Failed to find EIP-2334 start index.  Try running the find-script yourself, adjusting params as needed:"
	echo -en "$theme_command"
	cat <<-EOF
		./find-validator-key-indices.sh \\
			--validator_pubkeys="$chosen_pubkeys_csv"
	EOF
	echo -e "$color_reset"
	exit 1
}

# find the lowest EIP-2334 key index of the chosen validators
find_validator_key_indices_outfile=$(mktemp)
temp_files_to_delete+=("$find_validator_key_indices_outfile")
if ! "$this_dir/find-validator-key-indices.sh" \
	--no_logging \
	--no_banner \
	--mnemonic="$mnemonic" \
	--validator_pubkeys="$chosen_pubkeys_csv" \
	--deposit_cli="$deposit_cli_bin" \
	--outfile="$find_validator_key_indices_outfile"; then
	find_failed_exit
fi
# read the sorted lines, which should be of the format: <index> <pubkey>
# and populate the final arrays
final_pubkeys=()
final_beacon_indices=()
final_bls=()
validator_start_index=''
while read -r index pubkey; do
	if [[ -n $index && -n $pubkey ]]; then
		# NOTE: pubkey_map[i] = <beacon-index[i]> <bls-withdrawal-credentials[i]>
		pubkey_map_entry="${pubkey_map[$pubkey]}"
		read beacon_index bls_withdrawal_credential <<<"$pubkey_map_entry"
		final_pubkeys+=("$pubkey")
		final_beacon_indices+=("$beacon_index")
		final_bls+=("$bls_withdrawal_credential")
		if [[ -z $validator_start_index ]]; then
			validator_start_index="$index"
		fi
	fi
done <"$find_validator_key_indices_outfile"
if [[ -z $validator_start_index ]]; then
	find_failed_exit
fi
printf '\n'

# serialize the final arrays
final_pubkeys_csv="$(join_arr ',' "${final_pubkeys[@]}")"
final_beacon_indices_csv="$(join_arr ',' "${final_beacon_indices[@]}")"
final_bls_csv="$(join_arr ',' "${final_bls[@]}")"

# display results before call
printinfo "Validator pubkeys:\n${final_pubkeys_csv}"
printinfo "Beacon indices:\n${final_beacon_indices_csv}"
printinfo "BLS Withdrawal Credentials:\n${final_bls_csv}"
printinfo "EIP-2334 validator start index:\n${validator_start_index}"
printf '\n'

# obnoxious confirmation message
printwarn 'IMPORTANT: ensure that 'execution_address' below is set to your withdrawal wallet address!!!'
printwarn 'IMPORTANT: ensure that 'execution_address' below is set to your withdrawal wallet address!!!'
printwarn 'IMPORTANT: ensure that 'execution_address' below is set to your withdrawal wallet address!!!'

cat <<EOF
Ready to run the following command:${theme_command}
$deposit_cli_bin --language=English --non_interactive generate-bls-to-execution-change \\
	--mnemonic=<hidden> \\
	--execution_address="$withdrawal" \\
	--bls_to_execution_changes_folder="$bls_to_execution_changes_parent_dir" \\
	--bls_withdrawal_credentials_list="$final_bls_csv" \\
	--validator_start_index=$validator_start_index \\
	--validator_indices="$final_beacon_indices_csv" \\
	--chain="$ethereum_network"
${color_reset}
EOF
continue_or_exit 1

# generate the signed message
$deposit_cli_bin --language=English --non_interactive generate-bls-to-execution-change \
	--mnemonic="$mnemonic" \
	--execution_address="$withdrawal" \
	--bls_to_execution_changes_folder="$bls_to_execution_changes_parent_dir" \
	--bls_withdrawal_credentials_list="$final_bls_csv" \
	--validator_start_index=$validator_start_index \
	--validator_indices="$final_beacon_indices_csv" \
	--chain="$ethereum_network"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_directory_exists --sudo bls_to_execution_changes_dir
print_failed_checks --error
