#!/bin/bash

# _staking_deposit_cli.sh
#
# Common subroutines used with the Ethereum Staking Deposit CLI.
# Not meant to be run as a top-level script.

function staking_deposit_cli__preconditions() {
	assert_offline
	assert_not_on_node_server
	assert_sudo

	check_is_defined this_dir
	check_is_defined ethereum_staking_deposit_cli_version
	check_is_defined ethereum_staking_deposit_cli_sha256_checksum
	check_is_defined ethereum_staking_deposit_cli_url

	deposit_cli="$this_dir/$ethereum_staking_deposit_cli_basename"
	deposit_cli_sha256="$this_dir/$ethereum_staking_deposit_cli_basename_sha256"

	check_file_exists --sudo deposit_cli
	check_file_exists --sudo deposit_cli_sha256
	print_failed_checks --error || return
}

function staking_deposit_cli__reconnaissance() {
	printf '%s' \
		"Using an online PC, navigate to " \
		"${color_blue}https://github.com/ethereum/staking-deposit-cli/releases/tag/${ethereum_staking_deposit_cli_version}${color_reset} " \
		"and verify the ${color_lightgray}SHA256 Checksum${color_reset} of ${theme_filename}$ethereum_staking_deposit_cli_basename${color_reset}"
	printf '\n'
	if ! yes_or_no --default-no "Does it match this? ${theme_value}$ethereum_staking_deposit_cli_sha256_checksum${color_reset}"; then
		printerr "unexpected checksum; ensure that ${color_lightgray}ethereum_staking_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
		return 1
	fi
	printf '\n'
}

function staking_deposit_cli__unpack_tarball() {
	# these are set during preconditions, make sure they're set
	reset_checks
	check_file_exists --sudo deposit_cli
	check_file_exists --sudo deposit_cli_sha256
	print_failed_checks --error || return

	# copy to the temp dir and chown it all
	# (assume curdir is temp dir)
	local dest_dir="$(pwd)"
	cp -f "$deposit_cli" "$dest_dir"
	cp -f "$deposit_cli_sha256" "$dest_dir"
	sudo chown -R "$USER:$USER" "$dest_dir"

	# checksum using the included .sha256 file
	printinfo "Verifying deposit-cli SHA256 checksum..."
	sha256sum -c "$deposit_cli_sha256" || return
	printf '\n'

	# unpack tarball
	printinfo "Unpacking tarball..."
	tar xvzf "$ethereum_staking_deposit_cli_basename"
	printf '\n'

	local deposit_cli_dir="${dest_dir}/${ethereum_staking_deposit_cli_basename%%.*}"
	deposit_cli_bin="$deposit_cli_dir/deposit"

	# verify extraction success
	reset_checks
	check_directory_exists --sudo deposit_cli_dir
	check_executable_exists --sudo deposit_cli_bin
	print_failed_checks --error || return
}
