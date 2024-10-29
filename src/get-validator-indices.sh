#!/bin/bash

# get-validator-indices.sh
#
# Given a mnemonic seed phrase and a list of validator pubkeys, determine the
# validator account indices.
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
		Usage: $(basename ${BASH_SOURCE[0]}) [-h|--help] --mnemonic=<value> --validator_pubkeys=<value>
		  --mnemonic           The mnemonic used to generate the validator keys
		  --validator_pubkeys  The validator public keys
		  --help, -h           Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,mnemonic:,validator_pubkeys:' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
eval set -- "$_parsed_args"
unset _parsed_args

mnemonic=''
validator_pubkeys_csv=''

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

echo -n "${color_blue}${bold}"
cat <<EOF
  _ _ _/ __    _ /'_/__/  _ __  '  _/'_ _  _
 (/(- /     \/(/(/(/(//()/     //)(//( (-_) 
_/                                          
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Given a mnemonic seed phrase and a list of validator pubkeys, determine the validator account indices.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

staking_deposit_cli__preconditions
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

read_default "Start search at index" 0 validator_start_index
if [[ ! $validator_start_index =~ ^[[:digit:]]+$ || ! $validator_start_index -ge 0 ]]; then
	printerr "must choose an integer ≥ 0"
	exit 1
fi
printf '\n'

read_default "Max search range (more takes longer)" 5 num_validators
if [[ ! $num_validators =~ ^[[:digit:]]+$ || ! $num_validators -gt 0 ]]; then
	printerr "must choose a positive integer"
	exit 1
fi
printf '\n'

staking_deposit_cli__reconnaissance

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
staking_deposit_cli__unpack_tarball

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
for ((i = 0; i < num_pubkeys; i++ )); do
	validator_pubkey_trimmed="${validator_pubkeys_trimmed[i]}"
	validator_pubkey="${validator_pubkeys[i]}"
	validator_index=''
	for keystore_file in "${keystore_files[@]}"; do
		key_path="$(jq --raw-output --arg pubkey "$validator_pubkey_trimmed" '. | select(.pubkey == $pubkey) | .path' "$keystore_file")"
		if [[ -n $key_path ]]; then
			parse_index_from_signing_key_path "$key_path" validator_index
			indices_found+=("$validator_index")
			printinfo "${keystore_file}:\n\tpubkey: ${validator_pubkey}\n\tpath: ${key_path}\n\tindex: $validator_index"
			continue
		fi
	done
	if [[ -z $validator_index ]]; then
		pubkeys_not_found+=("$validator_pubkey")
	fi
done

# print comma-separated indices to stdout
num_found=${#indices_found[@]}
if [[ $num_found -ne 0 ]]; then
	printinfo "Found $num_found indices"
	echo "$(join_arr ',' "${indices_found[@]}")"
fi

# return an error code and warning message if any indices not found
num_not_found=${#pubkeys_not_found[@]}
if [[ $num_not_found -ne 0 ]]; then
	printwarn "Not found in the search range:"
	for ((i = 0; i < num_not_found; i++)); do
		echo "  ${pubkeys_not_found[i]}" >&2
	done
	exit 1
fi

# -------------------------- POSTCONDITIONS -----------------------------------
