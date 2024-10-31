#!/bin/bash

# find-validator-key-indices.sh
#
# Given a mnemonic seed phrase and a list of validator pubkeys, determine the
# validator key indices.
#
# Meant to be run on the air-gapped PC.
#
# see: https://eips.ethereum.org/EIPS/eip-2334#validator-keys

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
		  --mnemonic value                Mnemonic used to generate the validator keys
		  --validator_pubkeys value       Validator public keys, comma-separated
		  --validator_start_index value   Search start index, 0-based
		  --num_validators value          Number of keys to search
			--deposit_cli value             Path to the extracted deposit-cli binary (optional)
			--outfile value                 File to save results in (optional)
		  --help, -h                      Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,mnemonic:,validator_pubkeys:,validator_start_index:,num_validators:,deposit_cli:,outfile:' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

mnemonic=''
validator_pubkeys_csv=''
validator_start_index=''
num_validators=''
deposit_cli_bin=''
indices_outfile=''

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
	--validator_pubkeys)
		validator_pubkeys_csv="$2"
		shift 2
		;;
	--validator_start_index)
		validator_start_index="$2"
		shift 2
		;;
	--num_validators)
		num_validators="$2"
		shift 2
		;;
	--deposit_cli)
		deposit_cli_bin="$2"
		shift 2
		;;
	--outfile)
		indices_outfile="$2"
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

# -------------------------- BANNER -------------------------------------------

