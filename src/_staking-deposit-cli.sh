#!/bin/bash

# _staking-deposit-cli.sh
#
# Common subroutines used with the EthStaker Deposit CLI.
# Not meant to be run as a top-level script.

# externs; suppress unassigned
declare -g this_dir
declare -g ethstaker_deposit_cli_basename
declare -g ethstaker_deposit_cli_basename_sha256
declare -g ethstaker_deposit_cli_sha256_url
declare -g ethstaker_deposit_cli_sha256_checksum
declare -g theme_command
declare -g theme_value
declare -g theme_filename
declare -g color_reset

function staking_deposit_cli__preconditions() {
	assert_offline
	assert_not_on_node_server
	assert_sudo

	reset_checks
	check_is_defined this_dir
	check_is_defined ethstaker_deposit_cli_version
	check_is_defined ethstaker_deposit_cli_sha256_checksum
	check_is_defined ethstaker_deposit_cli_url
	print_failed_checks --error || return

	deposit_cli="$this_dir/$ethstaker_deposit_cli_basename"
	deposit_cli_sha256="$this_dir/$ethstaker_deposit_cli_basename_sha256"

	reset_checks
	check_file_exists --sudo deposit_cli
	check_file_exists --sudo deposit_cli_sha256
	print_failed_checks --error || return
}

function staking_deposit_cli__reconnaissance() {
	reset_checks
	check_is_defined ethstaker_deposit_cli_sha256_url
	check_is_defined ethstaker_deposit_cli_sha256_checksum
	print_failed_checks --error || return

	printf '%s\n  %s\n' \
		"Using an online PC, please run:" \
		"${theme_command}wget -qO - '$ethstaker_deposit_cli_sha256_url' | cat${color_reset}"
	if ! yes_or_no --default-no "Does the output match this? ${theme_value}$ethstaker_deposit_cli_sha256_checksum${color_reset}"; then
		printerr "unexpected checksum; ensure that ${theme_value}ethstaker_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
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
	local dest_dir
	dest_dir="$(pwd)"
	cp -f "$deposit_cli" "$dest_dir"
	cp -f "$deposit_cli_sha256" "$dest_dir"
	sudo chown -R "$USER:$USER" "$dest_dir"

	# checksum using the included .sha256 file
	printinfo "Verifying deposit-cli SHA256 checksum..."
	sha256sum -c "$deposit_cli_sha256" || return
	printf '\n'

	# unpack tarball
	printinfo "Unpacking tarball..."
	tar xvzf "$ethstaker_deposit_cli_basename"
	printf '\n'

	local deposit_cli_dir="${dest_dir}/${ethstaker_deposit_cli_basename%%.*}"
	
	declare -g deposit_cli_bin
	export deposit_cli_bin="$deposit_cli_dir/deposit"

	# verify extraction success
	reset_checks
	check_directory_exists --sudo deposit_cli_dir
	check_executable_exists --sudo deposit_cli_bin
	print_failed_checks --error || return
}
