#!/bin/bash

# _offline_utils.sh
#
# Utility functions used by scripts on the air-gapped PC.
# Not meant to be run as a top-level script.

function offline__preconditions() {
	assert_offline
	assert_not_on_node_server
	assert_sudo

	check_is_defined client_pc_usb_data_drive
	check_is_defined dist_dirname

	usb_dist_dir="$client_pc_usb_data_drive/$dist_dirname"
	
	check_directory_exists --sudo client_pc_usb_data_drive
	check_directory_exists --sudo usb_dist_dir
	
	print_failed_checks --error || return
}

function offline__deploy_usb_dist_to_current_dir() {
	# check that current dir is not the usb dist dir or its parent
	usb_dist_parent_dir="$(realpath "$usb_dist_dir/..")"
	reset_checks
	check_current_directory_is_not $usb_dist_dir
	check_current_directory_is_not $usb_dist_parent_dir
	print_failed_checks --error || return

	# copy USB drive deployment dir to current dir
	sudo cp -rf $usb_dist_dir .

	# check that the dist dir was created
	offline_dist_dir="$(realpath "./$dist_dirname")"
	reset_checks
	check_directory_exists --sudo offline_dist_dir
	print_failed_checks --error || return

	# unlock the dist files for use
	sudo chown "$USER:$USER" "$offline_dist_dir"
	sudo chmod ug+rw "$offline_dist_dir"
}
