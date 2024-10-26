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
validator_pubkeys=''

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
		validator_pubkeys="$2"
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
_.-=-=-=~'get-validator-indices'~=-=-=-._
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- PRECONDITIONS ------------------------------------

staking_deposit_cli__preconditions

# -------------------------- RECONNAISSANCE -----------------------------------

staking_deposit_cli__reconnaissance

if [[ -z $mnemonic ]]; then
	read_no_default "Please enter your mnemonic separated by spaces (\" \"). \
	Note: you only need to enter the first 4 letters of each word if you'd prefer." mnemonic
	if [[ $(printf '%s' "$mnemonic" | wc -w) -ne 24 ]]; then
		printerr "expected a 24-word mnemonic"
		exit 1
	fi
	printf '\n'
fi

if [[ -z $validator_pubkeys ]]; then
	read_no_default "Please enter the validator public keys, separated by commas." validator_pubkeys
	if [[ ! $validator_pubkeys =~ $regex_eth_validator_pubkey_csv ]]; then
		printerr "expected a comma-separated list of validator pubkeys"
		exit 1
	fi
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

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo
staking_deposit_cli__unpack_tarball

# -------------------------- POSTCONDITIONS -----------------------------------
