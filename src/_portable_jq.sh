#!/bin/bash

# _portable_jq.sh
#
# Common subroutines used with portable `jq` downloaded on the `DATA` drive.
# Not meant to be run as a top-level script.

function portable_jq__preconditions() {
	assert_sudo

	check_is_defined jq_bin
	check_is_defined jq_bin_sha256

	jq_bin_path="$this_dir/$jq_bin"
	jq_bin_sha256_path="$this_dir/$jq_bin_sha256"

	check_file_exists --sudo jq_bin_path
	check_file_exists --sudo jq_bin_sha256_path

	print_failed_checks --error || return

	# checksum using the included .sha256 file
	printinfo "Verifying jq SHA256 checksum..."
	sha256sum -c "$jq_bin_sha256_path" || return
	printf '\n'
}

function portable_jq__reconnaissance() {
	sudo chown "$USER:$USER" "$jq_bin_path"
	sudo chown "$USER:$USER" "$jq_bin_sha256_path"	
	sudo chmod ug+rwx "$jq_bin_path"
	sudo chmod ug+rw "$jq_bin_sha256_path"


}
