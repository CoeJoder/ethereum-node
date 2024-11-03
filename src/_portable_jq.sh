#!/bin/bash

# _portable_jq.sh
#
# Common subroutines used with portable `jq` downloaded on the `DATA` drive.
# Not meant to be run as a top-level script.

function portable_jq__preconditions() {
	assert_sudo

	reset_checks
	check_directory_exists --sudo usb_dist_dir
	check_file_exists --sudo jq_bin_dist
	check_file_exists --sudo jq_bin_sha256_dist
	print_failed_checks --error || return

	# checksum using the included .sha256 file
	printinfo "Verifying jq SHA256 checksum..."
	(
		cd "$usb_dist_dir"
		sha256sum -c "$jq_bin_sha256_dist"
	) || return $?
	printf '\n'
}

function jq() {
	"$jq_bin_dist" "$@"
}