echo "${color_blue}${bold}"
cat <<'EOF'
[`.,_ |__    |. |  |-    __.,_ |. _ _  _
| |||(|  \/(|||(|(||_()|`  |||(||(_(/__\
EOF
echo -n "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Given a mnemonic seed phrase and a list of validator pubkeys, determine the validator key indices.
See: https://eips.ethereum.org/EIPS/eip-2334#validator-keys
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

if [[ -z $deposit_cli_bin ]]; then
	staking_deposit_cli__preconditions
else
	check_executable_exists deposit_cli_bin
	print_failed_checks --error
fi
portable_jq__preconditions

# -------------------------- RECONNAISSANCE -----------------------------------

function validate_mnemonic() {
	if [[ -z $1 ]]; then
		printerr "missing mnemonic"
		exit 1
	fi
	if [[ $(printf '%s' "$1" | wc -w) -ne 24 ]]; then
		printerr "expected a 24-word mnemonic"
		exit 1
	fi
}

function validate_validator_pubkeys {
	if [[ -z $1 ]]; then
		printerr "missing validator pubkeys"
		exit 1
	fi
	if [[ ! $1 =~ $regex_eth_validator_pubkey_csv && ! $1 =~ $regex_eth_validator_pubkey_csv_v2 ]]; then
		printerr "expected a comma-separated list of validator pubkeys"
		exit 1
	fi
}

function validate_validator_start_index() {
	if [[ -z $1 ]]; then
		printerr "missing validator start index"
		exit 1
	fi
	if [[ ! $1 =~ ^[[:digit:]]+$ || ! $1 -ge 0 ]]; then
		printerr "validator start index must be an integer ≥ 0"
		exit 1
	fi
}

function validate_num_validators() {
	if [[ -z $1 ]]; then
		printerr "missing number of validators to search"
	fi
	if [[ ! $1 =~ ^[[:digit:]]+$ || ! $1 -gt 0 ]]; then
		printerr "must choose a positive integer"
		exit 1
	fi
}

# prompt for mnemonic if not passed as script arg
if [[ -n $mnemonic ]]; then
	validate_mnemonic "$mnemonic"
else
	read_no_default "Please enter your mnemonic separated by spaces (\" \"). \
	Note: you only need to enter the first 4 letters of each word if you'd prefer" mnemonic
	validate_mnemonic "$mnemonic"
	printf '\n'
fi

# prompt for validator pubkeys if not passed as script arg
if [[ -n $validator_pubkeys_csv ]]; then
	validate_validator_pubkeys "$validator_pubkeys_csv"
else
	read_no_default "Please enter the validator public keys, separated by commas" validator_pubkeys_csv
	validate_validator_pubkeys "$validator_pubkeys_csv"
	printf '\n'
fi

# prompt for validator start index if not passed as script arg
if [[ -n $validator_start_index ]]; then
	validate_validator_start_index "$validator_start_index"
else
	read_default "Start search at index" 0 validator_start_index
	validate_validator_start_index "$validator_start_index"
	printf '\n'
fi

# prompt for num validators to search if not passed as a script arg
if [[ -n $num_validators ]]; then
	validate_num_validators "$num_validators"
else
	read_default "Max search range (more takes longer)" 5 num_validators
	validate_num_validators "$num_validators"
	printf '\n'
fi

[[ -z $deposit_cli_bin ]] && staking_deposit_cli__reconnaissance

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo

# initialize dependencies
[[ -z $deposit_cli_bin ]] && staking_deposit_cli__unpack_tarball

# remove any '0x' prefixes from pubkeys to match keystore format
validator_pubkeys_trimmed=()
readarray -td ',' validator_pubkeys < <(printf '%s' "$validator_pubkeys_csv")
for validator_pubkey in "${validator_pubkeys[@]}"; do
	if [[ $validator_pubkey =~ $regex_eth_validator_pubkey ]]; then
		validator_pubkeys_trimmed+=("$(printf '%s' "$validator_pubkey" | cut -c 3-)")
	else
		validator_pubkeys_trimmed+=("$validator_pubkey")
	fi
done

# generate keys in the temp dir
printinfo "Generating keys..."
validator_keys_parent_dir='.'
validator_keys_dir="$validator_keys_parent_dir/validator_keys"
$deposit_cli_bin --language=English --non_interactive existing-mnemonic \
	--mnemonic="$mnemonic" \
	--keystore_password=passworddoesntmatter \
	--validator_start_index=$validator_start_index \
	--num_validators=$num_validators \
	--chain="$ethereum_network" \
	--folder="$validator_keys_parent_dir" >/dev/null
printf '\n'

# search the generated keys for pubkey matches and extract the indices
# from the `path` property
indices_found=()
pubkeys_not_found=()
readarray -d $'\0' keystore_files < <(find "$validator_keys_dir" -maxdepth 1 -name 'keystore-m_12381_3600_*' -type f -print0)
num_pubkeys=${#validator_pubkeys_trimmed[@]}
for ((i = 0; i < num_pubkeys; i++)); do
	validator_pubkey_trimmed="${validator_pubkeys_trimmed[i]}"
	validator_pubkey="${validator_pubkeys[i]}"
	validator_index=''
	for keystore_file in "${keystore_files[@]}"; do
		key_path="$(jq --raw-output --arg pubkey "$validator_pubkey_trimmed" '. | select(.pubkey == $pubkey) | .path' "$keystore_file")"
		if [[ -n $key_path ]]; then
			parse_index_from_signing_key_path "$key_path" validator_index
			indices_found+=("$validator_index $validator_pubkey")
			printinfo "${keystore_file}:\n\tpubkey: ${validator_pubkey}\n\tpath: ${key_path}\n\tindex: $validator_index"
			continue
		fi
	done
	if [[ -z $validator_index ]]; then
		pubkeys_not_found+=("$validator_pubkey")
	fi
done

# print sorted indices to stdout
num_found=${#indices_found[@]}
if [[ $num_found -ne 0 ]]; then
	printinfo "Found $num_found matches."
	if [[ -n $indices_outfile ]]; then
		# ensure empty
		>"$indices_outfile"
		# numeric-string, null-delimited array sort
		readarray -td $'\0' indices_found_sorted < <(printf '%s\0' "${indices_found[@]}" | sort -z -n)
		for index_found in "${indices_found_sorted[@]}"; do
			printf '%s\n' "$index_found" >>"$indices_outfile"
		done
	fi
fi

# return an error code and warning message if any indices not found
num_not_found=${#pubkeys_not_found[@]}
if [[ $num_not_found -ne 0 ]]; then
	printwarn "Not found:"
	for pubkey_not_found in "${pubkeys_not_found[@]}"; do
		echo "  $pubkeys_not_found" >&2
	done
	exit 1
fi

# -------------------------- POSTCONDITIONS -----------------------------------
