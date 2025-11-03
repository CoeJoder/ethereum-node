#!/bin/bash

# _portable_jq.sh
#
# Common subroutines used with portable `jq` downloaded on the `DATA` drive.
# Not meant to be run as a top-level script.

# externs; suppress unassigned
declare -g usb_dist_dir
declare -g jq_bin_dist
declare -g jq_bin_sha256_dist

function portable_jq__preconditions() {
	functrace
	assert_sudo

	reset_checks
	check_directory_exists --sudo usb_dist_dir
	check_file_exists --sudo jq_bin_dist
	check_file_exists --sudo jq_bin_sha256_dist
	print_failed_checks --error || return

	# checksum using the included .sha256 file
	log info "Verifying jq SHA256 checksum..."
	(
		cd "$usb_dist_dir"
		sha256sum -c "$jq_bin_sha256_dist"
	) || return $?
	stderr
}

function jq() {
	functrace "$@"
	"$jq_bin_dist" "$@"
}
